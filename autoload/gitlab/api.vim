if exists('g:autoloaded_fugitive_gitlab_api')
    finish
endif
let g:autoloaded_fugitive_gitlab_api = 1

" This file contains functions that deal directly with the GitLab API and
" vimscript
" This file has no vim ui or commands.
" Every public function should take a gitlab domain name where appropriate
" e.g. the key to gitlab_api_keys/fugitive_gitlab_domains
" Every public function should return the contents of the GitLab API
"
" Legend:
"   remote - a git url, e.g. git@gitlab.com:/foo (obtained via fugitive)
"   domain - a key in the g:gitlab_api_keys & g:fugitive_gitlab_domains dictionary, e.g. gitlab.com
"   root - https://gitlab.com
"   project - shumphrey/fugitive-gitlab.vim
"
" Everything in here is experimental and subject to change.

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

function! s:url_encode(text) abort
    return substitute(a:text, '[?@=&<>%#/:+[:space:]]', '\=submatch(0)==" "?"+":printf("%%%02X", char2nr(submatch(0)))', 'g')
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

    call gitlab#utils#throw(a:domain . ' is not a key in g:gitlab_api_keys')
endfunction

" Makes a request to the api and returns the resulting text
" :call setreg('+', b:gitlab_last_curl)
function! gitlab#api#request(domain, path, ...) abort
    let key = s:gitlab_api_key(a:domain)
    let domains = gitlab#utils#parse_gitlab_domains()
    let root = get(domains, a:domain)
    if empty(root)
        call gitlab#utils#throw(a:domain . ' is not in g:fugitive_gitlab_domains')
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
        call gitlab#utils#throw('cURL returned non-zero exit code: ' . raw)
    endif

    " Delete returns 204 no content, no json
    if a:0 > 1 && a:2 ==# 'DELETE'
        return
    endif

    if empty(raw)
        call gitlab#utils#throw('No output from api')
    endif

    try
        let jsonres = s:json_parse(raw)
        if type(jsonres) == type({}) && !empty(get(jsonres, 'message'))
            call gitlab#utils#throw(s:json_generate(get(jsonres, 'message')))
        endif

        if type(jsonres) == type({}) && has_key(jsonres, 'error')
            call gitlab#utils#throw(s:json_generate(get(jsonres, 'error')))
        endif
    catch /404/
        throw gitlab#utils#throw('404 - url: ' . url)
    endtry

    return jsonres
endfunction

function! gitlab#api#list_projects(domain, ...)
    let params = '?per_page=100'
    if a:0 > 0
        let params .= '&search='.a:1
    endif
    return gitlab#api#request(a:domain, '/projects'. params)
endfunction

function! gitlab#api#project(domain, project)
    return gitlab#api#request(a:domain, '/projects/' . s:url_encode(a:project))
endfunction

function! gitlab#api#list_groups(domain, ...)
    let params = '?per_page=100'
    if a:0 > 0
        let params .= '&search=' . a:1
    endif
    return gitlab#api#request(a:domain, '/groups'. params)
endfunction

function! s:list_issues(domain, path, ...)
    let params = '?scope=all&state=opened&per_page=100'
    if a:0 > 0
        let params .= '&search=' . a:1
    endif
    return gitlab#api#request(a:domain, a:path . params)
endfunction

" echo gitlab#api#list_issues('gitlab.com', '')
function! gitlab#api#list_issues(domain, ...)
    return call('s:list_issues', extend([a:domain, '/issues'], a:000))
endfunction

" echo gitlab#api#list_group_issues('gitlab.com', 'group', 'query')
" group id might not exactly match what gitlab displays
function! gitlab#api#list_group_issues(domain, group, ...)
    let path = '/groups/' . s:url_encode(a:group) . '/issues'
    return call('s:list_issues', extend([a:domain, path], a:000))
endfunction

" echo gitlab#api#list_project_issues(domain, group, query)
function! gitlab#api#list_project_issues(domain, project, ...)
    let path = '/projects/' . s:url_encode(a:project) . '/issues'
    return call('s:list_issues', extend([a:domain, path], a:000))
endfunction

function! gitlab#api#create_project_issue(domain, project, options)
    let allowed_options = ['assignee_id', 'assignee_ids', 'description', 'issue_type', 'labels', 'title', 'confidential', 'epic_id', 'epic_iid', 'milestone_id', 'weight', 'issue_iid']

    for key in keys(a:options)
        if index(allowed_options, key) < 0
            call gitlab#utils#throw('Unknown issue option ' . key)
        endif
    endfor

    let options = copy(a:options)
    if has_key(options, 'issue_id')
        let issue_iid = remove(options, 'issue_iid')
        let path = '/projects/' . s:url_encode(a:project) . '/issues/' . issue_iid
        let method = 'PUT'
    else
        if !has_key(options, 'title')
            call gitlab#utils#throw('Issue must have a title')
        endif
        let path = '/projects/' . s:url_encode(a:project) . '/issues'
        let method = 'POST'
    endif

    return gitlab#api#request(a:domain, path, options, method)
