local M = {}

M.config = {
  open_mode = "split",
}

M.adapter = nil

function M.setup(adapter, opts)
  M.adapter = adapter
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
