" gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.1.1

" Plugs in to fugitive.vim and provides a gitlab hook for :GBrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
" Requires fugitive.vim 2.1 or greater
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['https://gitlab.mydomain.com']
"
" known to work with gitlab 7.14.1 on 2015-09-14

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('gitlab#fugitive_handler')) < 0
    call insert(g:fugitive_browse_handlers, function('gitlab#fugitive_handler'))
endif

function! s:SetUpMessage(filename) abort
  if &omnifunc !~# '^\%(syntaxcomplete#Complete\)\=$' ||
        \ a:filename !~# '\.git[\/].*MSG$'
    return
  endif
  if !exists('g:gitlab_api_keys') || empty(g:gitlab_api_keys)
      return
  endif
  let dir = exists('*FugitiveConfigGetRegexp') ? FugitiveGitDir() : FugitiveExtractGitDir(a:filename)
  if !empty(dir) && !empty(gitlab#homepage_for_remote(FugitiveRemoteUrl('', dir)))
    setlocal omnifunc=gitlab#omnifunc
  endif
endfunction

augroup gitlab
  autocmd!
  if exists('+omnifunc')
    autocmd FileType gitcommit call s:SetUpMessage(expand('<afile>:p'))
  endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'gitlab#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END

let g:gitlab_snippets = {}

" autocompletion for :Gsnip command
" completes the previous snippet id and the remote name
function! s:write_snippet_comp(lead, cmd, pos) abort
    let list = ['-p', '-u']

    let remotes = keys(g:gitlab_api_keys)
    try
        let repo = fugitive#repo()
        call extend(remotes, split(repo.git_chomp('remote', 'show'), "\n"))
    catch
    endtry

    call extend(list, map(remotes, '"@" . v:val'))

    return filter(list, 'v:val =~# "^' . a:lead . '"')
endfunction

function! s:list_snippet_comp(lead, cmd, pos) abort
    let list = []

    let remotes = keys(g:gitlab_api_keys)
    try
        let repo = fugitive#repo()
        call extend(remotes, split(repo.git_chomp('remote', 'show'), "\n"))
    catch
    endtry

    call extend(list, map(remotes, '"@" . v:val'))

    return filter(list, 'v:val =~# "^' . a:lead . '"')
endfunction

command! -nargs=* -complete=customlist,s:list_snippet_comp GsnipList call gitlab#snippet#list(<f-args>)
command! -bar -bang -range=% -nargs=* -complete=customlist,s:write_snippet_comp Gsnip call gitlab#snippet#write(<bang>0, <line1>, <line2>, <f-args>)

" vim: set ts=4 sw=4 et
