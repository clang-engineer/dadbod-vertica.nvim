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
  ft = { "sql", "mysql", "plsql" },
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

- **macOS**: `vsql-*.mac.dmg` — universal binary (x86_64 + arm64). Mount it and copy `opt/vertica/bin/vsql` onto your `$PATH` (e.g. `~/bin/`)
- **Linux**: install the Client Drivers `.rpm` or extract the `.tar` — `vsql` lands in `/opt/vertica/bin/vsql`
- **Windows**: run the Client Drivers installer; `vsql.exe` is placed under `%PROGRAMFILES%\Vertica Systems\VSQL\bin`

## Limitations

- Tab completion of database names is not implemented (Vertica clusters typically expose one database, so listing is rarely useful)
- The `tables` introspection filters out the `v_catalog`, `v_monitor`, `v_internal`, `v_func`, `v_txtindex` system schemas — set `g:dadbod_vertica_include_system = 1` is **not** wired yet, open an issue if you need it
- Password handling mirrors vim-dadbod's PostgreSQL adapter — passing on the command line is visible via `ps`

## Tested against

- `vsql` 24.02.x on macOS (universal binary, arm64)
- vim-dadbod master (post-2024)

If you're using this against a different Vertica version, please open an issue with the version + any errors you see.

## License

MIT
