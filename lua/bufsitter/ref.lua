---@mod bufsitter.ref Ref
---@brief [[
---Generates a human-readable reference string for the current buffer or
---visual selection, in the form `path:LN` or `path:LN~LM`.
---
---Useful for inserting source references into scratch buffers or prompts.
---When `expand` is true, the path is expanded to an absolute path;
---otherwise it is relative to the home directory (`~`).
---@brief ]]

---@class bufsitter.ref.opts
---@field expand? boolean

local M = {}

---Returns a reference string for the most recent visual selection.
---Format: `path:LN` for a single line, `path:LN~LM` for a range.
---Falls back to the buffer name alone if no selection marks are set.
---@param opts? bufsitter.ref.opts
---@return string
---@usage [[
----- in a keymap callback, after making a visual selection
---local ref = require("bufsitter.ref").visual_selection()
----- "~/project/main.lua:L10~L15"
---@usage ]]
function M.visual_selection(opts)
  opts = opts or {}

  -- 1. Exit visual mode FIRST to force update of '< and '> marks
  -- Use "xt" to ensure type codes are handled and the call is synchronous enough
  vim.cmd([[execute "normal! \<Esc>"]])

  local name = vim.api.nvim_buf_get_name(0)
  name = (name == "") and "[No Name]"
    or vim.fn.fnamemodify(name, opts.expand and ":p" or ":~")

  -- 2. Now these marks are guaranteed to be updated to the recent selection
  local s = vim.fn.getpos("'<")[2]
  local e = vim.fn.getpos("'>")[2]

  if s == 0 or e == 0 then
    return name
  end

  return s == e and ("%s:L%d"):format(name, s) or ("%s:L%d~L%d"):format(name, s, e)
end

---Returns a reference string for the current context: delegates to
---`visual_selection` when in a visual mode, otherwise to `buffer`.
---@param opts? bufsitter.ref.opts
---@return string
---@usage [[
---vim.keymap.set({ "n", "v" }, "<leader>r", function()
---  local ref = require("bufsitter.ref").get()
---  vim.fn.setreg("+", ref)
---end)
---@usage ]]
function M.get(opts)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    return M.visual_selection(opts)
  end
  return M.buffer(opts)
end

---Returns the name of the current buffer. Returns `"[No Name]"` for unnamed
---buffers. With `expand = true`, returns the absolute path.
---@param opts? bufsitter.ref.opts
---@return string
---@usage [[
---local ref = require("bufsitter.ref")
---ref.buffer()                    -- "~/project/main.lua"
---ref.buffer({ expand = true })   -- "/Users/user/project/main.lua"
---@usage ]]
function M.buffer(opts)
  opts = opts or {}
  local expand = opts.expand or false
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" then
    return "[No Name]"
  end

  if expand then
    buf_name = vim.fn.fnamemodify(buf_name, ":p")
  else
    buf_name = vim.fn.fnamemodify(buf_name, ":~")
  end
  return buf_name
end

return M
