local M = {}

local ns = vim.api.nvim_create_namespace("fugitive_core_ansi")
M.ns = ns

local buf_counter = 0

-- ANSI color code constants
local ANSI_CODES = {
  RESET = "0",
  BOLD = "1",
  UNDERLINE = "4",
  NO_UNDERLINE = "24",
  DEFAULT_FG = "39",
}

-- ANSI color mappings - basic 3/4 bit colors
local ANSI_COLORS = {
  ["30"] = "Black",
  ["31"] = "Red",
  ["32"] = "Green",
  ["33"] = "Yellow",
  ["34"] = "Blue",
  ["35"] = "Magenta",
  ["36"] = "Cyan",
  ["37"] = "White",
  ["90"] = "DarkGray",
  ["91"] = "LightRed",
  ["92"] = "LightGreen",
  ["93"] = "LightYellow",
  ["94"] = "LightBlue",
  ["95"] = "LightMagenta",
  ["96"] = "LightCyan",
  ["97"] = "White",
}

-- Basic 16 colors for 256-color lookup (hoisted to avoid per-call allocation)
local BASIC_256 = {
  [0] = "Black",
  [1] = "Red",
  [2] = "Green",
  [3] = "Yellow",
  [4] = "Blue",
  [5] = "Magenta",
  [6] = "Cyan",
  [7] = "White",
  [8] = "DarkGray",
  [9] = "LightRed",
  [10] = "LightGreen",
  [11] = "LightYellow",
  [12] = "LightBlue",
  [13] = "LightMagenta",
  [14] = "LightCyan",
  [15] = "White",
}

-- Map 256-color palette index to a color name.
local function color_256_lookup(idx)
  local n = tonumber(idx)
  if not n then
    return nil
  end
  if n <= 15 then
    return BASIC_256[n]
  end
  -- Extended 256-color palette (16-231): map to nearest basic color
  if n <= 231 then
    local idx6 = n - 16
    local r = math.floor(idx6 / 36) % 6
    local g = math.floor(idx6 / 6) % 6
    local b = idx6 % 6
    if r == g and g == b then
      if r == 0 then
        return "Black"
      elseif r <= 2 then
        return "DarkGray"
      end
      return "White"
    elseif g > r and g > b then
      return "Green"
    elseif r > g and r > b then
      return "Red"
    elseif b > r and b > g then
      return "Blue"
    elseif r > 0 and g > 0 and b == 0 then
      return "Yellow"
    elseif r > 0 and b > 0 and g == 0 then
      return "Magenta"
    elseif g > 0 and b > 0 and r == 0 then
      return "Cyan"
    end
    return "White"
  end
  -- Grayscale (232-255): 24 shades from near-black to near-white
  if n <= 237 then
    return "Black"
  elseif n <= 243 then
    return "DarkGray"
  end
  return "White"
end

-- Parse ANSI escape sequences and convert to Neovim highlighting
function M.parse_ansi_colors(text)
  local highlights = {}
  local clean_text = ""
  local pos = 1
  local current_style = {}

  while pos <= #text do
    local esc_start, esc_end = text:find("\27%[[0-9;]*m", pos)

    if esc_start then
      -- Add text before escape sequence with current styling
      if esc_start > pos then
        local segment = text:sub(pos, esc_start - 1)
        if next(current_style) then
          table.insert(highlights, {
            group = current_style.group or "Normal",
            line = 0,
            col_start = #clean_text,
            col_end = #clean_text + #segment,
          })
        end
        clean_text = clean_text .. segment
      end

      -- Parse the escape sequence
      local codes = text:sub(esc_start + 2, esc_end - 1)

      -- Handle different codes
      if codes == ANSI_CODES.RESET or codes == "" then
        current_style = {}
      elseif codes == ANSI_CODES.BOLD then
        current_style.bold = true
        current_style.group = "Bold"
      elseif codes == ANSI_CODES.UNDERLINE then
        current_style.underline = true
        current_style.group = "Underlined"
      elseif codes == ANSI_CODES.NO_UNDERLINE then
        current_style.underline = false
        if not current_style.bold and not current_style.color then
          current_style = {}
        end
      elseif codes == ANSI_CODES.DEFAULT_FG then
        current_style.color = nil
        if not current_style.bold and not current_style.underline then
          current_style = {}
        end
      else
        -- Handle complex color codes like 38;5;n (256-color foreground)
        local codes_list = {}
        for code in codes:gmatch("[^;]+") do
          table.insert(codes_list, code)
        end

        local i = 1
        while i <= #codes_list do
          local code = codes_list[i]

          if code == "38" and codes_list[i + 1] == "5" and codes_list[i + 2] then
            local color_index = codes_list[i + 2]
            local color = color_256_lookup(color_index)
            if color then
              current_style.color = color
              current_style.group = current_style.bold and ("Bold" .. color) or color
            end
            i = i + 3
          elseif code == "1" then
            current_style.bold = true
            if current_style.color then
              current_style.group = "Bold" .. current_style.color
            else
              current_style.group = "Bold"
            end
            i = i + 1
          elseif ANSI_COLORS[code] then
            current_style.color = ANSI_COLORS[code]
            current_style.group = current_style.bold and ("Bold" .. ANSI_COLORS[code])
              or ANSI_COLORS[code]
            i = i + 1
          else
            i = i + 1
          end
        end
      end

      pos = esc_end + 1
    else
      local remaining = text:sub(pos)
      if #remaining > 0 then
        if next(current_style) then
          table.insert(highlights, {
            group = current_style.group or "Normal",
            line = 0,
            col_start = #clean_text,
            col_end = #clean_text + #remaining,
          })
        end
        clean_text = clean_text .. remaining
      end
      break
    end
  end

  return clean_text, highlights
