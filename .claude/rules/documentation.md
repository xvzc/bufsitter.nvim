# Documentation

Documentation annotations follow the same style as Lua type annotations: no leading space after `---`.

```lua
-- correct
---@mod bufsitter.io IO
---@brief [[
---Treesitter-powered buffer manipulation.
---@brief ]]

-- incorrect
--- @mod bufsitter.io IO
--- @brief [[
```

Nested types use dot notation to separate namespaces, not underscores:

```lua
-- correct
---@class bufsitter.scratch.win.opts

-- incorrect
---@class bufsitter.scratch.win_opts
```

Example code blocks must declare every variable they use. Never assume `bufnr`, `cursor`, `s`, or any other variable is already in scope:

```lua
-- correct
--->lua
---  local cursor = require("bufsitter.cursor")
---  local items = cursor.root():children()(bufnr)
---<

-- incorrect
--->lua
---  local items = cursor.root():children()(bufnr)
---<
```

Body text inside annotation blocks (e.g. `---@brief`) may use a leading space for indentation purposes:

```lua
---@brief [[
---Top-level description.
---
--- Indented paragraph or example:
--->lua
---  require("bufsitter").setup()
---<
---@brief ]]
```
