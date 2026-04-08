# fugitive-core.nvim

Shared foundation library for VCS-fugitive Neovim plugins.

This library provides the common UI primitives, buffer management, ANSI color
rendering, and view frameworks used by:

- [sl-fugitive](https://github.com/martintrojer/sl-fugitive) — Sapling/hg
- [jj-fugitive](https://github.com/martintrojer/jj-fugitive) — Jujutsu

## What it provides

| Module | Description |
|--------|-------------|
| `ui` | Scratch buffers, keymaps, pane management, popups, side-by-side diff, cursor save/restore |
| `ansi` | ANSI escape sequence parsing, colored buffer creation and update, diff highlighting |
| `completion` | CLI help output parser for tab completion |
| `views/describe` | Commit message editor framework (`open_editor`) |
| `views/diff` | Unified diff show/refresh framework |
| `views/browse` | Remote URL parsing, file/commit URL construction, browser opening |
| `views/list` | Show/refresh framework for list views (status, bookmark), inline diff state |
| `views/annotate` | Scroll-locked vsplit layout for annotation/blame views |

## Requirements

- Neovim 0.10+

## Installation

This plugin is a dependency of sl-fugitive and jj-fugitive. Install it alongside
whichever VCS plugin you use.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Installed automatically as a dependency:
{ "martintrojer/sl-fugitive", dependencies = { "martintrojer/fugitive-core.nvim" } }
{ "martintrojer/jj-fugitive", dependencies = { "martintrojer/fugitive-core.nvim" } }
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add("martintrojer/fugitive-core.nvim")
vim.pack.add("martintrojer/sl-fugitive")  -- and/or jj-fugitive
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { "martintrojer/sl-fugitive", requires = { "martintrojer/fugitive-core.nvim" } }
```

### Manual

```bash
git clone https://github.com/martintrojer/fugitive-core.nvim ~/.local/share/nvim/site/pack/plugins/start/fugitive-core.nvim
```

## Writing a VCS plugin with fugitive-core

Each VCS plugin is a thin adapter layer. The plugin's `ui.lua` and `ansi.lua`
delegate to the core via `setmetatable(__index)`, adding only VCS-specific
functions. View modules call core frameworks with callbacks for VCS-specific
data fetching, formatting, and keymaps.

```lua
-- Example: plugin setup propagates config to core
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  require("fugitive-core").setup(nil, M.config)
end
```

See [sl-fugitive](https://github.com/martintrojer/sl-fugitive) and
[jj-fugitive](https://github.com/martintrojer/jj-fugitive) for complete
examples.

## License

MIT