end

-- Process diff content and parse ANSI colors
function M.process_diff_content(diff_content, header_lines)
  local lines = vim.split(diff_content, "\n")
  local processed_lines = {}
  local all_highlights = {}

  if header_lines then
    for _, line in ipairs(header_lines) do
      table.insert(processed_lines, line)
    end
  end

  local line_offset = header_lines and #header_lines or 0
  for i, line in ipairs(lines) do
    local clean_line, highlights = M.parse_ansi_colors(line)
    table.insert(processed_lines, clean_line)

    for _, hl in ipairs(highlights) do
      hl.line = i + line_offset - 1
      table.insert(all_highlights, hl)
    end
  end

  return processed_lines, all_highlights
end

-- Setup standard diff highlighting and apply parsed ANSI colors
function M.setup_diff_highlighting(bufnr, highlights, opts)
  opts = opts or {}
  local prefix = opts.prefix or "FcDiff"

  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal filetype=diff")
    vim.cmd("setlocal conceallevel=0")

    vim.cmd(string.format("highlight default link %sAdd DiffAdd", prefix))
    vim.cmd(string.format("highlight default link %sDelete DiffDelete", prefix))
    vim.cmd(string.format("highlight default link %sChange DiffChange", prefix))
    vim.cmd(string.format("highlight default %sBold gui=bold cterm=bold", prefix))

    if opts.custom_syntax then
      for pattern, group in pairs(opts.custom_syntax) do
        vim.cmd(string.format("syntax match %s '%s'", group, pattern))
        if opts.custom_highlights and opts.custom_highlights[group] then
          vim.cmd(string.format("highlight default %s", opts.custom_highlights[group]))
        else
          vim.cmd(string.format("highlight default link %s Comment", group))
        end
      end
    end
  end)

  local color_to_theme = {
    Red = "DiagnosticError",
    Green = "DiagnosticOk",
    Yellow = "DiagnosticWarn",
    Blue = "Function",
    Magenta = "Keyword",
    Cyan = "Type",
    White = "Normal",
    Black = "Comment",
    DarkGray = "Comment",
    LightRed = "DiagnosticError",
    LightGreen = "DiagnosticOk",
    LightYellow = "DiagnosticWarn",
    LightBlue = "Function",
    LightMagenta = "Keyword",
    LightCyan = "Type",
  }

  local defined_groups = {}

  if highlights then
    for _, hl in ipairs(highlights) do
      local group = hl.group
      if group == "Green" or group == "LightGreen" then
        group = prefix .. "Add"
      elseif group == "Red" or group == "LightRed" then
        group = prefix .. "Delete"
      elseif group == "Yellow" or group == "LightYellow" then
        group = prefix .. "Change"
      elseif group == "Bold" then
        group = prefix .. "Bold"
      elseif group:match("^Bold") then
        local prefixed = "FcAnsi" .. group
        if not defined_groups[prefixed] then
          local color_name = group:sub(5)
          local link = color_to_theme[color_name]
          if link then
            local theme_hl = vim.api.nvim_get_hl(0, { name = link, link = false })
            if theme_hl.fg then
              pcall(vim.api.nvim_set_hl, 0, prefixed, { fg = theme_hl.fg, bold = true })
            else
              pcall(vim.api.nvim_set_hl, 0, prefixed, { link = link })
            end
          end
          defined_groups[prefixed] = true
        end
        group = prefixed
      else
        local link = color_to_theme[group]
        if link then
          local prefixed = "FcAnsi" .. group
          if not defined_groups[prefixed] then
            pcall(vim.api.nvim_set_hl, 0, prefixed, { link = link })
            defined_groups[prefixed] = true
          end
          group = prefixed
        end
      end

      local col_end = hl.col_end == -1 and -1 or hl.col_end
      pcall(vim.api.nvim_buf_add_highlight, bufnr, ns, group, hl.line, hl.col_start, col_end)
    end
  end
end

-- Create a colored diff/show buffer with consistent formatting
function M.create_colored_buffer(content, buffer_name, header_lines, opts)
  opts = opts or {}

  local ui = require("fugitive-core.ui")
  buf_counter = buf_counter + 1
  local unique_name = string.format("%s [%d]", buffer_name, buf_counter)
  local bufnr = ui.create_scratch_buffer({
    name = unique_name,
    modifiable = true,
  })

  local processed_lines, highlights = M.process_diff_content(content, header_lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  M.setup_diff_highlighting(bufnr, highlights, opts)

  pcall(vim.api.nvim_buf_set_var, bufnr, "fugitive_plugin_buffer", true)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  return bufnr
end

-- Update existing buffer with new colored content
function M.update_colored_buffer(bufnr, content, header_lines, opts)
  opts = opts or {}

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local processed_lines, highlights = M.process_diff_content(content, header_lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, processed_lines)

  M.setup_diff_highlighting(bufnr, highlights, opts)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
end

return M
