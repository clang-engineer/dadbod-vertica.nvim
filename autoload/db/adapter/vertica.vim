" Location: autoload/db/adapter/vertica.vim
" Maintainer: clang-engineer <clang.engineer@gmail.com>
" License: MIT
" Description: vim-dadbod adapter for Vertica via the vsql client.

function! s:vsql() abort
  return get(g:, 'dadbod_vertica_vsql', 'vsql')
endfunction

function! db#adapter#vertica#canonicalize(url) abort
  let url = substitute(a:url, '^[^:]*:/\=/\@!', 'vertica:///', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'host': 'host',
        \ 'port': 'port',
        \ 'dbname': 'database'})
endfunction

function! s:base_command(url) abort
  let parsed = db#url#parse(a:url)
  let cmd = [s:vsql()]
  if has_key(parsed, 'host')
    let cmd += ['-h', parsed.host]
  endif
  if has_key(parsed, 'port')
    let cmd += ['-p', parsed.port]
  endif
  if !empty(get(parsed, 'user', ''))
    let cmd += ['-U', parsed.user]
  endif
  if !empty(get(parsed, 'password', ''))
    let cmd += ['-w', parsed.password]
  endif
  let path = get(parsed, 'path', '')
  if !empty(path) && path !=# '/'
    let cmd += ['-d', substitute(path, '^/', '', '')]
  endif
  return cmd
endfunction

function! db#adapter#vertica#interactive(url, ...) abort
  return s:base_command(a:url) + (a:0 ? a:1 : [])
endfunction

function! db#adapter#vertica#filter(url) abort
  " vsql does not support '-P columns=N' (psql-only); '-X' replaces '--no-psqlrc'.
  return db#adapter#vertica#interactive(a:url, ['-X', '-v', 'ON_ERROR_STOP=1'])
endfunction

function! db#adapter#vertica#input(url, in) abort
  return db#adapter#vertica#filter(a:url) + ['-f', a:in]
endfunction

function! s:parse_rows(output, col) abort
  let rows = map(copy(a:output), 'split(v:val, "|")')
  return map(filter(rows, 'len(v:val) > a:col'), 'v:val[a:col]')
endfunction

function! s:user_schema_filter() abort
  return "table_schema NOT IN ('v_catalog', 'v_monitor', 'v_internal', 'v_func', 'v_txtindex')"
endfunction

function! db#adapter#vertica#tables(url) abort
  let filter = s:user_schema_filter()
  let query = "SELECT table_schema || '.' || table_name FROM v_catalog.tables WHERE " . filter
        \ . " UNION ALL SELECT table_schema || '.' || table_name FROM v_catalog.views WHERE " . filter
        \ . " ORDER BY 1;"
  return s:parse_rows(db#systemlist(
        \ db#adapter#vertica#filter(a:url) + ['-tA', '-c', query]), 0)
endfunction
