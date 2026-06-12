" Location: plugin/dadbod-vertica.vim
" Maintainer: clang-engineer <clang.engineer@gmail.com>
" License: MIT
" Description: Register dadbod-ui table helpers for the vertica scheme so the
" tree shows List/Columns/Primary Keys/Foreign Keys/References/Indexes
" submenus (matching the postgres layout). Vertica has no traditional
" indexes — 'Indexes' surfaces v_catalog.projections instead.

if exists('g:loaded_dadbod_vertica')
  finish
endif
let g:loaded_dadbod_vertica = 1

if !exists('g:db_ui_table_helpers')
  let g:db_ui_table_helpers = {}
endif

" dadbod-ui's s:schemas dict has no vertica entry, so the drawer takes the
" fallback path: it calls db#adapter#vertica#tables(), which returns each
" entry as the joined string 'schema.table'. That whole string lands in
" {table}; {schema} is left empty. The queries below therefore use {table}
" directly as a schema-qualified reference and SPLIT_PART it for catalog
" lookups instead of relying on {schema}.
" Dict insertion order = display order in the dadbod-ui tree.
let s:vertica_helpers = {
      \ 'List': 'SELECT * FROM {table} LIMIT 200',
      \ 'Columns': "SELECT * FROM v_catalog.columns WHERE table_schema = SPLIT_PART('{table}', '.', 1) AND table_name = SPLIT_PART('{table}', '.', 2) ORDER BY ordinal_position",
      \ 'Primary Keys': "SELECT * FROM v_catalog.primary_keys WHERE table_schema = SPLIT_PART('{table}', '.', 1) AND table_name = SPLIT_PART('{table}', '.', 2)",
      \ 'Indexes': "SELECT * FROM v_catalog.projections WHERE anchor_table_schema = SPLIT_PART('{table}', '.', 1) AND anchor_table_name = SPLIT_PART('{table}', '.', 2)",
      \ 'References': "SELECT * FROM v_catalog.foreign_keys WHERE reference_table_schema = SPLIT_PART('{table}', '.', 1) AND reference_table_name = SPLIT_PART('{table}', '.', 2)",
      \ 'Foreign Keys': "SELECT * FROM v_catalog.foreign_keys WHERE table_schema = SPLIT_PART('{table}', '.', 1) AND table_name = SPLIT_PART('{table}', '.', 2)",
      \ }

" User overrides win — extend with user dict last.
let g:db_ui_table_helpers.vertica = extend(s:vertica_helpers,
      \ get(g:db_ui_table_helpers, 'vertica', {}))
