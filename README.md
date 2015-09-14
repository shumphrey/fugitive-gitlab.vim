# fugitive-gitlab.vim

fugitive.vim is undoubtedly the best Git wrapper of all time.

This plugin allows you to use it with https://gitlab.com or your own
private gitlab instance.

Install it as you would install fugitive.vim.

To use private gitlab repositories add the follow to your .vimrc

    let g:fugitive_gitlab_domains = ['http://mygitlab', 'http://mygitlab.mydomain.com']

fugitive command :Gbrowse will now work with gitlab URLs.

## Requirements

fugitive-gitlab.vim requires [fugitive.vim](https://github.com/tpope/vim-fugitive) 2.1 or higher to function.
