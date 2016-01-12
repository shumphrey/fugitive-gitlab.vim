" fugitive-gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.1.0

" Plugs in to fugitive.vim and provides a gitlab hook for :Gbrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
" Requires fugitive.vim 2.1 or greater
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['http://gitlab','http://gitlab.mydomain.com','https://gitlab.mydomain.com']
"
" known to work with gitlab 7.14.1 on 2015-09-14

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

function! s:gitlab_fugitive_handler(opts, ...)
    let path   = substitute(get(a:opts, 'path', ''), '^/', '', '')
    let line1  = get(a:opts, 'line1')
    let line2  = get(a:opts, 'line2')
    let remote = get(a:opts, 'remote')

    let domains = exists('g:fugitive_gitlab_domains') ? g:fugitive_gitlab_domains : []

    let domain_pattern = 'gitlab\.com'
    for domain in domains
        let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
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
    if index(domains, 'http://' . matchstr(repo, '^[^:/]*')) >= 0
        let root = 'http://' . substitute(repo,':', '/','')
    else
        let root = 'https://' . substitute(repo,':', '/','')
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
    if get(a:opts, 'type', '') ==# 'tree' || a:opts.path =~# '/$'
        let url = substitute(root . '/tree/' . commit . '/' . path,'/$','', '')
    elseif get(a:opts, 'type', '') ==# 'blob' || a:opts.path =~# '[^/]$'
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

" vim: set ts=4 sw=4 et
