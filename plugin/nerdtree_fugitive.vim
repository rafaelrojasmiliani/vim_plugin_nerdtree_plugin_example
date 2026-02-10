" nerdtree_fugitive.vim - plugin entrypoint
" Loaded on startup; wires NERDTree commands to Fugitive helpers.

if exists('g:loaded_nerdtree_fugitive')
  finish
endif
let g:loaded_nerdtree_fugitive = 1

command! -bar NERDTreeModified call nerdtree_fugitive#open_modified_tree()
