local M = {}

--- Parse the Commands: section from CLI help output.
--- args: table passed to vim.fn.system (e.g. {"sl", "--help"})
function M.parse_commands(args)
  local output = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local commands = {}
  local in_commands = false

  for line in output:gmatch("[^\r\n]+") do
    if line:match("^Commands:") or line:match("^COMMANDS:") then
      in_commands = true
    elseif in_commands then
      if line:match("^%S") then
        break
      end
      local cmd = line:match("^%s+([a-z][a-z0-9%-]*)")
      if cmd then
        table.insert(commands, cmd)
      end
    end
  end

  return commands
end

return M
