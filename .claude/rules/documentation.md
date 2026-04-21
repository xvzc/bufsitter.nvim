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
