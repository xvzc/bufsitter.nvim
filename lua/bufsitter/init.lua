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

---@class bufsitter.config.scratch.opts
---@field ft? string
---@field init_contents? string[] | fun(): string[]
---@field on_attach? fun(bufnr: integer)
---@field win? bufsitter.scratch.win.opts

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
    ft = "markdown",
    init_contents = {},
    on_attach = nil,
    win = {
      relative = "editor",
      width = 0.6,
      height = 0.4,
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
