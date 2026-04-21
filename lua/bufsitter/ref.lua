---@mod bufsitter.ref Ref

---@class bufsitter.ref.opts
---@field expand? boolean

local M = {}

---@param opts? bufsitter.ref.opts
---@return string
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

---@param opts? bufsitter.ref.opts
---@return string
function M.get(opts)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    return M.visual_selection(opts)
  end
  return M.buffer(opts)
end

---@param opts? bufsitter.ref.opts
---@return string
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
