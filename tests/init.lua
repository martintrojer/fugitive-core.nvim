-- Test runner for fugitive-core.nvim
-- Run with: nvim --headless -u tests/init.lua

-- Add project to rtp
vim.opt.rtp:prepend(".")

-- Load mini.nvim (works with both packadd and manual rtp)
local ok = pcall(vim.cmd, "packadd mini.nvim")
if not ok then
  -- CI fallback: mini.nvim cloned to deps path
  vim.opt.rtp:append(vim.fn.expand("~/.local/share/nvim/site/pack/deps/opt/mini.nvim"))
end

require("mini.test").setup()
MiniTest.run()
