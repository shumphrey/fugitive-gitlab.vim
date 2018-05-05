if exists('g:autoloaded_gitlab_snippets')
    finish
endif
let g:autoloaded_gitlab_snippets = 1

" Determining which domain/root to use can be quite complicated
" Git may have multiple remotes, potentially multiple *gitlab* remotes
" Snippets command may not be associated with a git repo
"
" we can supply a @remotename to any argument
" if that is supplied it is assumed to be first a key to the api keys dict
" otherwise a git remote name
"
" If it isn't supplied, then we first try and work out the api url from
" current git repo remote, defaulting to origin
" otherwise default to https://gitlab.com
function! s:gitlab_remote(...) abort
    let remotename = substitute(matchstr(join(a:000, ' '), '@[a-zA-Z0-9_\.]\+'), '@', '', 'g')

    if empty(remotename)
        try
            let default_remote = 'origin'
            if exists('g:gitlab_remote')
                let default_remote = g:gitlab_remote
            endif
            let url = fugitive#buffer().repo().config('remote.'.default_remote.'.url')
            return gitlab#api_paths_for_remote(url)
        catch
            if exists('g:gitlab_api_url')
                let root = g:gitlab_api_url
            else
                let root = 'https://gitlab.com'
            endif
        endtry
    else
        " If its an entry from the api_keys, then I need to find the domain
        " from the fugitive array
        " otherwise just wack on https://
        if has_key(g:gitlab_api_keys, remotename)
            let index = match(g:fugitive_gitlab_domains, remotename)
            if index > -1
                let root = g:fugitive_gitlab_domains[index]
            else
                let root = remotename
            endif
        else
        " Otherwise, let's see if this is a git repo and its a git remote
        " If it is a git remote, we need to knock off the paths
        " First try and match found url to a fugitive_gitlab_domains
            try
                let url = fugitive#buffer().repo().git_chomp('config', 'remote.'.remotename.'.url')
            catch
                call s:throw('Not a valid url or git remote')
            endtry
            if exists('url') && !empty(url)
                try
                    return gitlab#api_paths_for_remote(url)
                catch
                    call s:throw('No API key for ' . url)
                endtry
            endif
        endif
    endif

    if !exists('root') || empty(root)
        call s:throw('Unable to determine gitlab instance')
    endif

    if root =~# '^http'
        return { 'root': root }
    endif

    return { 'root': 'https://' . root }
endfunction

function! gitlab#snippet#write(bang, line1, line2, ...) abort
    try
        let options = s:parse_args(a:000)
        if type(options) != type({})
            return
        endif

        let remote = s:gitlab_remote(get(options, 'remote', ''))
    catch
        call s:error(v:errmsg)
        return
    endtry

    let text = join(getline(a:line1, a:line2), "\n")
    let type = get(options, 'type', 'user')

    let title = get(options, 'title', expand('%'))
    let desc  = get(options, 'description', 'fugitive-gitlab generated snippet')
    let name  = get(options, 'name', expand('%'))
    if empty(title)
        let title = 'empty.txt'
    endif

    " let file_name = s:parse_string_arg(joinedargs, 'f', expand('%'))
    " let descr = s:parse_string_arg(joinedargs, 'd', 'fugitive-gitlab generated snippet')
    " let file_name = expand('%')
    " let descr = 'fugitive-gitlab generated snippet'

    let data = {
        \'title': title,
        \'file_name': name,
        \'description': desc
    \}

    if type == 'project'
        if !has_key(remote, 'project')
            call s:error('Not a git repository, cannot work out project')
            return
        endif
        let data['code'] = text
        let data['visibility'] = 'private'
        let path = '/projects/' . remote.project . '/snippets'
    else
        let data['content'] = text
        let path = '/snippets'
    endif

    echon 'writing snippet ... '
    call s:set_snippet(remote.root, path, data, 'POST')
endfunction

