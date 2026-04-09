local M = {}

--- Open a scratch buffer for editing a commit message.
--- On :w, filters comment lines and calls save_fn with the text.
--- opts: { setup_keymaps = function(bufnr, discard_and_close), statusline = string }
function M.open_editor(buffer_name, initial_text, help_lines, save_fn, opts)
  opts = opts or {}
  local ui = require("fugitive-core.ui")

  local bufnr = ui.create_scratch_buffer({
    name = buffer_name,
    buftype = "acwrite",
    filetype = "gitcommit",
    modifiable = true,
    bufhidden = "hide",
  })

  local lines = vim.list_extend({}, help_lines)
  table.insert(lines, "")
  vim.list_extend(lines, vim.split(initial_text or "", "\n", { plain = true }))

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local filtered = {}
      for _, line in ipairs(buf_lines) do
        if not line:match("^%s*#") then
          table.insert(filtered, line)
        end
      end

      local text = table.concat(filtered, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if save_fn(text) then
        vim.bo[bufnr].modified = false
        vim.cmd(ui.close_cmd())
      end
    end,
  })

  local function discard_and_close()
    vim.bo[bufnr].modified = false
    vim.cmd(ui.close_cmd())
  end

  ui.map(bufnr, "n", "q", discard_and_close)

  if opts.setup_keymaps then
    opts.setup_keymaps(bufnr, discard_and_close)
  end

  ui.open_pane()
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, { #help_lines + 2, 0 })

  if opts.statusline then
    ui.set_statusline(bufnr, opts.statusline)
  end

  return bufnr
end

return M
