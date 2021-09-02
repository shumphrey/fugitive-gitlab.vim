if exists('g:autoloaded_fugitive_gitlab_api')
    finish
endif
let g:autoloaded_fugitive_gitlab_api = 1

function! gitlab#api#json_parse(string) abort
    if exists('*json_decode')
        return json_decode(a:string)
    endif
    let [null, false, true] = ['', 0, 1]
    let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
    if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
        try
            return eval(substitute(a:string,"[\r\n]"," ",'g'))
        catch
        endtry
    endif
    call gitlab#utils#throw("invalid JSON: ".a:string)
endfunction

function! gitlab#api#json_generate(object) abort
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

function! s:gitlab_api_key(root) abort
    if exists('b:gitlab_api_key')
        return b:gitlab_api_key
    endif

    " gitlab_api_keys: { "gitlab.com": "myapitoken" }
    if exists('g:gitlab_api_keys')
        let keys = items(g:gitlab_api_keys)
        for item in keys
            if match(a:root, item[0]) >= 0
                return item[1]
            endif
        endfor
    endif

    call gitlab#utils#throw('Missing g:gitlab_api_keys')
endfunction

function! gitlab#api#paths_for_remote(remote) abort
    let homepage = gitlab#fugitive#homepage_for_remote(a:remote)

    if empty(homepage)
        call gitlab#utils#throw('Not a gitlab repo')
    endif

    let domains = gitlab#utils#parse_gitlab_domains()

    for domain in values(domains)
        let path = substitute(homepage, '^'.domain . '/', '', '')
        if path != homepage
            let project = substitute(path, '/', '%2F', 'g')
            let root = domain . '/api/v4'
            break
        endif
    endfor

    if len(root) < 1
        call gitlab#utils#throw(a:remote . " is not a known gitlab remote")
    endif

    return {'root': root, 'project': project}
endfunction

function! s:gitlab_project_from_repo(...) abort
    let validremote = '\.\|\.\=/.*\|[[:alnum:]_-]\+\%(://.\{-\}\)\='
    if len(a:000) > 0
        let remote = matchstr(join(a:000, ' '),'@\zs\%('.validremote.'\)$')
    else
        let remote = 'origin'
    endif

    let raw = FugitiveRemoteUrl(remote)

    return gitlab#api#paths_for_remote(raw)
endfunction

" Makes a request to the api and returns the resulting text
function! gitlab#api#request(domain, path, ...) abort
    let key = s:gitlab_api_key(a:domain)

    let url = a:domain . a:path

    let headers = [
        \'PRIVATE-TOKEN: ' . key,
        \'Content-Type: application/json',
        \'Accept: application/json',
    \]

    if a:0
        let json = gitlab#api#json_generate(a:0)
    endif

    if exists('*Post')
        if exists('json')
            let raw = Post(url, headers, json)
        else
            let raw = Post(url, headers)
        endif
        return gitlab#api#json_parse(raw)
    endif

    if !executable('curl')
        call gitlab#utils#throw('cURL is required')
    endif

    let data = ['-q', '--silent', '-A', 'fugitive-gitlab.vim']
    for header in headers
        call extend(data, ['-H', header])
    endfor
    if a:0
        let temp = tempfile()
        writefile([json], temp)
        call extend(data, ['-XPOST'])
        call extend(data, ['--data', '@'.temp])
    endif

    call extend(data, [url])

    let options = join(map(copy(data), 'shellescape(v:val)'), ' ')
    let raw = system('curl '.options)

    let jsonres = gitlab#api#json_parse(raw)
    if type(jsonres) == type({}) && !empty(get(jsonres, 'message'))
        call gitlab#utils#throw(get(jsonres, 'message'))
    endif
    return jsonres
endfunction

function! gitlab#api#issues(query, type, ...) abort
    let res = call('s:gitlab_project_from_repo', a:000)

    if a:type == 'group'
        let group = substitute(res.project, '%2F.*', '', '')
        let path = '/groups/' . group . '/issues'
    else
        let path = '/projects/' . res.project . '/issues'
    endif

    let params = '?scope=all&state=opened&per_page=100'
    let params .= '&search='.a:query
    return gitlab#api#request(res.root, path . params)
endfunction

" when querying members "collaborators"
" we probably want both project members and group members
function! gitlab#api#members(query, type, ...) abort
    let res = call('s:gitlab_project_from_repo', a:000)
    if a:type == 'group'
        let group = substitute(res.project, '%2F.*', '', '')
        let path = '/groups/' . group . '/members'
    else
        let path = '/projects/' . res.project . '/members'
    endif

    let params = '?per_page=100&query='.substitute(a:query, '@', '', '')
    return gitlab#api#request(res.root, path . params)
endfunction

function! gitlab#api#contributors(...) abort
    let res = call('s:gitlab_project_from_repo', a:000)

    let path = '/projects/' . res.project . '/repository/contributors'
    let params = '?per_page=100'

    return gitlab#api#request(res.root, path . params)
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
