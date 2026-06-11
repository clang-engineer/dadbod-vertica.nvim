local M = {}

M.config = {
  vsql = "vsql",
}

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  vim.g.dadbod_vertica_vsql = M.config.vsql
end

return M
