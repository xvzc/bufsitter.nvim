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

---@class Bufsitter
local M = {}

local config = require("bufsitter.config")

---@param opts? bufsitter.config.opts
function M.setup(opts)
  config.setup(opts)
end

return M
