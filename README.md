# fugitive-gitlab.vim

fugitive.vim is undoubtedly the best Git wrapper of all time.

This plugin allows you to use your own gitlab instance with it.

Install it as you would install fugitive.vim.

then in your .vimrc

    let g:fugitive_gitlab_domains = [
        'http://gitlab',
        'http://gitlab.mydomain.com'
    ]

fugitive command :Gbrowse will now work with gitlab URLs.
