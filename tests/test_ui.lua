local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local ui = require("fugitive-core.ui")

local T = new_set()

-- node_from_line -------------------------------------------------------------

T["node_from_line"] = new_set()

T["node_from_line"]["extracts 12-char hex"] = function()
  eq(ui.node_from_line("  abc123def456  some text"), "abc123def456")
end

T["node_from_line"]["extracts 40-char hex"] = function()
  local hash = "abcdef1234567890abcdef1234567890abcdef12"
  eq(ui.node_from_line("commit " .. hash), hash)
end

T["node_from_line"]["ignores short hex (<10 chars)"] = function()
  eq(ui.node_from_line("abc123 some text"), nil)
end

T["node_from_line"]["nil input returns nil"] = function()
  eq(ui.node_from_line(nil), nil)
end

T["node_from_line"]["no hex returns nil"] = function()
  eq(ui.node_from_line("no hex here"), nil)
end

T["node_from_line"]["ignores hex with uppercase"] = function()
  eq(ui.node_from_line("ABCDEF1234567890"), nil)
end

T["node_from_line"]["boundary: exactly 10 chars"] = function()
  eq(ui.node_from_line("abcdef1234"), "abcdef1234")
end

T["node_from_line"]["boundary: 9 chars too short"] = function()
  eq(ui.node_from_line("abcdef123"), nil)
end

-- confirm suffix -------------------------------------------------------------

T["confirm"] = new_set()

-- We can't easily test the interactive confirm dialog, but we can test
-- that the function exists and has the right signature
T["confirm"]["is a function"] = function()
  eq(type(ui.confirm), "function")
end

return T