endfunction

" echo gitlab#api#list_project_members(domain, project, query)
function! gitlab#api#list_project_members(domain, project, ...)
    let params = '?per_page=100'
    if a:0 > 0
        let params .= '&query='.substitute(a:1, '@', '', '')
    endif
    let path = '/projects/' . s:url_encode(a:project) . '/members/all'
    return gitlab#api#request(a:domain, path . params)
endfunction

" echo gitlab#api#list_repository_contributors('gitlab.com', 'project')
function! gitlab#api#list_repository_contributors(domain, project)
    let path = '/projects/' . s:url_encode(a:project) . '/repository/contributors'
    let params = '?per_page=100'

    return gitlab#api#request(a:domain, path . params)
endfunction

function! s:snippet_data_from_options(text, options) abort
    if has_key(a:options, 'snippet_id')
        let title = get(a:options, 'title')
        let desc = get(a:options, 'description')
        let name = get(a:options, 'name')
        let previous_name = get(a:options, 'previous_name')
        let visibility = get(a:options, 'visibility')

        let data = {}
        if !empty(title)
            let data['title'] = title
        endif
        if !empty(desc)
            let data['description'] = desc
        endif
        if !empty(visibility)
            let data['visibility'] = visibility
        endif

        if empty(name)
            call gitlab#utils#throw("Can't update snippet without filename")
        endif

        " if empty(previous_name)
        "     call gitlab#utils#throw("Missing previous_name")
        " endif
        let file_data = {
            \'file_path': name,
            \'action': 'update',
            \'content': a:text,
        \}

        if !empty(previous_name)
            let file_data.previous_path = previous_name
            let file_data.action = 'move'
        endif
        let data.files = [file_data]

    else
        let title = get(a:options, 'title', expand('%:t'))
        let desc  = get(a:options, 'description', 'fugitive-gitlab generated snippet')
        let name  = get(a:options, 'name', expand('%:t'))
        let visibility = get(a:options, 'visibility')
        if empty(title)
            let title = 'empty.txt'
        endif

        let file_data = {
            \'action': 'create',
            \'file_path': name,
            \'content': a:text,
        \}

        let data = {
            \'title': title,
            \'description': desc,
            \'files': [file_data],
        \}
        if !empty(visibility)
            let data['visibility'] = visibility
        endif
    endif

    return data
endfunction

" Write some text to a GitLab host
" echo gitlab#api#create_user_snippet('gitlab.com', text, options)
function! gitlab#api#create_user_snippet(domain, text, ...)
    let options = a:0 ? a:1 : {}
    let data = s:snippet_data_from_options(a:text, options)

    let snippet_id = get(options, 'snippet_id')
    if !empty(snippet_id)
        let path = '/snippets/' . snippet_id
        let method = 'PUT'
    else
        " User snippets have a default visibility
        " but this appears to be "internal" which you can't set on gitlab.com
        " https://gitlab.com/gitlab-org/gitlab/-/issues/12388
        let visibility = get(options, 'visibility', get(g:, 'gitlab_snippet_visibility', 'private'))
        let data['visibility'] = visibility

        let path = '/snippets'
        let method = 'POST'
    endif

    return gitlab#api#request(a:domain, path, data, method)
endfunction

" echo gitlab#api#create_project_snippet('gitlab.com', text, options)
function! gitlab#api#create_project_snippet(domain, project, text, ...)
    let options = a:0 ? a:1 : {}
    let data = s:snippet_data_from_options(a:text, options)

    " let data['visibility'] = visibility

    let snippet_id = get(options, 'snippet_id')
    if !empty(snippet_id)
        let path = '/projects/' . s:url_encode(a:project) . '/snippets/' . snippet_id
        let method = 'PUT'
    else
        " Project snippets must supply visibility
        let visibility = get(options, 'visibility', get(g:, 'gitlab_snippit_visibility', 'private'))
        let data['visibility'] = visibility

        let path = '/projects/' . s:url_encode(a:project) . '/snippets'
        let method = 'POST'
    endif

    return gitlab#api#request(a:domain, path, data, method)
endfunction

" Return a list of snippets from a GitLab host
" echo gitlab#api#list_snippets('gitlab.com')
function! gitlab#api#list_snippets(domain)
    return gitlab#api#request(a:domain, '/snippets?per_page=100')
endfunction

" Delete a snippet
" echo gitlab#api#delete_user_snippet('gitlab.com', '12345')
function! gitlab#api#delete_user_snippet(domain, snippet_id)
    return gitlab#api#request(a:domain, '/snippets/' . a:snippet_id, v:null, 'DELETE')
endfunction

" echo gitlab#api#delete_project_snippet('gitlab.com', '12345')
function! gitlab#api#delete_project_snippet(domain, project, snippet_id)
    let path = '/projects/' . s:url_encode(a:project) . '/snippets/' . a:snippet_id
    return gitlab#api#request(a:domain, path, v:null, 'DELETE')
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
