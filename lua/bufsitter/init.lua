---@toc bufsitter.contents

---@mod bufsitter bufsitter.nvim
---@brief [[
--- Treesitter-powered buffer manipulation for Neovim.
---
--- Quick start:
--->lua
---   require("bufsitter").setup()
---<
---@brief ]]

---@class bufsitter.config.scratch.win.opts
---@field relative? string
---@field width? number Width in columns, or a ratio 0–1 relative to editor width
---@field height? number Height in rows, or a ratio 0–1 relative to editor height
---@field min_width? number Minimum width in columns, or a ratio 0–1 relative to editor width
---@field min_height? number Minimum height in rows, or a ratio 0–1 relative to editor height
---@field row? number Top row, or a ratio 0–1 relative to editor height (centered when omitted)
---@field col? number Left column, or a ratio 0–1 relative to editor width (centered when omitted)
---@field style? string
---@field border? string

---@class bufsitter.config.scratch.opts
---@field ext? string File extension used to name the buffer (e.g. "typ", "md"). Sets buftype to "acwrite" so LSP can attach without writing to disk. Defaults to "md".
---@field force_quit? boolean Suppress unsaved-changes prompt: no-op `:w` and clear modified on `QuitPre`. Defaults to true.
---@field init_contents? string[] | fun(): string[]
---@field on_attach? fun(bufnr: integer)
---@field win? bufsitter.config.scratch.win.opts

---@class bufsitter.config.ref.opts
---@field expand? boolean

---@class bufsitter.config.io.opts
---@field on_error? fun(err: string)

---@class bufsitter.config.opts
---@field scratch? bufsitter.config.scratch.opts
---@field ref? bufsitter.config.ref.opts
---@field io? bufsitter.config.io.opts

---@class Bufsitter
---@field config bufsitter.config.opts
local M = {}

---@type bufsitter.config.opts
local default = {
  scratch = {
    ext = "md",
    force_quit = true,
    init_contents = {},
    on_attach = nil,
    win = {
      relative = "editor",
      width = 0.5,
      height = 0.7,
      min_width = nil,
      min_height = nil,
      row = nil,
      col = nil,
      style = "minimal",
      border = "rounded",
    },
  },
  io = {
    on_error = nil,
  },
  ref = {
    expand = false,
  },
}

---Initializes bufsitter with the given options, deep-merged over the defaults.
---Must be called once before using any other bufsitter API.
---@param opts? bufsitter.config.opts
---@usage [[
---require("bufsitter").setup({
---  scratch = { ft = "markdown" },
---  io = {
---    on_error = function(err)
---      vim.notify(err, vim.log.levels.ERROR)
---    end,
---  },
---})
---@usage ]]
function M.setup(opts)
  ---@type bufsitter.config.opts
  M.config = vim.tbl_deep_extend("force", default, opts or {})
  vim.g.bufsitter_loaded = 1
end

if not vim.g.bufsitter_loaded then
  M.setup()
end

return M
