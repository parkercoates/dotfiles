set nocompatible

set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

set lcs=tab:»·
set lcs+=trail:·
set list

set number

set showmatch

set incsearch

set novisualbell

"Whitespace stuff

nnoremap <Space> i<Space><Esc>l
nnoremap <CR> o<Esc>

"Notes stuff
command DateStamp r !date +"<\%F \%A>"

inoremap <F2> <C-K>2S
inoremap <F3> <C-K>3S

"Haskellmode stuff
au Bufenter *.hs compiler ghc

syntax on
filetype plugin on

let g:haddock_browser = "/home/parker/bin/elinksnewtab"
let g:haddock_indexfiledir = "/home/parker/.vim/"

command Hlint w !hlint %
command Main GHCI main

