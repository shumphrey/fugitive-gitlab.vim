FROM debian:latest

WORKDIR /test
RUN apt-get update && apt-get install -y vim git curl neovim && \
    git clone https://github.com/tpope/vim-fugitive.git && \
    git clone https://github.com/junegunn/vader.vim.git && \
    apt-get clean

ADD test/vimrc /test/

CMD vim -Nu vimrc
