" Location: plugin/dadbod-vertica.vim
" Maintainer: clang-engineer <clang.engineer@gmail.com>
" License: MIT
" Description: Extend vim-dadbod-ui so the vertica scheme behaves like the
" postgres scheme: a schema-grouped tree (Schemas → schema → tables) plus the
" full set of table helpers (List/Columns/Primary Keys/Indexes/References/
" Foreign Keys). Vertica has no traditional indexes — 'Indexes' surfaces
" v_catalog.projections instead.

if exists('g:loaded_dadbod_vertica')
  finish
endif
let g:loaded_dadbod_vertica = 1

" ---------------------------------------------------------------------------
" Table helpers
" ---------------------------------------------------------------------------
" When schema_support is active (the default — see the schema injection
" block below), {table} is just the unqualified table name and {schema}
" carries the schema. If schema_support is disabled (user set
" g:dadbod_vertica_disable_schema_tree = 1), vim-dadbod-ui falls back to
" calling db#adapter#vertica#tables() and the helpers below will not be able
" to resolve the schema — that mode is best-effort only.

if !exists('g:db_ui_table_helpers')
  let g:db_ui_table_helpers = {}
endif

" Dict insertion order = display order in the dadbod-ui tree.
let s:vertica_helpers = {
      \ 'List': 'SELECT * FROM {optional_schema}"{table}" LIMIT 200',
      \ 'Columns': "SELECT * FROM v_catalog.columns WHERE table_schema = '{schema}' AND table_name = '{table}' ORDER BY ordinal_position",
      \ 'Primary Keys': "SELECT * FROM v_catalog.primary_keys WHERE table_schema = '{schema}' AND table_name = '{table}'",
      \ 'Indexes': "SELECT * FROM v_catalog.projections WHERE anchor_table_schema = '{schema}' AND anchor_table_name = '{table}'",
      \ 'References': "SELECT * FROM v_catalog.foreign_keys WHERE reference_table_schema = '{schema}' AND reference_table_name = '{table}'",
      \ 'Foreign Keys': "SELECT * FROM v_catalog.foreign_keys WHERE table_schema = '{schema}' AND table_name = '{table}'",
      \ }

" User overrides win — extend with user dict last.
let g:db_ui_table_helpers.vertica = extend(s:vertica_helpers,
      \ get(g:db_ui_table_helpers, 'vertica', {}))

" ---------------------------------------------------------------------------
" Schema-tree injection
" ---------------------------------------------------------------------------
" vim-dadbod-ui only renders the 'Schemas → schema → tables' hierarchy when
" the scheme has an entry in its internal s:schemas dict (script-local, no
" public hook). We work around it by overriding db_ui#schemas#get(): we
" snapshot every known scheme into our own cache *first* (so postgres/mysql/
" etc. keep working), add a vertica entry, and replace the lookup function.
"
" Maintenance trade-off: if vim-dadbod-ui adds a new scheme later, our
" cached snapshot won't pick it up until this plugin is reloaded. The
" snapshot is taken via db#adapter#schemes() (all dadbod adapters on
" runtimepath), so any scheme dadbod itself knows about is captured.

if get(g:, 'dadbod_vertica_disable_schema_tree', 0)
  finish
endif

let s:sys_schemas = "'v_catalog','v_monitor','v_internal','v_func','v_txtindex'"

" Mirrors vim-dadbod-ui's s:results_parser (script-local, can't reuse).
function! s:results_parser(results, delimiter, min_len) abort
  if a:min_len ==? 1
    return filter(a:results, '!empty(trim(v:val))')
  endif
  let mapped = map(a:results, {_,row -> filter(split(row, a:delimiter), '!empty(trim(v:val))')})
  if a:min_len > 1
    return filter(mapped, 'len(v:val) ==? '.a:min_len)
  endif
  let counts = map(copy(mapped), 'len(v:val)')
  let min_len = max(counts)
  return filter(mapped, 'len(v:val) ==? '.min_len)
endfunction

" callable=filter routes catalog queries through db#adapter#vertica#filter,
" which carries the sh-wrap that swallows the Vertica license NOTICE on
" stderr — without it the banner pollutes the result and breaks parsing.
let s:vertica_scheme = {
      \ 'callable': 'filter',
      \ 'args': ['-A', '-c'],
      \ 'schemes_query': "SELECT schema_name FROM v_catalog.schemata WHERE schema_name NOT IN (" . s:sys_schemas . ") ORDER BY schema_name",
      \ 'schemes_tables_query':
      \   "SELECT table_schema, table_name FROM v_catalog.tables WHERE table_schema NOT IN (" . s:sys_schemas . ")"
      \   . " UNION ALL"
      \   . " SELECT table_schema, table_name FROM v_catalog.views WHERE table_schema NOT IN (" . s:sys_schemas . ")"
      \   . " ORDER BY 1, 2",
      \ 'parse_results': {results, min_len -> s:results_parser(filter(results, '!empty(v:val)')[1:-2], '|', min_len)},
      \ 'default_scheme': '',
      \ 'quote': 1,
      \ }

function! s:inject_vertica_schema() abort
  if exists('s:schemes_cache')
    return
  endif
  silent! runtime autoload/db_ui/schemas.vim
  if !exists('*db_ui#schemas#get')
    return
  endif

  " Snapshot before override: Vim funcrefs resolve by name, so once we
  " redefine the function there is no way to call the original. We pull each
  " known scheme out individually while we still can.
  let s:schemes_cache = {}
  for scheme in db#adapter#schemes()
    let entry = db_ui#schemas#get(scheme)
    if !empty(entry)
      let s:schemes_cache[scheme] = entry
    endif
  endfor
  let s:schemes_cache.vertica = s:vertica_scheme

  function! db_ui#schemas#get(scheme) abort
    return get(s:schemes_cache, a:scheme, {})
  endfunction
endfunction

" Try immediately. Works when vim-dadbod-ui is already on the runtimepath
" (e.g. startup-loaded). If it isn't — the common LazyVim setup loads it via
" `cmd = { "DBUI*" }` — defer until vim-dadbod-ui's plugin file sources, which
" happens before its command body runs.
call s:inject_vertica_schema()
if !exists('s:schemes_cache')
  augroup dadbod_vertica_schema_inject
    autocmd!
    autocmd SourcePost */vim-dadbod-ui/plugin/db_ui.vim ++once call s:inject_vertica_schema()
  augroup END
endif
