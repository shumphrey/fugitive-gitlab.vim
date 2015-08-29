" fugitive-gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <http://stevenhumphrey.uk>
" Version:      0.0.3

" Plugs in to fugitive.vim and provides a gitlab hook for :Gbrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['http://gitlab','http://gitlab.mydomain.com','https://gitlab.mydomain.com']

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

function! s:gitlab_fugitive_handler(opts, ...)
" repo,url,rev,commit,path,type,line1,line2)
    let opts  = a:opts
    let path  = get(a:opts, 'path')
    let line1 = get(a:opts, 'line1')
    let line2 = get(a:opts, 'line2')
    let url   = get(a:opts, 'remote')
    let domains = exists('g:fugitive_gitlab_domains') ? g:fugitive_gitlab_domains : []

    let domain_pattern = 'gitlab\.com'
    for domain in domains
        let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
    endfor
    
    let repo = matchstr(url,'^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
    if repo ==# ''
        return ''
    endif

    " look for http:// + repo in the domains array
    " if it exists, prepend http, otherwise https
    if index(domains, 'http://' . matchstr(repo, '^[^:/]*')) >= 0
        let root = 'http://' . repo
    else
        let root = 'https://' . repo
    endif

    if !line1
        let url = root . "/blob/master/" . path
    elseif line1 == line2
        let url = root . "/blob/master/" . path . '#L' . line1
    else
        let url = root . "/blob/master/" . path . '#L' . line1 . '-' . line2
    endif
    return url
endfunction

let temp = [function('s:gitlab_fugitive_handler')]
call extend(temp, g:fugitive_browse_handlers)
let g:fugitive_browse_handlers = temp

" vim: set ts=4 sw=4 et
