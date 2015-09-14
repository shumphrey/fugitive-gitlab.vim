" fugitive-gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.0.0

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
" repo,url,rev,commit,path,type,line1,line2)
    let path  = get(a:opts, 'path')
    let line1 = get(a:opts, 'line1')
    let line2 = get(a:opts, 'line2')
    let domains = exists('g:fugitive_gitlab_domains') ? g:fugitive_gitlab_domains : []

    let domain_pattern = 'gitlab\.com'
    for domain in domains
        let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
    endfor
    
    let repo = matchstr(get(a:opts, 'remote'),'^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
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
        let branch = a:opts.repo.git_chomp('config','branch.'.path[16:-1].'.merge')[11:-1]
        if branch ==# ''
            return root . '/commits/' . path[16:-1]
        else
            return root . '/commits/' . branch
        endif
    elseif path =~# '^\.git/refs/.'
        return root . '/commits/' . matchstr(path,'[^/]\+$')
    elseif path =~# '^\.git\>'
        return root
    endif

    " Work out the commit
    if a:opts.revision =~# '^[[:alnum:]._-]\+:'
        let commit = matchstr(a:opts.revision,'^[^:]*')
    elseif a:opts.commit =~# '^\d\=$'
        let local = matchstr(a:opts.repo.head_ref(),'\<refs/heads/\zs.*')
        let commit = a:opts.repo.git_chomp('config','branch.'.local.'.merge')[11:-1]
        if commit ==# ''
            let commit = local
        endif
    else
        let commit = a:opts.commit
    endif

    " If buffer contains directory not file, return a /tree url
    if a:opts.type == 'tree'
        let url = substitute(root . '/tree/' . commit . '/' . path,'/$','', '')
    elseif a:opts.type == 'blob'
        let url = root . "/blob/" . commit . '/' . path
        if line2 && line1 == line2
            let url .= '#L'.line1
        elseif line2
            let url .= '#L' . line1 . '-' . line2
        endif
    elseif a:opts.type == 'tag'
        let commit = matchstr(getline(3),'^tag \zs.*')
        let url = root . '/tree/' . commit
    else
        let url = root . '/commit/' . commit
    endif
    "
    return url
endfunction

call insert(g:fugitive_browse_handlers, function('s:gitlab_fugitive_handler'))

" vim: set ts=4 sw=4 et
