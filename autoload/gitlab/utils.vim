if exists('g:autoloaded_fugitive_gitlab_utils')
    finish
endif
let g:autoloaded_fugitive_gitlab_utils = 1

function! gitlab#utils#throw(string) abort
    let v:errmsg = 'gitlab: '.a:string
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

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
