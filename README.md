# fugitive-gitlab.vim

[![Build Status](https://travis-ci.org/shumphrey/fugitive-gitlab.vim.svg?branch=master)](https://travis-ci.org/shumphrey/fugitive-gitlab.vim)

[fugitive.vim][] is undoubtedly the best Git wrapper of all time.

This plugin allows you to use it with https://gitlab.com or your own
private gitlab instance.

* Enables `:Gbrowse` from fugitive.vim to open GitLab URLs

* In commit messages, GitLab issues can be omni-completed
  (`<C-X><C-O>`, see `:help compl-omni`).

## Installation

Install it as you would install [fugitive.vim][]
(you will also need [fugitive.vim][] installed)

To use private gitlab repositories add the following to your .vimrc

    let g:fugitive_gitlab_domains = ['https://my.gitlab.com']

fugitive command `:Gbrowse` will now work with gitlab URLs.

[Curl](http://curl.haxx.se/) is required for features
that use the GitLab API (i.e., `:Gbrowse` doesn't need it).
[Generate a personal access token](https://gitlab.com/profile/personal_access_tokens)
with api permissions and add it to your vimrc

    let g:gitlab_api_keys = {'gitlab.com': 'myaccesstoken'}

To use omnicompletion with a private gitlab repository

    let g:gitlab_api_keys = {'gitlab.com': 'mytoken1', 'my.gitlab.private': 'mytoken2' }

Omnicompletion functionality is subject to change.

## Requirements

fugitive-gitlab.vim requires a modern [fugitive.vim][].
API features require a gitlab instance with v4 of the API.

[fugitive.vim]: https://github.com/tpope/vim-fugitive

## FAQ

> How do I turn off that preview window that shows the issue body?

    set completeopt-=preview

> Why doesn't this plugin have a pun name?

I couldn't think of one.

## License

Copyright (c) Steven Humphrey.  Distributed under the same terms as Vim itself.
See `:help license`.
