local M = {}

function M.setup(opts)
  vim.g.dadbod_vertica_vsql = (opts or {}).vsql or "vsql"
end

return M
