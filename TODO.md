# TODO

## Shared navigation keymaps

All views set up `gl/gs/gb/gR/g?/q/R` individually. A shared
`setup_navigation_keymaps(bufnr, callbacks)` would reduce per-view boilerplate.

## Unified VCS adapter interface

The original plan envisioned a single adapter table per plugin (name, commands,
parsers, mutations) passed to `core.setup()`. Currently plugins use per-module
callbacks instead. A unified adapter would allow the core to own more of the
view lifecycle and further shrink the plugins.

## Slim down plugin modules

Plugins still have full module files for each view. With a unified adapter and
shared keymap registration, each plugin could shrink toward just `init.lua` +
a VCS-specific actions module.
