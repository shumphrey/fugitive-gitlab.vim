#!/usr/bin/env bash

unset CDPATH

cd "$( dirname "${BASH_SOURCE[0]}" )"

if [[ ! -d "../../vader.vim" ]] && [[ ! -d "../vader.vim" ]]; then
    echo "No ../vader.vim"
    exit 1
fi
if [[ ! -d "../../vim-fugitive" ]] && [[ ! -d "../vim-fugitive" ]]; then
    echo "No ../vim-fugitive"
    exit 1
fi

vim -Nu vimrc -c 'Vader! *' > /dev/null
