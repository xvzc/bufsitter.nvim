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
---@field hook? fun(ref: string): string

local M = {}

---@param opts? bufsitter.ref.opts
---@return string
local function visual_selection(opts)
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

---@param opts? bufsitter.ref.opts
---@return string
local function buffer(opts)
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

---Returns a reference string for the current context: delegates to
---`visual_selection` when in a visual mode, otherwise to `buffer`.
---An optional `hook` function receives the final reference string and may
---return a modified path before it is returned to the caller.
---@param opts? bufsitter.ref.opts
---@return string
---@usage [[
---vim.keymap.set({ "n", "v" }, "<leader>r", function()
---  local ref = require("bufsitter.ref").get({
---    hook = function(r)
---      return r:gsub("^/home/user", "~")
---    end,
---  })
---  vim.fn.setreg("+", ref)
---end)
---@usage ]]
function M.get(opts)
  local mode = vim.api.nvim_get_mode().mode
  local result
  if mode == "v" or mode == "V" or mode == "\22" then
    result = visual_selection(opts)
  else
    result = buffer(opts)
  end

  if opts and opts.hook then
    result = opts.hook(result)
  end

  return result
end

return M
