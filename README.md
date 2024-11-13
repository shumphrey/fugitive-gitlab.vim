# fugitive-gitlab.vim

[![Fugitive GitLab](https://github.com/shumphrey/fugitive-gitlab.vim/actions/workflows/vader.yml/badge.svg?branch=master)](https://github.com/shumphrey/fugitive-gitlab.vim/actions/workflows/vader.yml)

[fugitive.vim][] is undoubtedly the best Git wrapper of all time.

This plugin allows you to use it with https://gitlab.com or your own
private GitLab instance.

* Enables `:GBrowse` from fugitive.vim to open GitLab URLs

* In commit messages, GitLab issues and users can be omni-completed
  (`<C-X><C-O>`, see `:help compl-omni`).

## Installation

Install it as you would install [fugitive.vim][]
(you will also need [fugitive.vim][] installed)

To use private GitLab instances, add the following to your .vimrc

    let g:fugitive_gitlab_domains = ['https://my.gitlab.com']

If the private GitLab instance uses different URLs, for example, one for SSH
and another for HTTPS, instead add the following to your .vimrc

    let g:fugitive_gitlab_domains = {'my-ssh.gitlab.com': 'https://my.gitlab.com'}

Fugitive command `:GBrowse` will now work with GitLab URLs.

[Curl](http://curl.haxx.se/) is required for features
that use the GitLab API (i.e., `:GBrowse` doesn't need it).
[Generate a personal access token](https://gitlab.com/-/user_settings/personal_access_tokens)
with api permissions and add it to your vimrc

    let g:gitlab_api_keys = {'gitlab.com': 'myaccesstoken'}

To use omnicompletion with a private GitLab repository

    let g:gitlab_api_keys = {'gitlab.com': 'mytoken1', 'my.gitlab.private': 'mytoken2' }

Omnicompletion functionality is subject to change.

## Requirements

fugitive-gitlab.vim requires a modern [fugitive.vim][].
API features require a GitLab instance with v4 of the API.

[fugitive.vim]: https://github.com/tpope/vim-fugitive

## FAQ

> How do I turn off that preview window that shows the issue body?

    set completeopt-=preview

> :GBrowse produces 404s on my old self hosted GitLab

    let g:fugitive_gitlab_oldstyle_urls = 1

> Why doesn't this plugin have a pun name?

I couldn't think of one.
