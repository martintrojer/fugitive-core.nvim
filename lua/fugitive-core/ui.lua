local M = {}

--- Create a scratch buffer with standard options.
--- opts: { name, filetype, modifiable, buftype, bufhidden }
function M.create_scratch_buffer(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.bo[bufnr].buftype = opts.buftype or "nofile"
  vim.bo[bufnr].bufhidden = opts.bufhidden or "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = opts.modifiable == true

  if opts.filetype then
    vim.bo[bufnr].filetype = opts.filetype
  end

  if opts.name then
    pcall(vim.api.nvim_buf_set_name, bufnr, opts.name)
  end

  return bufnr
end

--- Set buffer lines and lock it (modifiable=false, modified=false).
function M.set_buf_lines(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
end

--- Buffer-local keymap helper.
function M.map(bufnr, mode, lhs, rhs, opts)
  local base = { buffer = bufnr, noremap = true, silent = true }
  if opts then
    base = vim.tbl_extend("force", base, opts)
  end
  vim.keymap.set(mode, lhs, rhs, base)
end

--- Get a buffer variable with a fallback default.
function M.buf_var(bufnr, name, default)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, name)
  return ok and val or default
end

--- Show an error message.
function M.err(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

--- Show a warning message.
function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

--- Show an info message.
function M.info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

--- Show a confirmation dialog. Appends "?" if not present. Returns true if user confirms.
function M.confirm(message)
  if not message:match("[%?!]$") then
    message = message .. "?"
  end
  return vim.fn.confirm(message, "&Yes\n&No", 2) == 1
end

--- Prompt for text input. Appends ": " to the prompt.
--- opts: { default = "..." } (optional)
function M.input(prompt, callback, opts)
  vim.ui.input({ prompt = prompt .. ": ", default = opts and opts.default }, callback)
end

--- Prompt to select from a list. Appends ":" to the prompt.
function M.select(items, prompt, callback)
  vim.ui.select(items, { prompt = prompt .. ":" }, callback)
end

--- Delete a file from the filesystem with confirmation.
--- Returns true if deleted, false otherwise.
function M.delete_file(filepath, repo_root)
  local full = repo_root and (repo_root .. "/" .. filepath) or filepath
  if not vim.loop.fs_stat(full) then
    M.warn(filepath .. " does not exist")
    return false
  end
  if not M.confirm("Delete " .. filepath) then
    return false
  end
  local ok, err = os.remove(full)
  if ok then
    M.info("Deleted: " .. filepath)
    return true
  else
    M.err("Failed to delete " .. filepath .. ": " .. (err or "unknown error"))
    return false
  end
end

--- Open a file in the editor, resolving repo-relative paths.
--- cmd: "edit" (default) or "split"/"vsplit".
--- In tab mode, "edit" closes the current tab first.
--- In split mode, "edit" just replaces the buffer in the current window.
--- "split"/"vsplit" always keeps the current view.
function M.open_file(file, repo_root, cmd)
  cmd = cmd or "edit"
  local path = file
  if repo_root and not vim.startswith(file, "/") then
    path = repo_root .. "/" .. file
  end
  if cmd == "edit" and M.get_config().open_mode == "tab" then
    vim.cmd(M.close_cmd())
  end
  vim.cmd(cmd .. " " .. vim.fn.fnameescape(path))
end

--- Set a custom statusline for a buffer.
function M.set_statusline(bufnr, text)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=" .. vim.fn.escape(text or "", " \\ "))
  end)
end

--- Get the plugin config table.
function M.get_config()
  return require("fugitive-core").config
end

--- Open a new pane (split or tab) based on user config.
--- opts: { split_cmd = "botright split" } to override the split command
function M.open_pane(opts)
  opts = opts or {}
  local cmd = M.get_config().open_mode == "tab" and "tabnew" or (opts.split_cmd or "split")
  vim.cmd(cmd)
  -- Mark the stray [No Name] buffer from tabnew so it gets wiped
  -- as soon as the caller sets a real buffer in this window
  if cmd == "tabnew" then
    local stray = vim.api.nvim_get_current_buf()
    vim.bo[stray].buflisted = false
    vim.bo[stray].bufhidden = "wipe"
  end
end

--- Close command appropriate for open_mode (close split or tab).
--- When it's the last window/tab, switches to the alternate buffer
--- or a listed buffer instead of creating a new empty one.
function M.close_cmd()
  if M.get_config().open_mode == "tab" then
    if #vim.api.nvim_list_tabpages() > 1 then
      return "tabclose"
    end
  else
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
      return "close"
    end
  end
  -- Try alternate buffer first
  local alt = vim.fn.bufnr("#")
  if alt > 0 and vim.api.nvim_buf_is_valid(alt) and alt ~= vim.api.nvim_get_current_buf() then
    return "buffer #"
  end
  -- Try any other listed buffer
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(bufnr)
      and vim.bo[bufnr].buflisted
      and bufnr ~= vim.api.nvim_get_current_buf()
    then
      return "buffer " .. bufnr
    end
  end
  return "enew"
end

--- Ensure a buffer is visible. Jump to its window if already displayed
--- (searching across all tabs), otherwise open in a new pane.
function M.ensure_visible(bufnr)
  -- Search all tabpages for the buffer
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_set_current_tabpage(tabpage)
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end
  M.open_pane()
  vim.api.nvim_set_current_buf(bufnr)
end

--- Find an existing buffer by name pattern. Returns bufnr or nil.
function M.find_buf(pattern)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match(pattern) then
        return bufnr
      end
    end
  end
  return nil
end

--- Show a floating help popup.
--- lines: table of strings to display
--- opts: { title, width, close_keys }
function M.help_popup(title, lines, opts)
  opts = opts or {}
  local help_buf = M.create_scratch_buffer({ filetype = "markdown", modifiable = true })
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines or {})
  vim.bo[help_buf].modifiable = false
  vim.bo[help_buf].modified = false

  local win_width = vim.o.columns
  local win_height = vim.o.lines
  local width = math.min(opts.width or 60, win_width - 4)
  local height = math.min(#(lines or {}) + 2, win_height - 4)

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = (win_height - height) / 2,
    col = (win_width - width) / 2,
    style = "minimal",
    border = "rounded",
  }

  if title then
    win_opts.title = " " .. title .. " "
    win_opts.title_pos = "center"
  end

  local help_win = vim.api.nvim_open_win(help_buf, true, win_opts)

  local function close()
    if vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
    end
  end

  for _, key in ipairs(vim.list_extend({ "<CR>", "<Esc>", "q" }, opts.close_keys or {})) do
    M.map(help_buf, "n", key, close)
  end

  -- Close popup when it loses focus
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = help_buf,
    once = true,
    callback = close,
  })

  return help_buf, help_win
