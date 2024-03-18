#!/usr/bin/env bash

docker build -f test/Dockerfile -t fugitive_gitlab --load .

docker run --rm -v `pwd`:/test/fugitive-gitlab.vim -w '/test' fugitive_gitlab vim -Es -Nu vimrc -c 'Vader! fugitive-gitlab.vim/test/*' > /dev/null
docker run --rm -v `pwd`:/test/fugitive-gitlab.vim -w '/test' fugitive_gitlab nvim -Es -Nu vimrc -c 'Vader! fugitive-gitlab.vim/test/*' > /dev/null
