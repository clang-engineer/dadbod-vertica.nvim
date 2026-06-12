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
    " vsql diverges from psql here: psql -w is --no-password (boolean), but
    " vsql -w accepts the password as its value. Don't 'fix' this back to a
    " psql-style flag.
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
  " -X: skip vsqlrc / -q: quiet startup banner. vsql does not accept
  " '-P columns=N' (psql-only) or '--no-psqlrc'.
  let base = db#adapter#vertica#interactive(a:url, ['-X', '-q', '-v', 'ON_ERROR_STOP=1'])
  if !has('unix') || !get(g:, 'dadbod_vertica_suppress_notice', 1)
    return base
  endif
  " Wrap so server-side license NOTICE (stderr) is discarded before dadbod
  " captures output. $@ forwards every arg — base + dadbod-appended — to vsql
  " without any client-side quoting.
  return ['/bin/sh', '-c', '"$@" 2>/dev/null', 'dbvertica-sh'] + base
endfunction

function! db#adapter#vertica#input(url, in) abort
  return db#adapter#vertica#filter(a:url) + ['-f', a:in]
endfunction

function! s:user_schema_filter() abort
  " Shares the system-schema list with plugin/dadbod-vertica.vim. The plugin
  " file always sources at startup and sets the default, so this fallback
  " only matters if a user loads the autoload adapter standalone.
  let schemas = get(g:, 'dadbod_vertica_system_schemas',
        \ ['v_catalog', 'v_monitor', 'v_internal', 'v_func', 'v_txtindex'])
  if empty(schemas)
    return '1=1'
  endif
  return "table_schema NOT IN ('" . join(schemas, "','") . "')"
endfunction

function! db#adapter#vertica#tables(url) abort
  let filter = s:user_schema_filter()
  " Belt-and-braces: db#adapter#vertica#filter already drops stderr and we
  " pass -tA so vsql prints tuples only. But some vsql builds still flush a
  " license/NOTICE line to stdout before the result set, so we prefix every
  " data row with a marker and discard anything that doesn't match.
  let marker = '__DBV_ROW__'
  let query = "SELECT '" . marker . "' || table_schema || '.' || table_name FROM v_catalog.tables WHERE " . filter
        \ . " UNION ALL SELECT '" . marker . "' || table_schema || '.' || table_name FROM v_catalog.views WHERE " . filter
        \ . " ORDER BY 1;"
  let lines = db#systemlist(db#adapter#vertica#filter(a:url) + ['-tA', '-c', query])
  let prefix_len = len(marker)
  return map(filter(lines, 'strpart(v:val, 0, prefix_len) ==# marker'),
        \ 'v:val[prefix_len :]')
endfunction
