local M = {}

function M.setup(opts)
  opts = opts or {}
  if opts.vsql ~= nil then
    vim.g.dadbod_vertica_vsql = opts.vsql
  end
end

return M
