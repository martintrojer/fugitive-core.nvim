local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local completion = require("fugitive-core.completion")

local T = new_set()

-- parse_commands -------------------------------------------------------------

T["parse_commands"] = new_set()

T["parse_commands"]["returns empty for bad output"] = function()
  local cmds = completion.parse_commands({ "echo", "no commands here" })
  eq(#cmds, 0)
end

T["parse_commands"]["is a function"] = function()
  eq(type(completion.parse_commands), "function")
end

return T