"[{"id":1700538,"title":"test","file_name":"test.md","description":"test project snippet","author":{"id":1672441,"name":"Steven Humphrey","username":"shumphrey","state":"active","avatar_url":"https://secure.gravatar.com/avatar/a5a6c4ee136cf136c6c379116a0caaeb?s=80\u0026d=identicon","web_url":"https://gitlab.com/shumphrey"},"updated_at":"2018-02-23T19:37:07.150Z","created_at":"2018-02-23T19:37:07.150Z","project_id":5360561,"web_url":"https://gitlab.com/shumphrey/fugitive-gitlab.vim/snippets/1700538"}]
function! gitlab#snippet#list(...) abort
    " calling buffer
    let g:gitlab_snippetlist_caller = bufnr('')

    let bufname = 'gitlab-snippets-list'

    let winnum = bufwinnr(bufnr(bufname))
    if winnum != -1
        if winnum != bufwinnr('%')
            exe winnum 'wincmd w'
        endif
    else
        execute 'silent noautocmd split ' bufname
    endif

    setlocal modifiable
    silent %d _

    try
        let remote = call('s:gitlab_remote', a:000)
    catch
        call s:error(v:errmsg)
        return
    endtry

    redraw | echon 'Listing snippets... '

    let snippets = gitlab#request(remote.root, '/snippets')

    let output = []
    let g:gitlab_snippets = {}
    for snippet in snippets
        let snippet['remote'] = remote
        " 10.7 has project_id, 10.4 does not?
        " work around for gitlab's lacking project_id, work it out from the
        " URL. Also gives us the nicer name or project instead of id
        if match(snippet.web_url, remote.root . '/snippets') < 0
            let url = snippet.web_url
            let url = substitute(url, remote.root . '/', '', '')
            let project = substitute(url, '/snippets.*', '', 'g')
            let snippet['project_id'] = substitute(project, '/', '%2F', 'g')
        else
            let snippet['project_id'] = v:null
        endif
        call add(output, s:snippet_list_output_line(snippet))
        let g:gitlab_snippets[snippet.id] = snippet
    endfor
    call setline(1, output)
    redraw | echon 'Got snippets'

    setlocal nomodified nomodifiable nomodeline nonumber nowrap foldcolumn=0 nofoldenable
    setlocal cursorline
    setlocal filetype=gitlabsnippetlist
    setlocal buftype=nofile bufhidden=hide noswapfile
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
    nohlsearch

    nnoremap <buffer> <silent> <CR> :exe <SID>gitlab_snippet_load()<CR>
    " nnoremap <buffer> <silent> o :exe <SID>gitlab_snippet_load()<CR>
    nnoremap <buffer> <silent> b :exe <SID>gitlab_snippet_browse()<CR>
    nnoremap <buffer> <silent> D :exe <SID>gitlab_snippet_delete()<CR>
    nnoremap <buffer> <silent> dd :exe <SID>gitlab_snippet_delete()<CR>
    " nnoremap <buffer> <silent> y :exe <SID>gitlab_snippet_yank()<CR>
    nnoremap <buffer> <silent> q :bwipeout<CR>
    nnoremap <buffer> <silent> <esc> :bwipeout<CR>

    redraw | echon ''
endfunction

augroup gitlab_snippets
    autocmd!
    " autocmd BufReadPost *.gitlabsnippetlist setfiletype gitlabsnippetlist
    " autocmd FileType gitlabsnippetlist setlocal nomodeline
    autocmd Syntax gitlabsnippetlist call s:gitlab_snippet_list_syntax()

    autocmd BufWritePost gitlabsnippet.* call s:update_gitlab_snippet()
augroup END

function! s:gitlab_snippet_load() abort
    let line = getline('.')
    let id   = matchstr(line, '\v^\d+')

    let snippet = g:gitlab_snippets[id]
    if empty(snippet)
        call s:throw('Invalid snippet id?')
    endif

    let name = snippet.file_name
    if empty(name)
        name = 'empty.txt'
    endif
    let temp = tempname()

    call mkdir(temp)
    let tempsnippet = temp . '/gitlabsnippet.' . fnamemodify(name, ':t')

    let key = gitlab#get_api_key_from_root(snippet.remote.root)

    let headers = [
        \'PRIVATE-TOKEN: ' . key,
        \'Content-Type: application/json',
        \'Accept: application/json',
    \]

    let data = ['-q', '--silent', '-A', 'fugitive-gitlab.vim']
    for header in headers
        call extend(data, ['-H', header])
    endfor
    call extend(data, [snippet.raw_url])

    let options = join(map(copy(data), 'shellescape(v:val)'), ' ')
    call system('curl '.options .'> '.shellescape(tempsnippet))

    exe 'wincmd l|edit '.tempsnippet

    " {'web_url': 'https://gitlab.com/shumphrey/fugitive-gitlab.vim/snippets/1700538', 'id': 1700538, 'author': {'web_url': 'https://gitlab.com/shumphrey', 'id': 1672441, 'name': 'Steven Humphrey', 'avatar_url': 'https://secure.gravatar.com/avatar/a5a6c4ee136cf136c6c379116a0caaeb?s=80&d=identicon', 'state': 'active', 'username': 'shumphrey'}, 'file_name': 'test.md', 'project_id': 5360561, 'created_at': '2018-02-23T19:37:07.150Z', 'description': 'test project snippet', 'updated_at': '2018-02-23T19:37:07.150Z', 'raw_url': 'https://gitlab.com/shumphrey/fugitive-gitlab.vim/snippets/1700538/raw', 'title': 'test'}

    let b:gitlab_snippet = snippet
