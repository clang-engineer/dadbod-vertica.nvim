# dadbod-vertica.nvim

[Vertica](https://www.vertica.com/) adapter for [vim-dadbod](https://github.com/tpope/vim-dadbod), wired through the official `vsql` client.

Lets you connect to Vertica with the same URL-driven workflow you already use for PostgreSQL/MySQL in dadbod and [dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui) — schema browsing, query buffers, result splits, completion.

## Requirements

- [vim-dadbod](https://github.com/tpope/vim-dadbod)
- `vsql` client on `$PATH` (see [vsql install](#installing-vsql))
- Neovim 0.7+ (works on Vim too — Lua entry is optional)

## Install

### lazy.nvim

```lua
{
  "clang-engineer/dadbod-vertica.nvim",
  dependencies = { "tpope/vim-dadbod" },
  -- plugin/dadbod-vertica.vim registers dadbod-ui table helpers and patches
  -- the schema tree, so it must source on every DBUI entry point — not just
  -- the first SQL buffer.
  cmd = { "DB", "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
  -- optional: only needed if vsql is not on PATH
  opts = { vsql = "/opt/vertica/bin/vsql" },
}
```

### packer.nvim

```lua
use {
  "clang-engineer/dadbod-vertica.nvim",
  requires = "tpope/vim-dadbod",
  config = function()
    require("dadbod-vertica").setup({})
  end,
}
```

### vim-plug

```vim
Plug 'tpope/vim-dadbod'
Plug 'clang-engineer/dadbod-vertica.nvim'
```

No `setup()` call needed if `vsql` is on `$PATH`.

## Usage

URL scheme is `vertica://`:

```
vertica://user@host:5433/database
vertica://user:password@host:5433/database
```

Add to `vim.g.dbs` (for dadbod-ui):

```lua
vim.g.dbs = {
  { name = "vertica local", url = "vertica://dbadmin@localhost:5433/VMart" },
  { name = "vertica prod",  url = "vertica://reporter@warehouse.corp:5433/ANALYTICS" },
}
```

Then `:DBUIToggle` and the entry shows up alongside your other databases.

For one-off queries:

```vim
:DB vertica://dbadmin@localhost:5433/VMart SELECT current_user();
```

## Configuration

```lua
require("dadbod-vertica").setup({
  vsql = "vsql",  -- absolute path if vsql is not on $PATH
})
```

Or set it directly via vimscript:

```vim
let g:dadbod_vertica_vsql = '/opt/vertica/bin/vsql'
```

## Authentication

Pick one of:

| Method | Notes |
|--------|-------|
| `vertica://user:password@host/db` URL | Simplest. Password ends up in `ps` output — fine for local/throwaway, avoid for shared machines |
| `VSQL_PASSWORD` env var | Set in your shell rc. Single password for all connections |
| vsql interactive prompt | Works for `:DB <url>` interactive mode; will hang on non-interactive query buffers |

URL credentials win over env vars.

## Installing vsql

`vsql` is not on Homebrew. Download from the official [Vertica Client Drivers](https://www.vertica.com/download/vertica/client-drivers/) page (no signup required) and pick the right package for your OS:

- **macOS**: `vsql-*.mac.dmg` — universal binary (x86_64 + arm64). Mount it and copy `opt/vertica/bin/vsql` onto your `$PATH`. **`/usr/local/bin/` is safest** because it ships on the default macOS PATH; `~/bin/` works too, but only if your shell rc actually puts `~/bin` on `$PATH` (default zsh does not)
- **Linux**: install the Client Drivers `.rpm` or extract the `.tar` — `vsql` lands in `/opt/vertica/bin/vsql`
- **Windows**: run the Client Drivers installer; `vsql.exe` is placed under `%PROGRAMFILES%\Vertica Systems\VSQL\bin`

Skip `$PATH` entirely by pointing the plugin straight at the binary:

```lua
opts = { vsql = "/opt/vertica/bin/vsql" }   -- or wherever you put it
```

## Troubleshooting

**Query result buffer is empty / SELECT shows nothing.** By default we wrap `vsql` so its server-side license NOTICE on stderr is discarded — but this also swallows real query errors. Flip the suppressor off to see what vsql is actually saying:

```vim
let g:dadbod_vertica_suppress_notice = 0
```

Re-run the query and the stderr message will land in the result buffer alongside the data.

**Neovim freezes when the host is unreachable.** vim-dadbod runs `vsql` synchronously via `system()`, so a network-unreachable host blocks the UI thread until the TCP connect times out (~75s on macOS by default). vsql has no command-line connect-timeout flag, but you can shorten the wait in your shell rc:

```sh
export VSQL_LOGIN_TIMEOUT=5
```

(Honored by recent vsql builds; behavior is version-dependent.)

## Limitations

- Tab completion of database names is not implemented (Vertica clusters typically expose one database, so listing is rarely useful)
- Schema introspection always hides the `v_catalog`, `v_monitor`, `v_internal`, `v_func`, `v_txtindex` system schemas. Override the list via `let g:dadbod_vertica_system_schemas = [...]` if you need a different exclude set (set it to `[]` to show everything)
- Password handling mirrors vim-dadbod's PostgreSQL adapter — passing on the command line is visible via `ps`
- **dadbod-ui schema-tree integration is a monkey-patch.** vim-dadbod-ui's `s:schemas` dict is script-local with no public hook, so we override `db_ui#schemas#get` after snapshotting the existing entries. If vim-dadbod-ui adds a new scheme in a later release, this plugin won't expose it until updated — open an issue. Disable the monkey-patch with `let g:dadbod_vertica_disable_schema_tree = 1` (tables fall back to a flat list under the DB node)
- **Windows NOTICE banner**: the stderr-suppression wrap only kicks in on Unix (`has('unix')`). On Windows the Vertica license NOTICE may surface inside result buffers

## Tested against

- `vsql` 24.02.x on macOS (universal binary, arm64)
- vim-dadbod master (post-2024)

If you're using this against a different Vertica version, please open an issue with the version + any errors you see.

## License

MIT
