if exists('g:autoloaded_fugitive_gitlab_omnifunc')
    finish
endif
let g:autoloaded_fugitive_gitlab_omnifunc = 1


let s:reference = '\<\%(\c\%(clos\|resolv\|referenc\)e[sd]\=\|\cfix\%(e[sd]\)\=\)\>'
function! gitlab#omnifunc#handler(findstart, base) abort
    let res = gitlab#utils#split_remote(FugitiveRemoteUrl())

    if a:findstart
        let line = getline('.')[0:col('.')-1]

        " contains an @, lets start from there
        let existing = substitute(matchstr(line, '\s*@[[:alnum:]]*$'), '^\s*', '', '')
        if !empty(existing)
            return col('.') - 1 - strlen(existing)
        endif

        " Otherwise, start from  "Fixes ..."
        let existing = matchstr(line,s:reference.'\s\+\zs[^#/,.;]*$\|[#@[:alnum:]-]*$')
        return col('.')-1-strlen(existing)
    endif

    try
        if a:base =~# '^@'
            let query = a:base
            " searching for s or st or sh does not find shumphrey or steven
            " searching for ste or shu does
            if len(a:base) < 4
                let query = ''
            else
                let query = substitute(a:base, '^@', '', '')
            endif

            let response  = gitlab#api#list_project_members(res.domain, res.project, query)

            return map(response, '{"word": "@" . v:val.username, "info": v:val.name}')
        else
            if a:base =~# '^#'
                let prefix = '#'
                let force_project_issues = v:true
            else
                let force_project_issues = v:false
            endif

            " If we've just got numbers, there's little point in searching for numbers
            if a:base =~# '^#\=\d\+$'
                let query = ''
            else
                let query = substitute(substitute(a:base, '#', '', ''), '^\s*', '', '')
            endif

            " Deciding whether to list project, group or all issues is hard
            " Most of the time, we'll just want to complete project issues
            " Sometimes a group.
            " Determining group can't be done from the git information.
            " shumphrey/fugitive-gitlab.vim, shumphrey is not a group
            " The api call gitlab#api#project(...) can be issued to get the group
            let group = get(b:, 'gitlab_group')

            if force_project_issues || empty(group)
                let response = gitlab#api#list_project_issues(res.domain, res.project, query)
            elseif !empty(group)
                let response = gitlab#api#list_group_issues(res.domain, group, query)
            else
                echoerr 'Could not get issues for project/group'
                return []
            endif

            if type(response) != type([])
                echoerr 'Unknown response from GitLab'
                return []
            endif


            if exists('prefix') && !empty(prefix)
                let wordstr = 'prefix . v:val.iid'
            else
                let wordstr = 'v:val.web_url'
            endif
            return map(response, '{"word": '.wordstr.', "abbr": "#".v:val.iid, "menu": v:val.title, "info": substitute(v:val.description,"\\r","","g")}')
        endif
    catch /^\%(fugitive\|GitLab\):/
        echoerr v:errmsg
    endtry
endfunction

" vim: set ts=4 sw=4 et :
