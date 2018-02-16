if exists('g:autoloaded_fugitive_gitlab')
    finish
endif
let g:autoloaded_fugitive_gitlab = 1

function! gitlab#fugitive_handler(opts, ...)
    let path   = substitute(get(a:opts, 'path', ''), '^/', '', '')
    let line1  = get(a:opts, 'line1')
    let line2  = get(a:opts, 'line2')
    let remote = get(a:opts, 'remote')

    let root = gitlab#homepage_for_remote(remote)
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

function! gitlab#homepage_for_remote(remote) abort
    let domains = exists('g:fugitive_gitlab_domains') ? g:fugitive_gitlab_domains : []
    call map(copy(domains), 'substitute(v:val, "/$", "", "")')
    let domain_pattern = 'gitlab\.com'
    for domain in domains
        let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
    endfor

    " git://domain:path
    " https://domain/path
    " https://user@domain/path
    " ssh://git@domain/path.git
    let base = matchstr(a:remote, '^\%(https\=://\|git://\|git@\|ssh://git@\)\%(.\{-\}@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')

    if index(domains, 'http://' . matchstr(base, '^[^:/]*')) >= 0
        return 'http://' . tr(base, ':', '/')
    elseif !empty(base)
        return 'https://' . tr(base, ':', '/')
    else
        return ''
    endif
endfunction

" vim: set ts=4 sw=4 et
