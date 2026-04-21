# bufsitter.nvim

> **Experimental.** APIs may change without notice. Not recommended for production use.

Treesitter-powered buffer manipulation for Neovim.

bufsitter provides a chainable cursor API for traversing syntax trees, and a set of IO primitives for reading, writing, and transforming buffer content — all driven by treesitter node ranges.

> **Note:** bufsitter depends on [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), which is currently archived. Future Neovim versions may introduce breaking changes that affect stability.

## Requirements

- Neovim >= 0.12.1
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with parsers installed for the filetypes you want to work with

## Installation

**lazy.nvim**

```lua
{
  "xvzc/bufsitter.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("bufsitter").setup()
  end,
}
```

## Configuration

```lua
require("bufsitter").setup({
  scratch = {
    ft = "markdown",
    init_contents = {},  -- string[] or fun(): string[]
    on_attach = nil,     -- fun(bufnr: integer)
    win = {
      relative = "editor",
      width = 0.5,       -- absolute columns, or 0–1 ratio
      height = 0.7,      -- absolute rows, or 0–1 ratio
      min_width = nil,   -- clamp width to a minimum
      min_height = nil,
      row = nil,         -- nil = centered
      col = nil,         -- nil = centered
      style = "minimal",
      border = "rounded",
    },
  },
  io = {
    on_error = nil,      -- fun(err: string) — global error handler for cursor ops
  },
  ref = {
    expand = false,      -- expand paths to absolute when true
  },
})
```

## Usage

Given a markdown buffer:

```markdown
# Shopping List

- apples
- oranges

# Todo
```

Insert a new item into the `Shopping List` section by matching the heading text:

```lua
local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")

local bufnr = vim.api.nvim_get_current_buf()

io.insert(bufnr, { "- milk" }, {
  cursor = cursor
    .root()
    :children({ types = { "section" } })
    :children({ types = { "atx_heading" } })
    :children({ names = { "heading_content" }, texts = { "Shopping List" } })
    :first()
    :parent()
    :siblings({ types = { "list" } })
    :last(),
})
```

Result:

```markdown
# Shopping List

- apples
- oranges
- milk

# Todo
```
