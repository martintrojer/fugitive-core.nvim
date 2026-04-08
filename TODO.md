# TODO

## Shared navigation keymaps

All views set up `gl/gs/gb/gR/g?/q/R` individually. A shared
`setup_navigation_keymaps(bufnr, callbacks)` would reduce per-view boilerplate
(~15-20 lines duplicated 7 times per plugin).

## Unified VCS adapter interface

Currently plugins use per-module callbacks. A single adapter table per plugin
(name, commands, parsers, mutations) passed to `core.setup()` would let the core
own more of the view lifecycle and further shrink the plugins.

## Slim down plugin modules

With a unified adapter and shared keymap registration, each plugin could shrink
toward just `init.lua` + a VCS-specific actions module.
