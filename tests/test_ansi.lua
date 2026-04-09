local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local ansi = require("fugitive-core.ansi")

local T = new_set()

-- parse_ansi_colors ----------------------------------------------------------

T["parse_ansi_colors"] = new_set()

T["parse_ansi_colors"]["plain text unchanged"] = function()
  local text, highlights = ansi.parse_ansi_colors("hello world")
  eq(text, "hello world")
  eq(#highlights, 0)
end

T["parse_ansi_colors"]["strips reset"] = function()
  local text = ansi.parse_ansi_colors("\27[0mhello\27[0m")
  eq(text, "hello")
end

T["parse_ansi_colors"]["strips color codes"] = function()
  local text = ansi.parse_ansi_colors("\27[31mred text\27[0m")
  eq(text, "red text")
end

T["parse_ansi_colors"]["returns highlight for colored text"] = function()
  local text, highlights = ansi.parse_ansi_colors("\27[31mred\27[0m plain")
  eq(text, "red plain")
  eq(#highlights, 1)
  eq(highlights[1].group, "Red")
  eq(highlights[1].col_start, 0)
  eq(highlights[1].col_end, 3)
end

T["parse_ansi_colors"]["bold"] = function()
  local _, highlights = ansi.parse_ansi_colors("\27[1mbold\27[0m")
  eq(#highlights, 1)
  eq(highlights[1].group, "Bold")
end

T["parse_ansi_colors"]["bold + color"] = function()
  local _, highlights = ansi.parse_ansi_colors("\27[1;32mtext\27[0m")
  eq(#highlights, 1)
  eq(highlights[1].group, "BoldGreen")
end

T["parse_ansi_colors"]["256-color basic"] = function()
  local _, highlights = ansi.parse_ansi_colors("\27[38;5;1mtext\27[0m")
  eq(#highlights, 1)
  eq(highlights[1].group, "Red")
end

T["parse_ansi_colors"]["256-color extended green"] = function()
  local _, highlights = ansi.parse_ansi_colors("\27[38;5;34mtext\27[0m")
  eq(#highlights, 1)
  eq(highlights[1].group, "Green")
end

T["parse_ansi_colors"]["empty string"] = function()
  local text, highlights = ansi.parse_ansi_colors("")
  eq(text, "")
  eq(#highlights, 0)
end

T["parse_ansi_colors"]["multiple colors"] = function()
  local text, highlights = ansi.parse_ansi_colors("\27[31mred\27[0m \27[32mgreen\27[0m")
  eq(text, "red green")
  eq(#highlights, 2)
  eq(highlights[1].group, "Red")
  eq(highlights[2].group, "Green")
end

T["parse_ansi_colors"]["underline"] = function()
  local _, highlights = ansi.parse_ansi_colors("\27[4munderlined\27[0m")
  eq(#highlights, 1)
  eq(highlights[1].group, "Underlined")
end

-- process_diff_content -------------------------------------------------------

T["process_diff_content"] = new_set()

T["process_diff_content"]["with header lines"] = function()
  local lines, highlights = ansi.process_diff_content("line1\nline2", { "# header" })
  eq(#lines, 3) -- 1 header + 2 content
  eq(lines[1], "# header")
  eq(lines[2], "line1")
  eq(lines[3], "line2")
end

T["process_diff_content"]["without header"] = function()
  local lines = ansi.process_diff_content("line1\nline2")
  eq(#lines, 2)
end

T["process_diff_content"]["strips ansi from content"] = function()
  local lines = ansi.process_diff_content("\27[31mred\27[0m")
  eq(lines[1], "red")
end

return T
