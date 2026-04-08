local M = {}

M.config = {
  open_mode = "split",
}

function M.setup(_, opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
