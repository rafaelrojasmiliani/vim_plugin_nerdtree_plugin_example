" autoload/nerdtree_fugitive.vim - lazy-loaded functions for NERDTree/Fugitive integration

let s:filter_registered = 0

function! nerdtree_fugitive#open_modified_tree() abort
  if !exists('*NERDTreeAddPathFilter')
    echohl ErrorMsg | echom 'nerdtree_fugitive: NERDTree is required.' | echohl None
    return
  endif

  let l:root = nerdtree_fugitive#repo_root()
  if empty(l:root)
    echohl ErrorMsg | echom 'nerdtree_fugitive: could not find git repository root.' | echohl None
    return
  endif

  call nerdtree_fugitive#build_modified_index(l:root)
  call nerdtree_fugitive#register_filter_once()

  execute 'NERDTree' fnameescape(l:root)
endfunction

function! nerdtree_fugitive#repo_root() abort
  if exists('*FugitiveWorkTree')
    let l:root = FugitiveWorkTree()
    if !empty(l:root)
      return fnamemodify(l:root, ':p')
    endif
  endif

  let l:raw = systemlist('git rev-parse --show-toplevel 2>/dev/null')
  if v:shell_error != 0 || empty(l:raw)
    return ''
  endif
  return fnamemodify(l:raw[0], ':p')
endfunction

function! nerdtree_fugitive#build_modified_index(root) abort
  let l:cmd = 'git -C ' . shellescape(a:root) . ' status --porcelain'
  let l:lines = systemlist(l:cmd)

  let g:nerdtree_fugitive_root = nerdtree_fugitive#normalize_path(a:root)
  let g:nerdtree_fugitive_modified = {}
  let g:nerdtree_fugitive_modified_dirs = {}

  for l:line in l:lines
    if l:line =~# '^.. '
      let l:path = strpart(l:line, 3)
      if l:path =~# ' -> '
        let l:path = matchstr(l:path, ' -> \zs.*$')
      endif
      call nerdtree_fugitive#track_path(l:path)
    endif
  endfor
endfunction

function! nerdtree_fugitive#track_path(path) abort
  let l:clean = substitute(a:path, '^"\|"$', '', 'g')
  let l:full = nerdtree_fugitive#normalize_path(g:nerdtree_fugitive_root . '/' . l:clean)
  let l:rel = nerdtree_fugitive#relpath(l:full)

  let g:nerdtree_fugitive_modified[l:rel] = 1

  let l:parts = split(l:rel, '/')
  if len(l:parts) <= 1
    return
  endif

  let l:prefix = ''
  for l:i in range(0, len(l:parts) - 2)
    let l:prefix = empty(l:prefix) ? l:parts[l:i] : l:prefix . '/' . l:parts[l:i]
    let g:nerdtree_fugitive_modified_dirs[l:prefix] = 1
  endfor
endfunction

function! nerdtree_fugitive#register_filter_once() abort
  if s:filter_registered
    return
  endif
  call NERDTreeAddPathFilter('nerdtree_fugitive#path_filter')
  let s:filter_registered = 1
endfunction

function! nerdtree_fugitive#path_filter(path) abort
  try
    if !exists('g:nerdtree_fugitive_modified') || !exists('g:nerdtree_fugitive_modified_dirs') || !exists('g:nerdtree_fugitive_root')
      return 0
    endif

    let l:absolute = nerdtree_fugitive#path_to_abs(a:path)
    if empty(l:absolute)
      return 1
    endif

    let l:rel = nerdtree_fugitive#relpath(l:absolute)
    if empty(l:rel)
      return 0
    endif

    if has_key(g:nerdtree_fugitive_modified, l:rel)
      return 0
    endif

    if has_key(g:nerdtree_fugitive_modified_dirs, l:rel)
      return 0
    endif

    return 1
  catch
    " Be conservative: if we cannot evaluate a path, hide it.
    return 1
  endtry
endfunction

function! nerdtree_fugitive#path_to_abs(path) abort
  if type(a:path) == v:t_string
    return nerdtree_fugitive#normalize_under_root(a:path)
  endif

  " NERDTree path objects differ between versions; probe methods/fields safely.
  try
    return nerdtree_fugitive#normalize_under_root(a:path.str())
  catch
  endtry

  try
    return nerdtree_fugitive#normalize_under_root(a:path._str())
  catch
  endtry

  try
    return nerdtree_fugitive#normalize_under_root(a:path.path.str())
  catch
  endtry

  try
    return nerdtree_fugitive#normalize_under_root(a:path.path)
  catch
  endtry

  return ''
endfunction

function! nerdtree_fugitive#relpath(absolute_path) abort
  let l:absolute = nerdtree_fugitive#normalize_path(a:absolute_path)
  let l:root = g:nerdtree_fugitive_root

  if l:absolute ==# l:root
    return ''
  endif

  let l:prefix = l:root . '/'
  if stridx(l:absolute, l:prefix) == 0
    return strpart(l:absolute, strlen(l:prefix))
  endif

  return l:absolute
endfunction

function! nerdtree_fugitive#normalize_path(path) abort
  return substitute(fnamemodify(a:path, ':p'), '/$', '', '')
endfunction

function! nerdtree_fugitive#normalize_under_root(path) abort
  if empty(a:path)
    return ''
  endif

  if a:path =~# '^/' || a:path =~# '^[A-Za-z]:[/\\]'
    return nerdtree_fugitive#normalize_path(a:path)
  endif

  return nerdtree_fugitive#normalize_path(g:nerdtree_fugitive_root . '/' . a:path)
endfunction
