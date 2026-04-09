# TODO

## Architecture

- [ ] Split `ui.lua` — 300+ lines of unrelated concerns (buffers, keymaps, prompts, file ops, side-by-side, view switching, node parsing)
- [ ] Config propagation is backwards — plugins own config, copy to core via `setup()`. Core's `init.lua` is just a global holder. A third plugin would race. Adapter interface would fix this
- [ ] `views/diff.lua` is very thin (show + parse_diff_files) — may not justify its own file

## Plugin helpers

- [ ] `make_view_callbacks(current_view)` factory — every view builds the same `{ log = function() close(); show() end, ... }` table with minor variations
- [ ] `g?` help text is hand-written per view, drifts from actual keymaps — consider generating from keymap registrations
