# fugitive-core.nvim

Shared foundation library for VCS-fugitive Neovim plugins. Extracted from
[sl-fugitive](https://github.com/martintrojer/sl-fugitive) (Sapling) and
[jj-fugitive](https://github.com/martintrojer/jj-fugitive) (Jujutsu) to
eliminate code duplication across VCS plugins.

## Architecture

```
lua/fugitive-core/
├── init.lua           # setup(), config + adapter storage
├── ui.lua             # scratch buffers, keymaps, panes, popups, side-by-side diff,
│                      # save/restore view, node extraction
├── ansi.lua           # ANSI parsing, colored buffer create/update, diff highlighting
├── completion.lua     # CLI help command parser (parse_commands)
└── views/
    ├── annotate.lua   # resolve_filename, vsplit+scrollbind layout (open_split)
    ├── browse.lua     # parse_remote_url, build_file/commit_url, open_url, line_range
    ├── describe.lua   # commit message editor framework (open_editor)
    ├── diff.lua       # unified diff show() framework, parse_diff_files
    └── list.lua       # show/refresh framework for list views (status, bookmark),
                       # inline diff state management
```

## Design Principles

- **Framework, not framework-itis.** Each module provides the shared pattern
  (buffer lifecycle, layout, state management) and lets plugins supply
  VCS-specific callbacks. No adapter registry or abstract base classes.
- **Plugins delegate via `__index`.** Plugin `ui.lua` and `ansi.lua` are thin
  `setmetatable` wrappers over the core, adding only VCS-specific functions.
- **Config propagation.** Plugins call `require("fugitive-core").setup(nil, opts)`
  in their own `setup()` so the core's `get_config()` returns the right values.

## What belongs here vs. in plugins

**Core:** UI primitives, buffer lifecycle, ANSI rendering, URL construction,
editor scaffolding, CLI help parsing, view state helpers.

**Plugins:** VCS command execution, output parsing, keymaps, syntax highlighting,
mutation actions, repo detection, review integration.

## Dependencies

- Neovim 0.10+

## Development

```bash
luacheck lua/                      # lint
stylua --check lua/                # format check
stylua lua/                        # format fix
```
