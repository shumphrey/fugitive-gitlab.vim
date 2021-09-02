if exists('g:autoloaded_fugitive_gitlab')
    finish
endif
let g:autoloaded_fugitive_gitlab = 1


let s:reference = '\<\%(\c\%(clos\|resolv\|referenc\)e[sd]\=\|\cfix\%(e[sd]\)\=\)\>'
function! gitlab#omnifunc(findstart, base) abort
    " Currently omnicompletion requires origin this is the same as rhubarb
    let remote = 'origin'

    if a:findstart
        let existing = matchstr(getline('.')[0:col('.')-1],s:reference.'\s\+\zs[^#/,.;]*$\|[#@[:alnum:]-]*$')
        return col('.')-1-strlen(existing)
    endif
    try
        if a:base =~# '^@'
            if !exists('g:gitlab_members_type')
                let g:gitlab_members_type = 'project'
            endif

            let response = []
            if g:gitlab_members_type == 'project' || g:gitlab_members_type == 'both'
                call extend(response, gitlab#api#members(a:base, 'project', '@'.remote))
            endif
            if g:gitlab_members_type == 'group' || g:gitlab_members_type == 'both'
                call extend(response, gitlab#api#members(a:base, 'group', '@'.remote))
            endif

            " This can be a bit slow as it results in two commits
            return map(response, '"@".v:val.username')
        else
            if a:base =~# '^#'
                let prefix = '#'
            else
                let homepage = gitlab#fugitive#homepage_for_remote(FugitiveRemoteUrl(remote))
                let prefix = homepage . '/issues/'
            endif
            " this differs to rhubarb slightly,
            " we always search for the search term, unless its purely a number
            if a:base =~# '^#\=\d\+$'
                let query = ''
            else
                let query = substitute(a:base, '#', '', '')
            endif

            if !exists('g:gitlab_issues_type')
                let g:gitlab_issues_type = 'project'
            endif

            let response = gitlab#api#issues(query, g:gitlab_issues_type, '@'.remote)
            if type(response) != type([])
                call gitlab#utils#throw('unknown error')
            endif
            return map(response, '{"word": prefix . v:val.iid, "abbr": "#".v:val.iid, "menu": v:val.title, "info": substitute(v:val.description,"\\r","","g")}')
        endif
    catch /^\%(fugitive\|gitlab\):/
        echoerr v:errmsg
    endtry
endfunction

" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
