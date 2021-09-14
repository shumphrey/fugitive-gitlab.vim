if exists('g:autoloaded_fugitive_gitlab_utils')
    finish
endif
let g:autoloaded_fugitive_gitlab_utils = 1

function! gitlab#utils#throw(string) abort
    let v:errmsg = 'GitLab: '.a:string
    throw v:errmsg
endfunction

function! gitlab#utils#parse_gitlab_domains() abort
    let dict_or_list = get(g:, 'fugitive_gitlab_domains', {})
    let domains = { 'gitlab.com': 'https://gitlab.com' }

    if type(dict_or_list) == type([])
        for domain in dict_or_list
            let lhs = substitute(substitute(domain, '^.\{-\}://', '', ''), '/.*', '', '')
            let domains[lhs] = domain
        endfor
    elseif type(dict_or_list) == type({})
        let domains = extend(domains, dict_or_list)
    endif
    return domains
endfunction

function! gitlab#utils#split_remote(remote) abort
    let homepage = gitlab#fugitive#homepage_for_remote(a:remote)

    if empty(homepage)
        call gitlab#utils#throw((len(a:remote) ? a:remote : 'origin') . ' is not a GitLab repository')
    endif

    let domains = gitlab#utils#parse_gitlab_domains()

    for [key, url] in items(domains)
        let path = substitute(homepage, '^'.url . '/', '', '')
        if path != homepage
            let project = path
            let root = url
            let domain = key
            break
        endif
    endfor

    if len(root) < 1
        call gitlab#utils#throw(a:remote . ' is not a known gitlab remote')
    endif

    return {'root': root, 'project': project, 'domain': domain}
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
