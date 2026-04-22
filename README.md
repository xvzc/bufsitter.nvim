# bufsitter.nvim

> **Experimental.** APIs may change without notice. Not recommended for production use.

Treesitter-powered buffer manipulation for Neovim.

bufsitter provides a chainable cursor API for traversing syntax trees, and a set of IO primitives for reading, writing, and transforming buffer content — all driven by treesitter node ranges.

> **Note:** bufsitter depends on [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), which is currently archived. Future Neovim versions may introduce breaking changes that affect stability.

## Features

- Chainable cursor API for traversing treesitter syntax trees
- IO primitives for reading, writing, and transforming buffer content by node range
- Filter nodes by type, field name, or text content
- Inline and line-level insert, delete, select, and replace operations
- Floating scratch buffer with configurable window options
- Buffer and visual-selection reference strings for use in prompts or notes

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

### Insert into a section by heading text

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
    :next_siblings({ types = { "list" } })
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
