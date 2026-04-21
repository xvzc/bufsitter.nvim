# bufsitter.nvim

Treesitter-powered buffer manipulation for Neovim.

bufsitter provides a chainable cursor API for traversing syntax trees, and a set of IO primitives for reading, writing, and transforming buffer content — all driven by treesitter node ranges.

## Requirements

- Neovim >= 0.12.1
- A treesitter parser installed for the filetype you want to work with

## Installation

**lazy.nvim**

```lua
{
  "xvzc/bufsitter.nvim",
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

## Modules

### `bufsitter.cursor`

Lazy, chainable treesitter traversal. A cursor describes a traversal but does not touch any buffer until `:exec(bufnr)` is called. The same cursor can be reused across buffers.

```lua
local cursor = require("bufsitter.cursor")

-- All top-level function declarations
cursor.root():children({ types = { "function_declaration" } }):exec(bufnr)

-- First function declaration
cursor.root():children({ types = { "function_declaration" } }):first():exec(bufnr)

-- Filter by node text
cursor.root():children():filter(function(b, node)
  return vim.treesitter.get_node_text(node, b) == "main"
end):exec(bufnr)

-- Navigate up
cursor.root():children():first():parent():exec(bufnr)

-- Siblings
cursor.root():children():first():next_siblings():exec(bufnr)

-- Treesitter query
cursor.query("(function_declaration name: (identifier) @name)"):exec(bufnr)
```

### `bufsitter.io`

Buffer read/write operations. Accepts either a `cursor` or an explicit `start_row`/`end_row` range. When a cursor is used, operations apply to every matched node.

```lua
local io = require("bufsitter.io")
local cursor = require("bufsitter.cursor")

local bufnr = vim.api.nvim_get_current_buf()
local fns = cursor.root():children({ types = { "function_declaration" } })

-- Read
local results = io.select(bufnr, { cursor = fns })
-- results[1] == { "func foo() {", "  ...", "}" }

local texts = io.select_text(bufnr, { cursor = fns })
-- texts[1] == "func foo() {\n  ...\n}"

-- Insert after each matched node
io.insert(bufnr, { "// generated" }, { cursor = fns })

-- Insert before
io.insert(bufnr, { "// generated" }, { cursor = fns, prepend = true })

-- Insert inline (no newline)
io.insert(bufnr, { " // note" }, { cursor = fns:first(), inline = true })

-- Delete
io.delete(bufnr, { cursor = fns:first() })

-- Replace
io.replace(bufnr, { "func foo() {}" }, { cursor = fns:first() })

-- Clear buffer
io.clear(bufnr)
```

**`trim_end`** (default `true`): when using a cursor, the operation endpoint is resolved to the last non-blank line of the node. Set `trim_end = false` to use the raw treesitter range instead.

**`hook`**: transform content before it is written.

```lua
io.insert(bufnr, { "hello" }, {
  cursor = fns,
  hook = function(b, lines)
    return vim.tbl_map(function(l) return "-- " .. l end, lines)
  end,
})
```

### `bufsitter.scratch`

Floating scratch buffer with show/hide/toggle lifecycle.

```lua
local Scratch = require("bufsitter.scratch")

local s = Scratch.new({
  ft = "markdown",
  init_contents = { "# Notes", "" },
  on_attach = function(bufnr)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr })
  end,
})

s:show()
s:hide()
s:toggle()
s:delete()

-- Override window options at show time
s:show({ width = 0.9, height = 0.8 })
```

### `bufsitter.ref`

Generates a human-readable reference string for the current buffer or visual selection.

```lua
local ref = require("bufsitter.ref")

ref.buffer()                  -- "~/project/main.lua"
ref.buffer({ expand = true }) -- "/home/user/project/main.lua"
ref.visual_selection()        -- "~/project/main.lua:L10~L15"
ref.get()                     -- visual_selection in visual mode, buffer otherwise
```

## Example: AI-assisted code editing

A common pattern is combining `scratch`, `cursor`, `io`, and `ref` to build a lightweight AI editing workflow.

```lua
local Scratch = require("bufsitter.scratch")
local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local ref = require("bufsitter.ref")

-- Open a scratch buffer as a prompt pad
local pad = Scratch.new({
  ft = "markdown",
  on_attach = function(bufnr)
    -- Submit the prompt on <CR> in normal mode
    vim.keymap.set("n", "<cr>", function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- send lines to your AI backend of choice
    end, { buffer = bufnr })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr })
  end,
})

-- Yank a reference to the selected code into the prompt pad
vim.keymap.set("v", "<leader>ar", function()
  local r = ref.get()
  io.insert(pad:bufnr(), { r })
  pad:show()
end)

-- Insert AI output after the function the cursor is on
vim.keymap.set("n", "<leader>ai", function()
  local bufnr = vim.api.nvim_get_current_buf()
  io.insert(bufnr, { "-- TODO: generated" }, {
    cursor = cursor
      .root()
      :children({ types = { "function_declaration" } })
      :first(),
  })
end)
```
