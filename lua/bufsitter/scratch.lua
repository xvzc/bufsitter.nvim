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
---@field min_width? number Minimum width in columns, or a ratio 0–1 relative to editor width
---@field min_height? number Minimum height in rows, or a ratio 0–1 relative to editor height
---@field row? number Top row, or a ratio 0–1 relative to editor height (centered when omitted)
---@field col? number Left column, or a ratio 0–1 relative to editor width (centered when omitted)
---@field style? string
---@field border? string

---@class bufsitter.scratch.opts
---@field ext? string File extension used to name the buffer (e.g. "typ", "md"). Sets buftype to "acwrite" so LSP can attach without writing to disk. Defaults to "md".
---@field force_quit? boolean Suppress unsaved-changes prompt: no-op `:w` and clear modified on `QuitPre`. Defaults to true.
---@field init_contents? string[] | fun(): string[]
---@field on_attach? fun(bufnr: integer)
---@field win? bufsitter.scratch.win.opts

---@class bufsitter.Scratch
---@field private _bufnr integer
---@field private _winid integer|nil
---@field private _win_opts bufsitter.scratch.win.opts
---@field private _ext string|nil
---@field private _force_quit boolean
---@field private _on_attach fun(bufnr: integer)|nil
---@field private _init_contents string[]|fun(): string[]|nil
local Scratch = {}
Scratch.__index = Scratch

local function resolve_dim(value, total)
  if value and value > 0 and value < 1 then
    return math.floor(total * value)
  end
  return value
end

local function init_buf(self)
  local bufnr = vim.api.nvim_create_buf(false, true)

  local path = vim.fn.stdpath("data") .. "/bufsitter_" .. bufnr .. "." .. self._ext
  vim.api.nvim_buf_set_name(bufnr, path)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "hide"
  local ft = vim.filetype.match({ filename = path })
  if ft then
    vim.bo[bufnr].filetype = ft
  end

  local lines = {}
  local init_contents = self._init_contents
  if type(init_contents) == "function" then
    lines = init_contents()
  elseif type(init_contents) == "table" then
    lines = init_contents
  end
  if lines and #lines > 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  self._bufnr = bufnr

  local group =
    vim.api.nvim_create_augroup("bufsitter_scratch_" .. bufnr, { clear = true })

  -- Re-layout the floating window when the editor is resized (e.g. tmux pane resize).
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if self:is_visible() then
        self:show()
      end
    end,
  })
  -- Suppress unsaved-changes prompt: no-op :w and clear modified on QuitPre.
  if self._force_quit then
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      group = group,
      buffer = bufnr,
      callback = function()
        vim.bo[bufnr].modified = false
      end,
    })
    vim.api.nvim_create_autocmd("QuitPre", {
      group = group,
      callback = function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.bo[bufnr].modified = false
        end
      end,
    })
  end
  -- Run on_attach once when the buffer first enters a window, so LSP and
  -- treesitter can attach with a valid window context.
  if type(self._on_attach) == "function" then
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = group,
      buffer = bufnr,
      once = true,
      callback = function()
        self._on_attach(bufnr)
      end,
    })
  end

  -- Clean up the augroup when the buffer is deleted.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
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

  local self = setmetatable({}, Scratch)
  self._winid = nil
  self._win_opts = opts.win or {}
  self._ext = opts.ext
  self._force_quit = opts.force_quit
  self._on_attach = type(opts.on_attach) == "function" and opts.on_attach or nil
  self._init_contents = opts.init_contents

  init_buf(self)

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

---Returns true if the underlying buffer still exists and is loaded.
---An unloaded `nofile` buffer has lost its content and is treated as invalid.
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
    and vim.api.nvim_buf_is_loaded(self._bufnr)
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

---Opens the floating window. All of `width`, `height`, `row`, and `col` accept
---either an absolute integer or a 0–1 ratio relative to the editor size.
---`row` and `col` default to centered when omitted.
---If the buffer was deleted externally (e.g. via `:bd`), it is recreated from
---`init_contents` before the window is opened.
---Returns the window id.
---@param win_opts? bufsitter.scratch.win.opts
---@return integer
---@usage [[
---local Scratch = require("bufsitter.scratch")
---local s = Scratch.new()
---s:show()
---s:show({ width = 0.8, height = 0.6 })
---s:show({ width = 0.8, height = 0.6, row = 0.1, col = 0.1 })
---@usage ]]
function Scratch:show(win_opts)
  if not self:is_valid() then
    init_buf(self)
  end

  local merged = vim.tbl_deep_extend("force", self._win_opts, win_opts or {})
  local width = resolve_dim(merged.width, vim.o.columns)
  local height = resolve_dim(merged.height, vim.o.lines)
  if merged.min_width then
    width = math.max(width, resolve_dim(merged.min_width, vim.o.columns))
  end
  if merged.min_height then
    height = math.max(height, resolve_dim(merged.min_height, vim.o.lines))
  end
  local row = merged.row and resolve_dim(merged.row, vim.o.lines)
    or math.floor((vim.o.lines - height) / 2)
  local col = merged.col and resolve_dim(merged.col, vim.o.columns)
    or math.floor((vim.o.columns - width) / 2)
  local wopts = vim.tbl_deep_extend("force", merged, {
    width = width,
    height = height,
    row = row,
    col = col,
  })

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
  for _, winid in ipairs(vim.fn.win_findbuf(self._bufnr)) do
    vim.api.nvim_win_close(winid, false)
  end
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
