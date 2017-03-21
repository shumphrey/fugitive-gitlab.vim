" fugitive-gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.2.0

" Plugs in to fugitive.vim and provides a gitlab hook for :Gbrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
" Requires fugitive.vim 2.1 or greater
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['https://gitlab.mydomain.com','http://gitlab.mydomain.com','http://gitlab']
"
" known to work with gitlab 7.14.1 on 2015-09-14

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

function! s:shellesc(arg) abort
    if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
        return a:arg
    elseif &shell =~# 'cmd' && a:arg !~# '"'
        return '"'.a:arg.'"'
    else
        return shellescape(a:arg)
    endif
endfunction

function! s:get_gitlab_domain_from_remote(remote)
    let remote = a:remote

    let domains = exists('g:fugitive_gitlab_domains') ? g:fugitive_gitlab_domains : []
    let rel_path = {}

    let domain_pattern = 'gitlab\.com'
    for domain in domains
        let domain = escape(split(domain, '://')[-1], '.')
        let domain_path = matchstr(domain, '/')
        if domain_path ==# '/'
            let domain_path = substitute(domain,'^[^/]*/','','')
        else
            let domain_path = ''
        endif
        let domain_root = split(domain, '/')[0]
        let domain_pattern .= '\|' . domain_root
        let rel_path[domain_root] = domain_path
    endfor

    " Try and extract a domain name from the remote
    " See https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols for the types of protocols.
    " If we can't extract the domain, we don't understand this protocol.
    " git://domain:path
    " https://domain/path
    let repo = matchstr(remote,'^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
    " ssh://user@domain:port/path.git
    if repo ==# ''
        let repo = matchstr(remote,'^\%(ssh://\%(\w*@\)\=\)\zs\('.domain_pattern.'\).\{-\}\ze\%(\.git\)\=$')
        let repo = substitute(repo, ':[0-9]\+', '', '')
    endif
    if repo ==# ''
        return ''
    endif

    " look for http:// + repo in the domains array
    " if it exists, prepend http, otherwise https
    " git/ssh URLs contain : instead of /, http ones don't contain :
    let repo_root = split(split(repo, '://')[-1],':')[0]
    let repo_path = get(rel_path, escape(repo_root, '.'), '')
    if repo_path ==# ''
        let repo = substitute(repo,':','/','')
    else
        let repo = substitute(repo,':','/' . repo_path . '/','')
    endif

    let project = substitute(repo, repo_root . '/', '', '')
    if index(domains, 'http://' . matchstr(repo, '^[^:/]*')) >= 0
        let root = 'http://' . repo
        let base = 'http://' . repo_root
    else
        let root = 'https://' . repo
        let base = 'https://' . repo_root
    endif

    return [root, base, project]
endfunction

function! s:gitlab_fugitive_handler(opts, ...)
    let path   = substitute(get(a:opts, 'path', ''), '^/', '', '')
    let line1  = get(a:opts, 'line1')
    let line2  = get(a:opts, 'line2')
    let remote = get(a:opts, 'remote')

    let root = s:get_gitlab_domain_from_remote(remote)[0]
    if empty(root)
        return ''
    endif

    " work out what branch/commit/tag/etc we're on
    " if file is a git/ref, we can go to a /commits gitlab url
    " If the branch/tag doesn't exist upstream, the URL won't be valid
    " Could check upstream refs?
    if path =~# '^\.git/refs/heads/'
        return root . '/commits/' . path[16:-1]
    elseif path =~# '^\.git/refs/tags/'
        return root . '/tags/' . path[15:-1]
    elseif path =~# '^\.git/refs/.'
        return root . '/commits/' . path[10:-1]
    elseif path =~# '^\.git\>'
        return root
    endif

    " Work out the commit
    if a:opts.commit =~# '^\d\=$'
        let commit = a:opts.repo.rev_parse('HEAD')
    else
        let commit = a:opts.commit
    endif

    " If buffer contains directory not file, return a /tree url
    let path = get(a:opts, 'path', '')
    if get(a:opts, 'type', '') ==# 'tree' || path =~# '/$'
        let url = substitute(root . '/tree/' . commit . '/' . path,'/$','', '')
    elseif get(a:opts, 'type', '') ==# 'blob' || path =~# '[^/]$'
        let url = root . "/blob/" . commit . '/' . path
        if line2 && line1 == line2
            let url .= '#L'.line1
        elseif line2
            let url .= '#L' . line1 . '-' . line2
        endif
    else
        let url = root . '/commit/' . commit
    endif

    return url
endfunction

call insert(g:fugitive_browse_handlers, function('s:gitlab_fugitive_handler'))

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Gitlab API related things
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:get_gitlab_api_key(root) abort
    if exists('b:gitlab_api_key')
        return b:gitlab_api_key
    endif

    " favour gitlab_api_keys: { "gitlab.com": "myapitoken" }
    if exists('g:gitlab_api_keys')
        let keys = items(g:gitlab_api_keys)
        for item in keys
            if match(a:root, item[0]) >= 0
                let b:gitlab_api_key = item[1]
                return b:gitlab_api_key
            endif
        endfor
    endif

    " otherwise just gitlab_api_key = "myapitoken"
    if !exists('g:gitlab_api_key')
        throw "Missing g:gitlab_api_keys in vimrc"
    endif

    let b:gitlab_api_key = g:gitlab_api_key
    return b:gitlab_api_key
endfunction

" Makes a request to the api and returns the resulting text
function! s:gitlab_request(root, path, ...) abort
    if !executable('curl')
        throw 'cURL is required'
    endif

    let key = s:get_gitlab_api_key(a:root)

    let url = a:root . '/api/v4' . a:path

    let args = ['-H', 'PRIVATE-TOKEN: ' . key]
    call extend(args, ['-H', 'Content-Type: application/json'])

    if a:0
        let jsonfile = a:1
        call extend(args, ['--data', '@'.jsonfile])
        call extend(args, ['-XPOST'])
    endif

    call extend(args, [url])
    let options = join(map(copy(args), 's:shellesc(v:val)'), ' ')
    let raw = system('curl '.options)
    return raw
endfunction

function! s:escape_snippet_line(key, line) abort
    let line = substitute(a:line, '\\', '\\\\', 'g')
    return substitute(line, '"', '\\"', 'g')
endfunction

" Annoyingly, v4 api at this time, uses different json for both snippet types
function! s:snippet_json(title, line1, line2, isproject) abort
    " shellescape() could be used, but we're not escaping for the shell...
    " TODO: replace this...
    let lines = map(getbufline(bufname('%'), a:line1, a:line2), function('s:escape_snippet_line'))
    let text = join(lines, "\\n")
    let filename = expand('%:t')
    let visibility = "public"

    let l:tmpfile = tempname() . '.json'

    if a:isproject
        let json = '{ "title": "' . a:title . '", "file_name": "' . filename .  '", "code": "' . text . '", "visibility": "' . visibility . '" }'
    else
        let json = '{ "title": "' . a:title . '", "file_name": "' . filename .  '", "content": "' . text . '", "visibility": "' . visibility . '" }'
    endif
    call writefile([json], l:tmpfile, 'b')

    return l:tmpfile
endfunction

function! s:get_gitlab_project(args) abort
    let repo = fugitive#repo()

    let validremote = '\.\|\.\=/.*\|[[:alnum:]_-]\+\%(://.\{-\}\)\='
    if len(get(a:args, 0)) > 0
        let remote = matchstr(join(a:args, ' '),'@\zs\%('.validremote.'\)$')
    else
        let remote = 'origin'
    endif

    if fugitive#git_version() =~# '^[01]\.\|^2\.[0-6]\.'
      let raw = repo.git_chomp('config','remote.'.remote.'.url')
    else
      let raw = repo.git_chomp('remote','get-url',remote)
    endif

    let l:ret = s:get_gitlab_domain_from_remote(raw)
    let l:domain = l:ret[1]
    let l:project = l:ret[2]

    if len(l:domain) < 1
        throw "Not a gitlab remote"
    endif

    let l:project = substitute(l:project, '/', '%2F', 'g')

    return {"domain": l:domain, "name": l:project}
endfunction

function! s:create_project_snippet(bang, line1, line2, ...) abort
    return s:create_snippet(a:bang, a:line1, a:line2, 1, join(a:000, ' '))
endfunction

function! s:create_user_snippet(bang, line1, line2, ...) abort
    return s:create_snippet(a:bang, a:line1, a:line2, 0, join(a:000, ' '))
endfunction

function! s:create_snippet(bang, line1, line2, isproject, ...) abort
    let repo = s:get_gitlab_project(a:000)
    let jsonfile = s:snippet_json(expand('%:t'), a:line1, a:line2, a:isproject)

    if a:isproject
        let path = '/projects/' . repo.name . '/snippets'
    else
        let path = '/snippets'
    endif


    let response = s:gitlab_request(repo.domain, path, jsonfile)

    " extract web_url
    let res = substitute(response, '.*web_url":"', '', '')
    let url = substitute(res, '".*', '', '')

    if match(url, '^http') < 0
        echomsg response
        echomsg "Could not extract url from response"
        return 0
    endif

    if a:bang
        if has('clipboard')
            let @+ = url
        endif
    elseif exists(':Browse') == 2
        Browse(url)
    else
        if !exists('g:loaded_netrw')
            runtime! autoload/netrw.vim
        endif

        if exists('*netrw#BrowseX')
            call netrw#BrowseX(url, 0)
        else
            call netrw#NetrwBrowseX(url, 0)
        endif
    endif
endfunction

" no arguments
" range with default of whole file
" accept ! to just copy the snippet url
command! -nargs=* -range=% -bang GitlabProjectSnippet  :call s:create_project_snippet(<bang>0, <line1>, <line2>, <f-args>)
command! -nargs=* -range=% -bang GitlabUserSnippet  :call s:create_user_snippet(<bang>0, <line1>, <line2>, <f-args>)

" vim: set ts=4 sw=4 et
