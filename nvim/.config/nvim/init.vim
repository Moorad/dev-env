lua require('init')

nnoremap <Left> :echo "No left for you!"<CR>
vnoremap <Left> :<C-u>echo "No left for you!"<CR>
inoremap <Left> <C-o>:echo "No left for you!"<CR>

nnoremap <Right> :echo "No right for you!"<CR>
vnoremap <Right> :<C-u>echo "No right for you!"<CR>
inoremap <Right> <C-o>:echo "No right for you!"<CR>

nnoremap <Up> :echo "No up for you!"<CR>
vnoremap <Up> :<C-u>echo "No up for you!"<CR>
inoremap <Up> <C-o>:echo "No up for you!"<CR>

nnoremap <Down> :echo "No down for you!"<CR>
vnoremap <Down> :<C-u>echo "No down for you!"<CR>
inoremap <Down> <C-o>:echo "No down for you!"<CR>

imap jj <Esc>
imap jk <Esc>

vnoremap > >gv
vnoremap < <gv

let mapleader = " "

nnoremap <leader>d "_d
nnoremap <leader>c "_c
nnoremap <leader>x "_x

nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

set clipboard+=unnamedplus

command! W write
