if exists('g:autoloaded_fugitive_gitlab_api')
    finish
endif
let g:autoloaded_fugitive_gitlab_api = 1

" This file contains functions that deal directly with the GitLab API and
" vimscript
" This file has no vim ui or commands.
" Every public function should take a gitlab domain name where appropriate
" e.g. the key to gitlab_api_keys
" Every public function should return the contents of the GitLab API
"
" remote - a git url, e.g. git@gitlab.com:/foo (obtained via fugitive)
" domain - a key in the g:gitlab_api_keys & g:fugitive_gitlab_domains dictionary, e.g. gitlab.com
" root - https://gitlab.com
" project - shumphrey/fugitive-gitlab.vim

function! s:json_parse(string) abort
    if exists('*json_decode')
        return json_decode(a:string)
    endif
    let [null, false, true] = ['', 0, 1]
    let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
    if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
        try
            return eval(substitute(a:string,'[\r\n]',' ','g'))
        catch
        endtry
    endif
    call gitlab#utils#throw('invalid JSON: '.a:string)
endfunction

function! s:json_generate(object) abort
    if exists('*json_encode')
        return json_encode(a:object)
    endif
    if type(a:object) == type('')
        return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
    elseif type(a:object) == type([])
        return '['.join(map(copy(a:object), 'gitlab#json_generate(v:val)'),', ').']'
    elseif type(a:object) == type({})
        let pairs = []
        for key in keys(a:object)
            call add(pairs, gitlab#json_generate(key) . ': ' . gitlab#json_generate(a:object[key]))
        endfor
        return '{' . join(pairs, ', ') . '}'
    else
        return string(a:object)
    endif
endfunction

function! s:gitlab_api_key(domain) abort
    if exists('b:gitlab_api_keys') && has_key(b:gitlab_api_keys, a:domain)
        return b:gitlab_api_keys[a:domain]
    endif

    " gitlab_api_keys: { "gitlab.com": "myapitoken" }
    if exists('g:gitlab_api_keys')
        let key = get(g:gitlab_api_keys, a:domain)
        if !empty(key)
            return key
        endif
    endif

    call gitlab#utils#throw('Missing g:gitlab_api_keys or remote does not exist')
endfunction


" Makes a request to the api and returns the resulting text
" :call setreg('+', b:gitlab_last_curl)
function! gitlab#api#request(domain, path, ...) abort
    let key = s:gitlab_api_key(a:domain)
    let domains = gitlab#utils#parse_gitlab_domains()
    let root = get(domains, a:domain)
    if empty(root)
        call gitlab#utils#throw('No such domain')
    endif
    let url = root . '/api/v4' . a:path

    let headers = [
        \'PRIVATE-TOKEN: ' . key,
        \'Content-Type: application/json',
        \'Accept: application/json',
    \]

    if a:0
        let json = s:json_generate(a:1)
    endif

    if exists('*Post')
        if exists('json')
            let raw = Post(url, headers, json, a:0 > 1 ? a:2 : 'POST')
        else
            let raw = Post(url, headers)
        endif
        return s:json_parse(raw)
    endif

    if !executable('curl')
        call gitlab#utils#throw('cURL is required')
    endif

    let data = ['-q', '--silent', '-A', 'fugitive-gitlab.vim']
    for header in headers
        call extend(data, ['-H', header])
    endfor
    if a:0
        let temp = tempname()
        call writefile([json], temp)
        call extend(data, ['--data', '@'.temp])
    endif
    if a:0 > 1
        call extend(data, ['-X' . a:2])
    elseif a:0
        call extend(data, ['-XPOST'])
    endif

    call extend(data, [url])

    let options = join(map(copy(data), 'shellescape(v:val)'), ' ')
    let b:gitlab_last_curl = 'curl '.options
    silent let raw = system('curl '.options)
    let b:gitlab_last_raw = raw

    if !empty(v:shell_error)
        call gitlab#api#throw('shell error: ' . v:shell_error)
    endif

    " Delete returns 204 no content, no json
    if a:0 > 1 && a:2 ==# 'DELETE'
        return
    endif

    if empty(raw)
        call gitlab#utils#throw('No output from api')
    endif

    let jsonres = s:json_parse(raw)
    if type(jsonres) == type({}) && !empty(get(jsonres, 'message'))
        call gitlab#utils#throw(s:json_generate(get(jsonres, 'message')))
    endif

    if type(jsonres) == type({}) && has_key(jsonres, 'error')
        call gitlab#utils#throw(s:json_generate(get(jsonres, 'error')))
    endif

    return jsonres
endfunction

function! gitlab#api#issues(domain, project, query, type) abort
    if a:type ==# 'group'
        let group = substitute(a:project, '%2F.*', '', '')
        let path = '/groups/' . group . '/issues'
    else
        let path = '/projects/' . a:project . '/issues'
    endif

    let params = '?scope=all&state=opened&per_page=100'
    let params .= '&search='.a:query
    return gitlab#api#request(a:domain, path . params)
endfunction

" we probably want both project members and group members
function! gitlab#api#members(domain, project, query, type, ...) abort
    if a:type ==# 'group'
        let group = substitute(a:project, '%2F.*', '', '')
        let path = '/groups/' . group . '/members'
    else
        let path = '/projects/' . a:project . '/members'
    endif

    let params = '?per_page=100&query='.substitute(a:query, '@', '', '')
    return gitlab#api#request(a:domain, path . params)
endfunction

function! gitlab#api#contributors(domain, project) abort
    let path = '/projects/' . a:project . '/repository/contributors'
    let params = '?per_page=100'

    return gitlab#api#request(a:domain, path . params)
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
