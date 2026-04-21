---@mod bufsitter.scratch Scratch
---@brief [[
---Floating scratch buffer with show/hide/toggle lifecycle management.
---
---A `Scratch` is a unlisted, non-file buffer displayed in a floating window.
---Window position and size are configured via |bufsitter.scratch.win.opts|.
---Initial content can be provided as a string array or a function, and an
---`on_attach` callback runs once on buffer creation.
---@brief ]]

---@class bufsitter.scratch.win.opts
---@field relative? string
---@field width? number Width in columns, or a ratio 0–1 relative to editor width
---@field height? number Height in rows, or a ratio 0–1 relative to editor height
---@field row? integer Top row of the window (computed from center when omitted)
---@field col? integer Left column of the window (computed from center when omitted)
---@field style? string
---@field border? string

---@class bufsitter.scratch.opts
---@field ft? string
---@field init_contents? string[] | fun(): string[]
---@field on_attach? fun(bufnr: integer)
---@field win? bufsitter.scratch.win.opts

---@class bufsitter.Scratch
---@field private _bufnr integer
---@field private _winid integer|nil
---@field private _win_opts bufsitter.scratch.win.opts
local Scratch = {}
Scratch.__index = Scratch

local function resolve_dim(value, total)
  if value and value > 0 and value < 1 then
    return math.floor(total * value)
  end
  return value
end

---Creates a new scratch buffer, deep-merging `opts` over the global defaults.
---Sets the filetype, writes `init_contents`, and calls `on_attach` if provided.
---@param opts? bufsitter.scratch.opts
---@return bufsitter.Scratch
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new({
---  ft = "markdown",
---  init_contents = { "# Notes", "" },
---  on_attach = function(bufnr)
---    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr })
---  end,
---})
---@usage ]]
function Scratch.new(opts)
  opts = vim.tbl_deep_extend("force", require("bufsitter").config.scratch, opts or {})

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = opts.ft

  local lines = {}
  local init_contents = opts.init_contents
  if type(init_contents) == "function" then
    lines = init_contents()
  elseif type(init_contents) == "table" then
    lines = init_contents
  end
  if lines and #lines > 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  if type(opts.on_attach) == "function" then
    opts.on_attach(bufnr)
  end

  local self = setmetatable({}, Scratch)
  self._bufnr = bufnr
  self._winid = nil
  self._win_opts = opts.win or {}
  return self
end

---Returns the buffer number of the scratch buffer.
---@return integer
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---local bufnr = s:bufnr()
---@usage ]]
function Scratch:bufnr()
  return self._bufnr
end

---Returns true if the underlying buffer still exists.
---@return boolean
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---if s:is_valid() then
---  s:show()
---end
---@usage ]]
function Scratch:is_valid()
  return vim.api.nvim_buf_is_valid(self._bufnr)
end

---Returns true if the floating window is currently open.
---@return boolean
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---if not s:is_visible() then
---  s:show()
---end
---@usage ]]
function Scratch:is_visible()
  return self._winid ~= nil and vim.api.nvim_win_is_valid(self._winid)
end

---Opens the floating window. Width and height ratios (0–1) are resolved against
---the current editor size, and the window is centered unless `row`/`col` are
---explicitly provided. Returns the window id, or nil if the buffer is invalid.
---@param win_opts? bufsitter.scratch.win.opts
---@return integer|nil
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---s:show()
---s:show({ width = 0.8, height = 0.6 })
---@usage ]]
function Scratch:show(win_opts)
  if not self:is_valid() then
    return nil
  end

  local merged = vim.tbl_deep_extend("force", self._win_opts, win_opts or {})
  local width = resolve_dim(merged.width, vim.o.columns)
  local height = resolve_dim(merged.height, vim.o.lines)
  local wopts = vim.tbl_deep_extend("force", {
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }, merged, { width = width, height = height })

  if self:is_visible() then
    vim.api.nvim_win_set_buf(self._winid, self._bufnr)
    vim.api.nvim_win_set_config(self._winid, wopts)
  else
    self._winid = vim.api.nvim_open_win(self._bufnr, true, wopts)
  end

  return self._winid
end

---Closes the floating window without deleting the buffer.
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---s:hide()
---@usage ]]
function Scratch:hide()
  if not self._winid or not vim.api.nvim_win_is_valid(self._winid) then
    return
  end
  vim.api.nvim_win_close(self._winid, false)
  self._winid = nil
end

---Hides the window if visible, shows it otherwise.
---@param win_opts? bufsitter.scratch.win.opts
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---vim.keymap.set("n", "<leader>s", function() s:toggle() end)
---@usage ]]
function Scratch:toggle(win_opts)
  if self:is_visible() then
    self:hide()
  else
    self:show(win_opts)
  end
end

---Closes the floating window and deletes the buffer. The instance should not
---be used after calling this.
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---s:delete()
---@usage ]]
function Scratch:delete()
  if self._winid and vim.api.nvim_win_is_valid(self._winid) then
    vim.api.nvim_win_close(self._winid, false)
  end
  if vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end
  self._winid = nil
end

return Scratch
