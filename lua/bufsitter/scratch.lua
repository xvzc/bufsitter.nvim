---@mod bufsitter.scratch Scratch

---@class bufsitter.scratch.win_opts
---@field relative? string
---@field width? integer
---@field height? integer
---@field row? integer
---@field col? integer
---@field style? string
---@field border? string

---@class bufsitter.scratch.opts
---@field ft? string
---@field init_contents? string[] | fun(): string[]
---@field on_attach? fun(bufnr: integer)
---@field win? bufsitter.scratch.win_opts

---@class bufsitter.Scratch
---@field private _bufnr integer
---@field private _winid integer|nil
---@field private _win_opts bufsitter.scratch.win_opts
local Scratch = {}
Scratch.__index = Scratch

local config = require("bufsitter.config")

---@param opts? bufsitter.scratch.opts
---@return bufsitter.Scratch
function Scratch.new(opts)
  opts = vim.tbl_deep_extend("force", config.config.scratch, opts or {})

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

---@return integer
function Scratch:bufnr()
  return self._bufnr
end

---@return boolean
function Scratch:is_valid()
  return vim.api.nvim_buf_is_valid(self._bufnr)
end

---@return boolean
function Scratch:is_visible()
  return self._winid ~= nil and vim.api.nvim_win_is_valid(self._winid)
end

---@param win_opts? bufsitter.scratch.win_opts
---@return integer|nil
function Scratch:show(win_opts)
  if not self:is_valid() then
    return nil
  end

  local wopts = vim.tbl_deep_extend("force", self._win_opts, win_opts or {})

  if self:is_visible() then
    vim.api.nvim_win_set_buf(self._winid, self._bufnr)
  else
    self._winid = vim.api.nvim_open_win(self._bufnr, true, wopts)
  end

  return self._winid
end

function Scratch:hide()
  if not self._winid or not vim.api.nvim_win_is_valid(self._winid) then
    return
  end
  vim.api.nvim_win_close(self._winid, false)
  self._winid = nil
end

---@param win_opts? bufsitter.scratch.win_opts
function Scratch:toggle(win_opts)
  if self:is_visible() then
    self:hide()
  else
    self:show(win_opts)
  end
end

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
