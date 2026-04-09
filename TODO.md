# TODO

## Architecture

- [ ] Split `ui.lua` — it's becoming a grab-bag (buffers, keymaps, prompts, file ops, views, node parsing)
- [ ] `init.lua` is almost empty — config propagation feels like a workaround
- [ ] `views/diff.lua` is very thin (show + parse_diff_files) — may not justify its own file
- [ ] `M.ns` exported from `ansi.lua` but never used externally — remove or document

## Cleanup

- [ ] `highlight default link` uses `vim.cmd` strings instead of `vim.api.nvim_set_hl` — inconsistent with rest of file
- [ ] `describe.lua` and `process_diff_content` use manual `table.insert` loops — use `vim.list_extend`

## Plugin helpers

- [ ] Plugin-level `make_view_callbacks()` to eliminate repeated `close_cmd(); require("X").show()` pattern

## Tests

- [ ] Unit tests for pure functions: `parse_remote_url`, `parse_ansi_colors`, `node_from_line`, `line_range`, `build_file_url`, `build_custom_file_url`

## Help text

- [ ] `g?` help content is maintained manually per view — consider generating from keymap registrations
