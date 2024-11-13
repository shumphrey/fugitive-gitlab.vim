" gitlab.vim - gitlab support for fugitive.vim
" Maintainer:   Steven Humphrey <https://github.com/shumphrey>
" Version:      1.1.1

" Plugs in to fugitive.vim and provides a gitlab hook for :GBrowse
" Relies on fugitive.vim by tpope <http://tpo.pe>
" See fugitive.vim for more details
" Requires fugitive.vim 3.0 or greater
"
" If using https://gitlab.com, everything might just work.
" If using a private gitlab, you need to specify the gitlab domains for your
" gitlab instance.
" e.g.
"   let g:fugitive_gitlab_domains = ['https://gitlab.mydomain.com']
"
" Verified working with current gitlab.com in 2024

if exists('g:loaded_fugitive_gitlab')
    finish
endif
let g:loaded_fugitive_gitlab = 1


" Fugitive {{{
if !exists('g:fugitive_browse_handlers')
    let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('gitlab#fugitive#handler')) < 0
    call insert(g:fugitive_browse_handlers, function('gitlab#fugitive#handler'))
endif
" }}}

" gitcommit omnicomplete {{{
function! s:SetUpMessage(filename) abort
    if &omnifunc !~# '^\%(syntaxcomplete#Complete\)\=$' ||
                \ a:filename !~# '\.git[\/].*MSG$'
        return
    endif
    if !exists('g:gitlab_api_keys') || empty(g:gitlab_api_keys)
        return
    endif
    let dir = exists('*FugitiveConfigGetRegexp') ? FugitiveGitDir() : FugitiveExtractGitDir(a:filename)
    if !empty(dir) && !empty(gitlab#fugitive#homepage_for_remote(FugitiveRemoteUrl('', dir)))
        setlocal omnifunc=gitlab#omnifunc#handler
    endif
endfunction

augroup fugitive_gitlab
    autocmd!
    if exists('+omnifunc')
        autocmd FileType gitcommit call s:SetUpMessage(expand('<afile>:p'))
    endif
    autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'gitlab#omnifunc#handler' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END
" }}}

" vim: set ts=4 sw=4 et foldmethod=marker foldnestmax=1 :
