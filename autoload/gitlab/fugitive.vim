if exists('g:autoloaded_fugitive_gitlab_fugitive')
    finish
endif
let g:autoloaded_fugitive_gitlab_fugitive = 1

function! gitlab#fugitive#handler(opts, ...)
    let path   = substitute(get(a:opts, 'path', ''), '^/', '', '')
    let line1  = get(a:opts, 'line1')
    let line2  = get(a:opts, 'line2')
    let remote = get(a:opts, 'remote')

    let root = gitlab#fugitive#homepage_for_remote(remote)
    if empty(root)
        return ''
    endif

    if !exists('g:fugitive_gitlab_oldstyle_urls')
        let root = root . '/-'
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

    let commit = a:opts.commit

    " All paths re-verified with gitlab.com on 22-05-2023
    let path = get(a:opts, 'path', '')
    " If buffer contains directory not file, return a /tree url
    if get(a:opts, 'type', '') ==# 'tree' || get(a:opts, 'path', '') =~# '/$'
        let url = substitute(root . '/tree/' . commit . '/' . path,'/$','', '')
    elseif get(a:opts, 'type', '') ==# 'blob' || path =~# '[^/]$'
        let url = root . '/blob/' . commit . '/' . path
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

function! gitlab#fugitive#homepage_for_remote(url) abort
    let domains = gitlab#utils#parse_gitlab_domains()

    " https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols
    " [full_url, scheme, host_with_port, host, path]
    if a:url =~# '://'
        let match = matchlist(a:url, '^\(https\=://\|git://\|ssh://\|git+ssh://\)\%([^@/]\+@\)\=\(\([^/:]\+\)\%(:\d\+\)\=\)/\(.\{-\}\)\%(\.git\)\=/\=$')
    else
        let match = matchlist(a:url, '^\([^@/]\+@\)\=\(\([^:/]\+\)\):\(.\{-\}\)\%(\.git\)\=/\=$')
        if empty(match)
            return ''
        endif
        let match[1] = 'ssh://'
    endif

    if empty(match)
        return ''
    elseif has_key(domains, match[1] . 'git@' . match[2])
        let key = match[1] . 'git@' . match[2]
    elseif has_key(domains, match[1] . match[2])
        let key = match[1] . match[2]
    elseif has_key(domains, match[2])
        let key = match[2]
    elseif has_key(domains, match[3])
        let key = match[3]
    else
        return ''
    endif
    let root = domains[key]

    " e.g. v:true
    if type(root) !=# type('') && root
        let root = key
    endif

    if empty(root)
        return ''
    elseif root !~# '://'
        let root = (match[1] =~# '^http://' ? 'http://' : 'https://') . root
    endif
    return substitute(root, '/$', '', '') . '/' . match[4]
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
