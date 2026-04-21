---@mod bufsitter.io IO

---@class bufsitter.io.select.opts
---@field cursor? bufsitter.Cursor
---@field start_row? integer
---@field start_col? integer
---@field end_row? integer
---@field end_col? integer
---@field on_error? fun(err: string)
---@field hook? fun(bufnr: integer, contents: string[]): string[]?

---@class bufsitter.io.insert.opts
---@field cursor? bufsitter.Cursor
---@field start_row? integer
---@field start_col? integer
---@field end_row? integer
---@field end_col? integer
---@field on_error? fun(err: string)
---@field hook? fun(bufnr: integer, contents: string[]): string[]?
---@field prepend? boolean
---@field inline? boolean

---@class bufsitter.io.delete.opts
---@field cursor? bufsitter.Cursor
---@field start_row? integer
---@field start_col? integer
---@field end_row? integer
---@field end_col? integer
---@field on_error? fun(err: string)

---@class bufsitter.io.replace.opts
---@field cursor? bufsitter.Cursor
---@field start_row? integer
---@field start_col? integer
---@field end_row? integer
---@field end_col? integer
---@field on_error? fun(err: string)
---@field hook? fun(bufnr: integer, contents: string[]): string[]?

local config = require("bufsitter.config")

local M = {}

local function eval_cursor(cursor_fn, bufnr, on_error)
  local handler = on_error
    or (config.config and config.config.io and config.config.io.on_error)
  if handler then
    local ok, result = pcall(cursor_fn, bufnr)
    if not ok then
      handler(tostring(result))
      return nil
    end
    return result
  end
  return cursor_fn(bufnr)
end

-- Treesitter node ranges use exclusive end: er=N,ec=0 means "start of row N".
-- nvim_buf_set_text requires valid positions, so clamp to the end of row N-1.
local function clamp_end(bufnr, er, ec)
  if ec == 0 and er > 0 then
    local prev = vim.api.nvim_buf_get_lines(bufnr, er - 1, er, false)[1] or ""
    return er - 1, #prev
  end
  return er, ec
end

