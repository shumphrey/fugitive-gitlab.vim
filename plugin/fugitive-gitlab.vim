" fugitive-gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <http://stevenhumphrey.uk>
" Version:      0.0.1

" Plugs in to fugitive.vim and provides a gitlab hook for :Gbrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
"
" You need to specify the gitlab domains for your gitlab instance
" e.g.
"   let g:fugitive_gitlab_domains = [
"       'http://gitlab',
"       'http://gitlab.mydomain.com',
"       'https://gitlab.mydomain.com'
"   ]

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1

if !exists('g:fugitive_experimental_browse_handlers')
    let g:fugitive_experimental_browse_handlers = []
endif

function! s:gitlab_fugitive_handler(repo,url,rev,commit,path,type,line1,line2)
    let path    = a:path
    let domain_pattern = ''
    for domain in g:fugitive_gitlab_domains
        let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
    endfor
    
    let rep = matchstr(a:url,'^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
    if rep ==# ''
        return ''
    endif
    let repo = substitute(rep,':', '/','')

    " if the passed in domains have http, prefix that otherwise https
    if index(domains, 'http://' . matchstr(repo, '^[^:/]*')) >= 0
        let root = 'http://' . repo
    else
        let root = 'https://' . repo
    endif

    let url = root . "/blob/master/" . path . '#L' . a:line1
    return url
endfunction

let temp = [function('s:gitlab_fugitive_handler')]
call extend(temp, g:fugitive_experimental_browse_handlers)
let g:fugitive_experimental_browse_handlers = temp

" vim: set ts=4 sw=4 et
