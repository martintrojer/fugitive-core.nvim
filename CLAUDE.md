# fugitive-core.nvim

Shared foundation library for VCS-fugitive Neovim plugins. Extracted from
[sl-fugitive](https://github.com/martintrojer/sl-fugitive) (Sapling) and
[jj-fugitive](https://github.com/martintrojer/jj-fugitive) (Jujutsu) to
eliminate code duplication across VCS plugins.

## Architecture

```
lua/fugitive-core/
├── init.lua           # setup(), config storage (open_mode, forges)
├── ui.lua             # scratch buffers, keymaps, panes, popups, side-by-side diff,
│                      # save/restore view, prompt helpers (input/select/confirm),
│                      # setup_view_keymaps, node extraction
├── ansi.lua           # ANSI parsing, colored buffer create/update, diff highlighting
├── completion.lua     # CLI help command parser (parse_commands)
└── views/
    ├── annotate.lua   # resolve_filename, vsplit+scrollbind layout (open_split)
    ├── browse.lua     # parse_remote_url, build_file/commit_url, custom forges,
    │                  # open_url, line_range
    ├── describe.lua   # commit message editor framework (open_editor)
    ├── diff.lua       # unified diff show() framework, parse_diff_files
    └── list.lua       # show/refresh framework for list views (status, bookmark),
                       # inline diff state management, collapse_inline_at_cursor
```

## Design Principles

- **Framework, not framework-itis.** Each module provides the shared pattern
  (buffer lifecycle, layout, state management) and lets plugins supply
  VCS-specific callbacks. No adapter registry or abstract base classes.
- **Plugins delegate via `__index`.** Plugin `ui.lua` is a thin `setmetatable`
  wrapper over the core, adding only VCS-specific functions (e.g. `file_at_rev`).
  Plugins use `require("fugitive-core.ansi")` directly.
- **Config propagation.** Plugins call `require("fugitive-core").setup(nil, opts)`
  in their own `setup()` so the core's `get_config()` returns the right values
  (e.g. `open_mode`, `forges`).
- **Prompts go through core.** `ui.input`, `ui.select`, and `ui.confirm` handle
  consistent prompt formatting (appending `: `, `:`, `?`). Plugins never call
  `vim.ui` directly.

## What belongs here vs. in plugins

**Core:** UI primitives, buffer lifecycle, ANSI rendering, URL construction,
editor scaffolding, CLI help parsing, view state helpers, prompt helpers,
navigation keymap registration, custom forge URL building.

**Plugins:** VCS command execution, output parsing, mutation keymaps, syntax
highlighting, repo detection, review integration.

## Dependencies

- Neovim 0.10+

## Development

```bash
luacheck lua/                      # lint
stylua --check lua/                # format check
stylua lua/                        # format fix
```
