# TODO

## Unified VCS adapter interface

Currently plugins use per-module callbacks. A single adapter table per plugin
(name, commands, parsers, mutations) passed to `core.setup()` would let the core
own more of the view lifecycle and further shrink the plugins.

## Slim down plugin modules

With a unified adapter, each plugin could shrink toward just `init.lua` +
a VCS-specific actions module.
