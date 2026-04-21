---@mod bufsitter.config
---@brief [[
--- Configuration module for bufsitter.nvim.
--- Call `setup()` once during plugin initialization to set global defaults.
---@brief ]]

---@class bufsitter.config.io.opts
---@field on_error? fun(err: string)

---@class bufsitter.config.opts
---@field scratch? bufsitter.scratch.opts
---@field ref? bufsitter.ref.opts
---@field io? bufsitter.config.io.opts

local M = {}

---@type bufsitter.config.opts
local default = {
  scratch = {
    ft = "markdown",
    init_contents = {},
    on_attach = nil,
    win = {
      relative = "editor",
      width = 80,
      height = 20,
      row = 5,
      col = 10,
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

---@param opts? bufsitter.config.opts
function M.setup(opts)
  ---@type bufsitter.config.opts
  M.config = vim.tbl_deep_extend("force", default, opts or {})
end

return M