end

--- Open a side-by-side diff in a new tab using Neovim's diffthis.
--- left_content, right_content: strings
--- left_name, right_name: buffer names
--- filename: used for filetype detection (optional)
--- opts: { repo_root = "..." } for resolving the filename on `o`
function M.open_sidebyside(left_content, left_name, right_content, right_name, filename, opts)
  -- Remember where we came from so q can restore it
  local prev_tab = vim.api.nvim_get_current_tabpage()
  local prev_win = vim.api.nvim_get_current_win()

  -- Always use a tab for side-by-side (needs full width)
  M.open_pane({ split_cmd = "tabnew" })

  local left = M.create_scratch_buffer({ name = left_name })
  M.set_buf_lines(left, vim.split(left_content, "\n"))

  local right = M.create_scratch_buffer({ name = right_name })
  M.set_buf_lines(right, vim.split(right_content, "\n"))

  if filename then
    local ft = vim.filetype.match({ filename = filename })
    if ft then
      vim.bo[left].filetype = ft
      vim.bo[right].filetype = ft
    end
  end

  vim.api.nvim_set_current_buf(left)
  local left_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.api.nvim_set_current_buf(right)
  local right_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_call(left_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(right_win, function()
    vim.cmd("diffthis")
  end)

  local diff_tab = vim.api.nvim_get_current_tabpage()

  local function close_sidebyside()
    -- Always try to go back where we came from
    if vim.api.nvim_tabpage_is_valid(prev_tab) and prev_tab ~= diff_tab then
      vim.api.nvim_set_current_tabpage(prev_tab)
      if vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end
      -- Now safe to close the diff tab
      if vim.api.nvim_tabpage_is_valid(diff_tab) then
        local ok = pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(diff_tab))
        if not ok then
          -- Wipe the diff buffers manually
          pcall(vim.api.nvim_buf_delete, left, { force = true })
          pcall(vim.api.nvim_buf_delete, right, { force = true })
        end
      end
    elseif #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd("tabclose")
    else
      -- Last tab, no prev — close both windows, find a real buffer
      pcall(vim.api.nvim_buf_delete, left, { force = true })
      pcall(vim.api.nvim_buf_delete, right, { force = true })
      if vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == "" then
        vim.cmd(M.close_cmd())
      end
    end
  end

  local repo_root = opts and opts.repo_root
  for _, buf in ipairs({ left, right }) do
    M.map(buf, "n", "q", close_sidebyside)
    if filename then
      M.map(buf, "n", "o", function()
        close_sidebyside()
        M.open_file(filename, repo_root)
      end)
    end
  end

  return left, right, close_sidebyside
end

--- Save cursor position and viewport for a buffer window.
--- Returns a state table (or nil if the buffer has no visible window).
function M.save_view(bufnr)
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return nil
  end
  return {
    win = win,
    cursor = vim.api.nvim_win_get_cursor(win),
    topline = vim.fn.getwininfo(win)[1].topline,
  }
end

--- Restore cursor position and viewport, clamped to buffer size.
function M.restore_view(bufnr, state)
  if not state or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if state.cursor then
    local row = math.min(state.cursor[1], line_count)
    pcall(vim.api.nvim_win_set_cursor, state.win, { row, state.cursor[2] })
  end
  if state.topline then
    vim.api.nvim_win_call(state.win, function()
      vim.fn.winrestview({ topline = math.min(state.topline, line_count) })
    end)
  end
end

--- Setup common view-switching keymaps.
--- opts: table of optional callbacks:
---   close     — q keymap (default: close_cmd)
---   log       — gl keymap
---   status    — gs keymap
---   bookmark  — gb keymap
---   review    — gR keymap (nil to skip)
---   refresh   — R keymap (nil to skip)
---   help      — g? keymap (nil to skip)
function M.setup_view_keymaps(bufnr, opts)
  M.map(bufnr, "n", "q", opts.close or function()
    vim.cmd(M.close_cmd())
  end)
  if opts.log then
    M.map(bufnr, "n", "gl", opts.log)
  end
  if opts.status then
    M.map(bufnr, "n", "gs", opts.status)
  end
  if opts.bookmark then
    M.map(bufnr, "n", "gb", opts.bookmark)
  end
  if opts.review then
    M.map(bufnr, "n", "gR", opts.review)
  end
  if opts.refresh then
    M.map(bufnr, "n", "R", opts.refresh)
  end
  if opts.help then
    M.map(bufnr, "n", "g?", opts.help)
  end
end

--- Extract a hex node ID (10+ chars) from a line.
function M.node_from_line(line)
  if not line then
    return nil
  end
  local match = line:match("%f[%x]([0-9a-f][0-9a-f]+)%f[^%x]")
  return match and #match >= 10 and match or nil
end

return M
