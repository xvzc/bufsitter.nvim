---@mod bufsitter.io IO
---@brief [[
---Buffer read/write operations driven by a cursor or explicit row/col range.
---
---Each function accepts an `opts` table with either a `cursor` field
---(a |bufsitter.Cursor|) or explicit `start_row`/`end_row` coordinates.
---When `cursor` is given, the operation is applied to every node the cursor
---resolves to. An optional `hook` can transform the content before it is
---written, and `on_error` can intercept errors thrown by the cursor.
---@brief ]]

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

local config = require("bufsitter")

local M = {}

local function eval_cursor(cursor_fn, bufnr, on_error)
  local handler = on_error
    or (config.config and config.config.io and config.config.io.on_error)
  if handler then
    local ok, result = pcall(function()
      return cursor_fn:exec(bufnr)
    end)
    if not ok then
      handler(tostring(result))
      return nil
    end
    return result
  end
  return cursor_fn:exec(bufnr)
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

---Reads text from `bufnr`. Returns one `string[]` per matched node when
---`cursor` is used, or a single-element wrapper otherwise.
---Returns `nil` if the buffer is invalid or the cursor yields nothing.
---@param bufnr integer
---@param opts bufsitter.io.select.opts
---@return string[][]|nil
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local results = io.select(bufnr, {
---  cursor = cursor.root():children({ types = { "function_declaration" } }),
---})
----- results[1] == { "func foo() {", "  ...", "}" }
---@usage ]]
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
    for _, node in ipairs(items) do
      local sr, sc, er, ec = node:range()
      er, ec = clamp_end(bufnr, er, ec)
      local lines = vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {})
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

---Like `select`, but joins each node's lines with `\n` and returns a flat
---`string[]` — one string per matched node.
---@param bufnr integer
---@param opts? bufsitter.io.select.opts
---@return string[]|nil
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local texts = io.select_text(bufnr, {
---  cursor = cursor.root():children({ types = { "function_declaration" } }),
---})
----- texts[1] == "func foo() {\n  ...\n}"
---@usage ]]
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

---Inserts `contents` into `bufnr`. When `prepend` is false (default) content
---is placed after each target; when true, before. `inline` inserts at the
---exact character position without adding a new line. Without a cursor or
---range, appends to the end of the buffer.
---@param bufnr integer
---@param contents string[]
---@param opts? bufsitter.io.insert.opts
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
----- append after the first function
---io.insert(bufnr, { "-- generated" }, {
---  cursor = cursor.root():children({ types = { "function_declaration" } }):first(),
---})
----- prepend before it
---io.insert(bufnr, { "-- generated" }, {
---  prepend = true,
---  cursor = cursor.root():children({ types = { "function_declaration" } }):first(),
---})
---@usage ]]
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

    table.sort(items, function(a, b)
      local a_sr, _, a_er = a:range()
      local b_sr, _, b_er = b:range()
      if opts.prepend then
        return a_sr > b_sr
      else
        return a_er > b_er
      end
    end)

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for _, node in ipairs(items) do
      local sr, sc, er, ec = node:range()
      if opts.prepend then
        if opts.inline then
          -- attach at exact character position, no newline added
          vim.api.nvim_buf_set_text(bufnr, sr, sc, sr, sc, contents)
        else
          vim.api.nvim_buf_set_lines(bufnr, sr, sr, false, contents)
        end
      else
        if opts.inline then
          -- attach at exact character position, no newline added
          if er >= line_count then
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
            local end_row, end_col = clamp_end(bufnr, er, ec)
            vim.api.nvim_buf_set_text(bufnr, end_row, end_col, end_row, end_col, contents)
          end
        else
          -- ec=0 means exclusive end (before row er), so insert at er; otherwise after er
          local row = (ec == 0) and er or (er + 1)
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

---Convenience wrapper around `insert` that splits `str` on newlines first.
---@param bufnr integer
---@param str string
---@param opts? bufsitter.io.insert.opts
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---io.insert_text(bufnr, "-- line one\n-- line two", {
---  cursor = cursor.root():children():first(),
---})
---@usage ]]
function M.insert_text(bufnr, str, opts)
  M.insert(bufnr, vim.split(str, "\n"), opts)
end

---Deletes text from `bufnr`. Nodes are deleted in reverse source order to
---preserve row indices for subsequent deletions.
---@param bufnr integer
---@param opts? bufsitter.io.delete.opts
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---io.delete(bufnr, {
---  cursor = cursor.root():children({ types = { "function_declaration" } }):first(),
---})
---@usage ]]
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
      local a_sr = a:range()
      local b_sr = b:range()
      return a_sr > b_sr
    end)
    for _, node in ipairs(items) do
      local sr, sc, er, ec = node:range()
      er, ec = clamp_end(bufnr, er, ec)
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, {})
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

---Replaces the text of each matched node or range with `contents`.
---Multiple matches are replaced in reverse source order to preserve indices.
---@param bufnr integer
---@param contents string[]
---@param opts? bufsitter.io.replace.opts
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---io.replace(bufnr, { "func foo() {}", "}" }, {
---  cursor = cursor.root():children({ types = { "function_declaration" } }):first(),
---})
---@usage ]]
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
      local a_sr = a:range()
      local b_sr = b:range()
      return a_sr > b_sr
    end)
    for _, node in ipairs(items) do
      local sr, sc, er, ec = node:range()
      er, ec = clamp_end(bufnr, er, ec)
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, vim.deepcopy(contents))
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

---Convenience wrapper around `replace` that splits `str` on newlines first.
---@param bufnr integer
---@param str string
---@param opts? bufsitter.io.replace.opts
---@usage [[
---local io = require("bufsitter.io")
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---io.replace_text(bufnr, "func foo() {}\n}", {
---  cursor = cursor.root():children():first(),
---})
---@usage ]]
function M.replace_text(bufnr, str, opts)
  M.replace(bufnr, vim.split(str, "\n"), opts)
end

---Clears all content from `bufnr`, leaving a single empty line.
---@param bufnr integer
---@usage [[
---local io = require("bufsitter.io")
---local bufnr = vim.api.nvim_get_current_buf()
---io.clear(bufnr)
---@usage ]]
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
