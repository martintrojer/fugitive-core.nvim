# Plan: Extract shared VCS-fugitive core library

## Context

~/hacking/sl-fugitive (Sapling) and ~/hacking/jj-fugitive (Jujutsu) share 60-70% identical code
across all modules. Every UI fix, keymap change, or improvement must be
duplicated manually. A shared library eliminates this and lets each plugin
focus on VCS-specific logic only.

## Name

**`fugitive-core.nvim`** — the shared foundation for VCS-fugitive plugins.

## Architecture

```
fugitive-core.nvim/
└── lua/fugitive-core/
    ├── init.lua        # setup(), register_commands(), VCS adapter interface
    ├── ui.lua          # scratch buffers, keymaps, popups, splits, close_cmd
    ├── ansi.lua        # ANSI parsing and colored buffer rendering
    ├── views/
    │   ├── log.lua     # Log/smartlog view framework
    │   ├── status.lua  # Status view framework
    │   ├── diff.lua    # Unified + side-by-side diff
    │   ├── annotate.lua# Annotate/blame split
    │   ├── bookmark.lua# Bookmark management
    │   ├── describe.lua# Commit message editor (open_editor)
    │   └── browse.lua  # Forge URL construction + opening
    └── completion.lua  # Tab completion framework
```

Each view module exports a factory that takes a VCS adapter and returns the
view's `show()`, `refresh()`, and keymap setup functions.

## VCS Adapter Interface

Each plugin (sl-fugitive, jj-fugitive) provides an adapter table:

```lua
{
  -- Identity
  name = "sl",              -- plugin name for buffer names, namespaces
  command_prefix = "S",     -- :S or :J
  browse_command = "SBrowse",

  -- Revision symbols
  working_copy = ".",       -- sl: ".", jj: "@"
  parent_of = function(rev) return rev .. "^" end,  -- sl: "^", jj: "@-" or parents()

  -- Repo detection
  repo_markers = { ".sl", ".hg", ".git/sl" },

  -- Command execution
  build_command = function(args, repo_root) -> cmd_table end,

  -- Data providers (each returns string output or nil)
  get_log = function(opts) -> output end,
  get_status = function() -> output end,
  get_diff = function(file, rev) -> output end,
  get_description = function(rev) -> string end,
  file_at_rev = function(filename, rev) -> string end,
  get_bookmarks = function() -> output end,
  get_remotes = function() -> { name = url } end,
  annotate = function(filename, rev) -> output end,

  -- Parsers (VCS output format differs)
  parse_status_line = function(line) -> { file, status_code } | nil end,
  parse_bookmark_line = function(line) -> { name, node } | nil end,
  parse_annotation_line = function(line) -> { node, user, content } | nil end,
  rev_from_line = function(bufnr, line) -> rev_id | nil end,

  -- Mutations (each returns success boolean)
  goto_rev = function(rev) end,
  revert_file = function(file) end,
  describe = function(rev, message) end,
  commit = function(message) end,
  create_bookmark = function(name, rev) end,
  delete_bookmark = function(name) end,
  move_bookmark = function(name, rev) end,
  push_bookmark = function(name, dest) end,

  -- Optional: VCS-specific keymaps added to views
  log_keymaps = function(bufnr, get_rev) end,    -- sl: rr/rs/ri/rf/rR/etc
  status_keymaps = function(bufnr) end,           -- jj: cc/S
  bookmark_keymaps = function(bufnr) end,          -- sl: r(ename), jj: t/u/f
}
```

## What moves to fugitive-core

### Direct extraction (95%+ shared)
- `ui.lua` — all helpers verbatim (parameterize config lookup)
- `ansi.lua` — entire module (parameterize namespace/prefix)

### Framework extraction (60-75% shared)
- `views/diff.lua` — get_diff via adapter, keymaps, ANSI rendering, side-by-side
- `views/describe.lua` — open_editor framework, save via adapter callback
- `views/status.lua` — format_lines, inline diff toggle/state, keymaps
- `views/bookmark.lua` — format_lines, CRUD keymaps calling adapter
- `views/annotate.lua` — vsplit layout, scrollbind, parse via adapter
- `views/browse.lua` — URL construction, open_url, line_range
- `views/log.lua` — ANSI buffer, header, detail keymaps, refresh w/ cursor restore
- `completion.lua` — parse_commands framework, revision completion

### Common keymap registration
All views get `gl/gs/gb/gR/g?/q/R` via a shared `setup_navigation_keymaps(bufnr, adapter)`.

## What stays in sl-fugitive / jj-fugitive

Each plugin becomes a thin adapter + VCS-specific extras:

```lua
-- sl-fugitive/init.lua (simplified)
local core = require("fugitive-core")

local adapter = {
  name = "sl",
  command_prefix = "S",
  working_copy = ".",
  repo_markers = { ".sl", ".hg", ".git/sl" },
  -- ... all VCS-specific implementations
  log_keymaps = function(bufnr, get_rev)
    -- rr, rs, ri, rS, rf, rR, rc, rA, ra, rm, rt, rh
  end,
}

function M.setup(opts)
  core.setup(adapter, opts)
end
```

## Resulting plugin structure

```
sl-fugitive.nvim/
└── lua/sl-fugitive/
    ├── init.lua          # adapter definition + setup
    └── log_actions.lua   # sl-specific mutation keymaps (optional)

jj-fugitive.nvim/
└── lua/jj-fugitive/
    ├── init.lua          # adapter definition + setup
    └── log_actions.lua   # jj-specific mutation keymaps (optional)

fugitive-core.nvim/        # shared dependency
└── lua/fugitive-core/
    └── ...               # everything listed above
```

## Migration plan

1. ~~Create `fugitive-core.nvim` repo~~ **DONE**
2. ~~Extract `ui.lua` and `ansi.lua` first (easiest, highest value)~~ **DONE**
   - `ui.lua` extracted with all shared functions; `file_at_rev()` (VCS-specific)
     and `show_aliases()` (jj-only) left in plugins
   - `ansi.lua` extracted verbatim; namespace unified to `fugitive_core_ansi`,
     default prefix `FcDiff` (callers override via `opts.prefix`),
     buffer variable unified to `fugitive_plugin_buffer`
   - `init.lua` created (minimal: stores adapter + config)
   - `luacheck` and `stylua` pass clean
3. **NEXT:** Update both plugins to depend on fugitive-core `ui`/`ansi`
   - Replace `require("sl-fugitive.ui")` / `require("jj-fugitive.ui")` with
     `require("fugitive-core.ui")` for shared functions
   - Keep plugin-local `ui.lua` as a thin wrapper re-exporting core +
     VCS-specific functions (`file_at_rev`, `show_aliases`)
   - Same pattern for `ansi.lua` — re-export core + set `opts.prefix`
4. Extract view modules one at a time, starting with `describe.lua` (simplest)
5. Move `diff.lua`, `browse.lua`, `completion.lua` next
6. Then `status.lua`, `bookmark.lua`, `annotate.lua`
7. Finally `log.lua` (most complex, most VCS-specific)
8. Each step: verify both plugins still work before moving to next

## Verification

After each extraction step:
- `luacheck lua/ plugin/` passes in all three repos
- `stylua --check lua/ plugin/` passes in all three repos
- Manual test in Neovim: `:S log`, `:J log`, and the affected view
- Run the CHECKLIST.md items for the migrated surface
