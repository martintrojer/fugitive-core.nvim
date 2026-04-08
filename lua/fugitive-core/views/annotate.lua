local M = {}

--- Resolve a filename for annotation from the current buffer.
--- Returns the relative path or nil if no file is available.
function M.resolve_filename(filename, repo_root)
  if filename and filename ~= "" then
    return filename
  end

  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.buftype ~= "" then
    return nil
  end

  if repo_root and buf_name:find(repo_root, 1, true) == 1 then
    return buf_name:sub(#repo_root + 2)
  end
  return buf_name
end

--- Create a vsplit layout with annotation pane on the left and source on the right.
--- Both panes are scroll-locked together.
--- Returns ann_buf, src_buf, close_fn
--- opts:
---   ann_name        — annotation buffer name
---   src_name        — source buffer name
---   annotations     — table of annotation lines
---   source_lines    — table of source content lines
---   filename        — for filetype detection on source buffer
---   ann_syntax(bufnr) — callback to set up annotation syntax highlighting
---   statusline_ann  — statusline for annotation pane
---   statusline_src  — statusline for source pane
function M.open_split(opts)
  local ui = require("fugitive-core.ui")

  local ann_buf = ui.create_scratch_buffer({
    name = opts.ann_name,
    modifiable = true,
    bufhidden = "hide",
  })
  local src_buf = ui.create_scratch_buffer({
    name = opts.src_name,
    modifiable = true,
    bufhidden = "hide",
  })

  vim.api.nvim_buf_set_lines(ann_buf, 0, -1, false, opts.annotations)
  vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, opts.source_lines)
  vim.bo[ann_buf].modifiable = false
  vim.bo[src_buf].modifiable = false
  vim.bo[ann_buf].modified = false
  vim.bo[src_buf].modified = false

  if opts.filename then
    local ft = vim.filetype.match({ filename = opts.filename })
    if ft then
      vim.bo[src_buf].filetype = ft
    end
  end

  if opts.ann_syntax then
    opts.ann_syntax(ann_buf)
  end

  -- Remember original buffer for restore on close
  local orig_buf = vim.api.nvim_get_current_buf()

  -- Set source in current window, then open annotation as a left vsplit
  vim.api.nvim_set_current_buf(src_buf)
  vim.cmd("vsplit")
  vim.cmd("wincmd H")
  vim.api.nvim_set_current_buf(ann_buf)

  -- Size the annotation window to fit content
  local max_width = 0
  for _, ann in ipairs(opts.annotations) do
    if #ann > max_width then
      max_width = #ann
    end
  end
  vim.api.nvim_win_set_width(0, math.min(max_width + 1, 60))

  -- Lock scrolling between the two windows
  vim.cmd("setlocal scrollbind nowrap nonumber norelativenumber")
  vim.cmd("wincmd l")
  vim.cmd("setlocal scrollbind")
  vim.cmd("syncbind")
  vim.cmd("wincmd h")

  local function close()
    local ann_win = vim.fn.bufwinid(ann_buf)
    local src_win = vim.fn.bufwinid(src_buf)
    if ann_win ~= -1 then
      pcall(vim.api.nvim_win_close, ann_win, true)
    end
    if src_win ~= -1 then
      vim.api.nvim_win_call(src_win, function()
        vim.cmd("setlocal noscrollbind")
      end)
      if vim.api.nvim_buf_is_valid(orig_buf) then
        vim.api.nvim_win_set_buf(src_win, orig_buf)
      end
      pcall(vim.api.nvim_set_current_win, src_win)
    end
    if vim.api.nvim_buf_is_valid(src_buf) then
      pcall(vim.api.nvim_buf_delete, src_buf, { force = true })
    end
  end

  if opts.statusline_ann then
    ui.set_statusline(ann_buf, opts.statusline_ann)
  end
  if opts.statusline_src then
    ui.set_statusline(src_buf, opts.statusline_src)
  end

  return ann_buf, src_buf, close
end

return M
