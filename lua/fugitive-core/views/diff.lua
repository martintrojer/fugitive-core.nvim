local M = {}

--- Show a unified diff view.
--- Handles the create-or-update colored buffer + ensure_visible + statusline pattern.
--- opts:
---   get_diff()        → string output (caller runs VCS command)
---   on_empty()        → called when diff output is empty
---   buf_name          — base buffer name (e.g. "sl-diff: foo.lua")
---   buf_pattern       — pattern for find_buf (e.g. "^sl%-diff: foo%.lua %[%d+%]$")
---   ansi_prefix       — highlight prefix (e.g. "SlDiff")
---   header            — table of header lines
---   statusline        — statusline text
---   setup(bufnr)      — called after buffer is created/updated (set keymaps, context, etc.)
function M.show(opts)
  local output = opts.get_diff()
  if not output then
    return nil
  end
  if output:match("^%s*$") then
    opts.on_empty()
    return nil
  end

  local ansi = require("fugitive-core.ansi")
  local ui = require("fugitive-core.ui")
  local bufnr = ui.find_buf(opts.buf_pattern)

  if bufnr then
    ansi.update_colored_buffer(bufnr, output, opts.header, { prefix = opts.ansi_prefix })
  else
    bufnr =
      ansi.create_colored_buffer(output, opts.buf_name, opts.header, { prefix = opts.ansi_prefix })
  end

  if opts.setup then
    opts.setup(bufnr)
  end

  ui.ensure_visible(bufnr)
  ui.set_statusline(bufnr, opts.statusline)
  return bufnr
end

--- Parse diff buffer lines for filenames (from "diff --git a/... b/..." headers).
--- Returns a list of unique filenames.
function M.parse_diff_files(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local files = {}
  local seen = {}
  for _, line in ipairs(lines) do
    local f = line:match("^diff %-%-git a/.+ b/(.+)$")
    if f and not seen[f] then
      seen[f] = true
      table.insert(files, f)
    end
  end
  return files
end

return M
