local M = {}

--- Show a list-type view (status, bookmark, etc.).
--- Handles the find-or-create buffer + set lines + ensure visible + cursor + statusline pattern.
--- opts:
---   get_data()          → string output from VCS command
---   format_lines(output) → table of display lines
---   buf_pattern         — pattern for find_buf
---   buf_name            — name for new buffer
---   statusline          — statusline text
---   first_item(line)    — returns true for the first data line (for cursor positioning)
---   setup(bufnr, is_new) — called after buffer is populated (keymaps, syntax, etc.)
---   on_refresh(bufnr)   — called after refresh (optional, e.g. reset inline diff state)
function M.show(opts)
  local output = opts.get_data()
  if not output then
    return nil
  end

  local lines = opts.format_lines(output)
  local ui = require("fugitive-core.ui")
  local existing = ui.find_buf(opts.buf_pattern)
  local bufnr

  if existing then
    bufnr = existing
    ui.set_buf_lines(bufnr, lines)
  else
    bufnr = ui.create_scratch_buffer({ name = opts.buf_name })
    ui.set_buf_lines(bufnr, lines)
  end

  if opts.setup then
    opts.setup(bufnr, not existing)
  end

  ui.ensure_visible(bufnr)

  if opts.first_item then
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      for i, line in ipairs(lines) do
        if opts.first_item(line) then
          pcall(vim.api.nvim_win_set_cursor, win, { i, 0 })
          break
        end
      end
    end
  end

  ui.set_statusline(bufnr, opts.statusline)
  return bufnr
end

--- Refresh an open list view buffer.
--- opts:
---   get_data()          → string output
---   format_lines(output) → table of display lines
---   buf_pattern         — pattern for find_buf
---   on_refresh(bufnr)   — optional callback after refresh
function M.refresh(opts)
  local ui = require("fugitive-core.ui")
  local bufnr = ui.find_buf(opts.buf_pattern)
  if not bufnr then
    return
  end

  local output = opts.get_data()
  if not output then
    return
  end

  ui.set_buf_lines(bufnr, opts.format_lines(output))

  if opts.on_refresh then
    opts.on_refresh(bufnr)
  end
end

--- Inline diff state management for status views.
--- Tracks expanded diff ranges so they can be toggled and used for review comments.

function M.get_inline_state(bufnr, var_name)
  local ui = require("fugitive-core.ui")
  return ui.buf_var(bufnr, var_name, {})
end

function M.set_inline_state(bufnr, var_name, state)
  pcall(vim.api.nvim_buf_set_var, bufnr, var_name, state)
end

--- Shift inline diff ranges after inserting or removing lines.
function M.shift_inline_ranges(state, from_line, delta)
  for _, item in ipairs(state) do
    if item.start_line > from_line then
      item.start_line = item.start_line + delta
      item.end_line = item.end_line + delta
    end
  end
end

return M