---@param bufnr integer
---@param opts bufsitter.io.select.opts
---@return string[][]|nil
function M.select(bufnr, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  opts = opts or {}

  if opts.cursor then
    local items = eval_cursor(opts.cursor, bufnr, opts.on_error)
    if not items or #items == 0 then
      return nil
    end
    local results = {}
    for _, item in ipairs(items) do
      local r = item.range
      local er, ec = clamp_end(bufnr, r.er, r.ec)
      local lines = vim.api.nvim_buf_get_text(bufnr, r.sr, r.sc, er, ec, {})
      if type(opts.hook) == "function" then
        local res = opts.hook(bufnr, lines)
        if res ~= nil then
          lines = res
        end
      end
      table.insert(results, lines)
    end
    return results
  end

  local lines
  if opts.start_row ~= nil and opts.end_row ~= nil then
    local er, ec = clamp_end(bufnr, opts.end_row, opts.end_col or 0)
    lines =
      vim.api.nvim_buf_get_text(bufnr, opts.start_row, opts.start_col or 0, er, ec, {})
  else
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  if type(opts.hook) == "function" then
    local res = opts.hook(bufnr, lines)
    if res ~= nil then
      lines = res
    end
  end
  return { lines }
end

---@param bufnr integer
---@param opts? bufsitter.io.select.opts
---@return string[]|nil
function M.select_text(bufnr, opts)
  local results = M.select(bufnr, opts)
  if not results then
    return nil
  end
  local texts = {}
  for _, lines in ipairs(results) do
    table.insert(texts, table.concat(lines, "\n"))
  end
  return texts
end

---@param bufnr integer
---@param contents string[]
---@param opts? bufsitter.io.insert.opts
function M.insert(bufnr, contents, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  opts = opts or {}

  if type(opts.hook) == "function" then
    local res = opts.hook(bufnr, contents)
    if res ~= nil then
      contents = res
    end
  end

  if opts.cursor then
    local items = eval_cursor(opts.cursor, bufnr, opts.on_error)
    if not items or #items == 0 then
      return
    end

    local pos_key = opts.prepend and "sr" or "er"
    table.sort(items, function(a, b)
      return a.range[pos_key] > b.range[pos_key]
    end)

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for _, item in ipairs(items) do
      local r = item.range
      if opts.prepend then
        if opts.inline then
          -- attach at exact character position, no newline added
          vim.api.nvim_buf_set_text(bufnr, r.sr, r.sc, r.sr, r.sc, contents)
        else
          vim.api.nvim_buf_set_lines(bufnr, r.sr, r.sr, false, contents)
        end
      else
        if opts.inline then
          -- attach at exact character position, no newline added
          if r.er >= line_count then
            local last = vim.api.nvim_buf_get_lines(
              bufnr,
              line_count - 1,
              line_count,
              false
            )[1] or ""
            vim.api.nvim_buf_set_text(
              bufnr,
              line_count - 1,
              #last,
              line_count - 1,
              #last,
              contents
            )
          else
            vim.api.nvim_buf_set_text(bufnr, r.er, r.ec, r.er, r.ec, contents)
          end
        else
          -- ec=0 means exclusive end (before row r.er), so insert at r.er; otherwise after r.er
          local row = (r.ec == 0) and r.er or (r.er + 1)
          if row > line_count then
            row = line_count
          end
          vim.api.nvim_buf_set_lines(bufnr, row, row, false, contents)
        end
      end
    end
    return
  end

  if opts.start_row ~= nil and opts.end_row ~= nil then
    if opts.prepend then
      if opts.inline then
        vim.api.nvim_buf_set_text(
          bufnr,
          opts.start_row,
          opts.start_col or 0,
          opts.start_row,
          opts.start_col or 0,
          contents
        )
      else
        vim.api.nvim_buf_set_lines(bufnr, opts.start_row, opts.start_row, false, contents)
      end
    else
      if opts.inline then
        vim.api.nvim_buf_set_text(
          bufnr,
          opts.end_row,
          opts.end_col or 0,
          opts.end_row,
          opts.end_col or 0,
          contents
        )
      else
        local rep = vim.list_extend(vim.deepcopy(contents), { "" })
        vim.api.nvim_buf_set_text(
          bufnr,
          opts.end_row,
          opts.end_col or 0,
          opts.end_row,
          opts.end_col or 0,
          rep
        )
      end
    end
    return
  end

  local last_row = vim.api.nvim_buf_line_count(bufnr) - 1
  local last_line = vim.api.nvim_buf_get_lines(bufnr, last_row, last_row + 1, false)[1]
    or ""
  vim.api.nvim_buf_set_text(
    bufnr,
    last_row,
    #last_line,
    last_row,
    #last_line,
    { "", unpack(contents) }
  )
end

---@param bufnr integer
---@param str string
---@param opts? bufsitter.io.insert.opts
function M.insert_text(bufnr, str, opts)
  M.insert(bufnr, vim.split(str, "\n"), opts)
end

---@param bufnr integer
---@param opts? bufsitter.io.delete.opts
function M.delete(bufnr, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  opts = opts or {}

  if opts.cursor then
    local items = eval_cursor(opts.cursor, bufnr, opts.on_error)
    if not items or #items == 0 then
      return
    end

    table.sort(items, function(a, b)
      return a.range.sr > b.range.sr
    end)
    for _, item in ipairs(items) do
      local r = item.range
      local er, ec = clamp_end(bufnr, r.er, r.ec)
      vim.api.nvim_buf_set_text(bufnr, r.sr, r.sc, er, ec, {})
    end
    return
  end

  if opts.start_row ~= nil and opts.end_row ~= nil then
    vim.api.nvim_buf_set_text(
      bufnr,
      opts.start_row,
      opts.start_col or 0,
      opts.end_row,
      opts.end_col or 0,
      {}
    )
  end
end

---@param bufnr integer
---@param contents string[]
---@param opts? bufsitter.io.replace.opts
function M.replace(bufnr, contents, opts)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  opts = opts or {}

  if type(opts.hook) == "function" then
    local res = opts.hook(bufnr, contents)
    if res ~= nil then
      contents = res
    end
  end

  if opts.cursor then
    local items = eval_cursor(opts.cursor, bufnr, opts.on_error)
    if not items or #items == 0 then
      return
    end

    table.sort(items, function(a, b)
      return a.range.sr > b.range.sr
    end)
    for _, item in ipairs(items) do
      local r = item.range
      local er, ec = clamp_end(bufnr, r.er, r.ec)
      vim.api.nvim_buf_set_text(bufnr, r.sr, r.sc, er, ec, vim.deepcopy(contents))
    end
    return
  end

  if opts.start_row ~= nil and opts.end_row ~= nil then
    local er, ec = clamp_end(bufnr, opts.end_row, opts.end_col or 0)
    vim.api.nvim_buf_set_text(
      bufnr,
      opts.start_row,
      opts.start_col or 0,
      er,
      ec,
      contents
    )
  end
end

---@param bufnr integer
---@param str string
---@param opts? bufsitter.io.replace.opts
function M.replace_text(bufnr, str, opts)
  M.replace(bufnr, vim.split(str, "\n"), opts)
end

---@param bufnr integer
function M.clear(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local last_row = vim.api.nvim_buf_line_count(bufnr) - 1
  local last_line = vim.api.nvim_buf_get_lines(bufnr, last_row, last_row + 1, false)[1]
    or ""
  vim.api.nvim_buf_set_text(bufnr, 0, 0, last_row, #last_line, { "" })
end

return M