endfunction!

function! s:gitlab_snippet_delete() abort
    let line = getline('.')
    let id   = matchstr(line, '\v^\d+')

    if confirm('Delete snippet?', "&No\n&Yes") == 1
        return
    endif

    let snippet = remove(g:gitlab_snippets, id)
    if empty(snippet)
        call s:throw('Invalid snippet id?')
    endif

    if !empty(snippet.project_id)
        let path = '/projects/' . snippet.project_id . '/snippets/' . id
    else
        let path = '/snippets/' . id
    endif

    call gitlab#request(snippet.remote.root, path, {}, 'DELETE')

    setlocal modifiable
    silent del
    setlocal nomodifiable
endfunction

function! s:update_gitlab_snippet() abort
    if !exists('b:gitlab_snippet')
        call s:throw('Not editing a gitlab snippet')
    endif

    let lines = join(getline(1, '$'), "\n")

    let id  = get(b:gitlab_snippet, 'id')
    let pid = get(b:gitlab_snippet, 'project_id')
    if !empty(pid)
        let data = {'code': lines}
        let path = '/projects/' . pid . '/snippets/' . id
    else
        let data = {'content': lines}
        let path = '/snippets/' . id
    endif

    call s:set_snippet(b:gitlab_snippet.remote.root, path, data, 'PUT')
endfunction

function! s:set_snippet(root, path, data, method) abort
    let res = gitlab#request(a:root, a:path, a:data, a:method)
    if !has_key(res, 'id')
        call s:throw('api response does not have id')
    endif
    if !exists('g:gitlab_snippets')
        let g:gitlab_snippets = {}
    endif

    let g:gitlab_snippets[res.id] = res
    redraw!

    if has('clipboard')
        let @+ = res.web_url
    endif
    echom res.web_url

    return res
endfunction

function! s:gitlab_snippet_list_syntax() abort
    let b:current_syntax = 'gitlabsnippetlist'
    syn match GitlabSnippetText                     "\v\w+"
    syn match GitlabSnippetID                       "\v^\d+" nextgroup=GitlabSnippetText skipwhite
    hi def link GitlabSnippetID                   Identifier
    hi def link GitlabSnippetText                 String
endfunction

" 1000[P] - Project snippet title
" Should I include project name some how...
function! s:snippet_list_output_line(snippet) abort
    let output = a:snippet.id
    if has_key(a:snippet, 'project_id')
        let output .= (!empty(a:snippet.project_id) ? '[P] ' : '[U] ')
    else
        let output .= ' '
    endif
    let output .= a:snippet.title . ' - ' . a:snippet.description
    return output
endfunction

function! s:parse_args(args) abort
    let options = {}

    let index = 0
    while index < len(a:args)
        let arg = a:args[index]
        let next = get(a:args, index + 1)
        if next =~# '^-' || next =~# '^@'
            let next = 0
        endif

        if arg =~# '^@.'
            let options['remote'] = arg
        elseif arg =~# '^-p$'
            let options['type'] = 'project'
        elseif arg =~# '^-t$' && !empty(next)
            let index = index + 1
            let options['title'] = next
        elseif arg =~# '^-d$' && !empty(next)
            let index = index + 1
            let options['description'] = next
        elseif arg =~# '^-f$' && !empty(next)
            let index = index + 1
            let options['name'] = next
        elseif arg =~# '^-v$' && !empty(next)
            let index = index + 1
            let options['visibility'] = next
        else
            call s:error('Invalid arguments')
            return 0
        endif

        let index = index + 1
    endwhile

    return options
endfunction

function! s:throw(string) abort
    let v:errmsg = 'gitlab: '.a:string
    throw v:errmsg
endfunction

function! s:error(string)
    let v:errmsg = a:string
    echohl ErrorMsg | echomsg a:string | echohl None
endfunction
" vim: set ts=4 sw=4 et foldmethod=indent foldnestmax=1 :
