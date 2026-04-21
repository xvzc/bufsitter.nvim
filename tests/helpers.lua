local M = {}

function M.clean_bufs()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "nofile" then
      vim.api.nvim_buf_delete(b, { force = true })
    end
  end
end

---@param path string
---@return integer
function M.buf_from_file(path)
  local lines = vim.fn.readfile(path)
  local ft = vim.filetype.match({ filename = path, contents = lines })
  return M.make_buf(lines, ft)
end

---@param lines string[]
---@param ft? string
---@return integer
function M.make_buf(lines, ft)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local ei = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.bo[bufnr].filetype = ft
  vim.o.eventignore = ei
  return bufnr
end

---@param bufnr integer
---@param ft? string
---@return any
function M.get_root(bufnr, ft)
  ft = ft or vim.bo[bufnr].filetype
  local parser = vim.treesitter.get_parser(bufnr, ft)
  return parser:parse()[1]:root()
end

return M
