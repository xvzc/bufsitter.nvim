---@mod bufsitter.cursor Cursor

---@class bufsitter.cursor.range
---@field sr integer
---@field sc integer
---@field er integer
---@field ec integer

---@class bufsitter.cursor.opts
---@field names? string[]
---@field types? string[]

---@alias bufsitter.cursor.fn fun(bufnr: integer, node: TSNode): boolean

---@class bufsitter.Cursor
---@field private _exec fun(bufnr: integer): TSNode[]
---@field private _prev bufsitter.Cursor|nil
local Base = {}
Base.__index = Base

---@class bufsitter.MultiCursor : bufsitter.Cursor
local Multi = setmetatable({}, { __index = Base })
Multi.__index = Multi

---@class bufsitter.SingleCursor : bufsitter.Cursor
local Single = setmetatable({}, { __index = Base })
Single.__index = Single

local function call_impl(self, bufnr)
  local nodes = self._exec(bufnr)
  local result = {}
  for _, node in ipairs(nodes) do
    local sr, sc, er, ec = node:range()
    table.insert(result, { node = node, range = { sr = sr, sc = sc, er = er, ec = ec } })
  end
  return result
end

Multi.__call = call_impl
Single.__call = call_impl

-- Factories

local function new_multi(exec, prev)
  return setmetatable({ _exec = exec, _prev = prev }, Multi)
end

local function new_single(exec, prev)
  return setmetatable({ _exec = exec, _prev = prev }, Single)
end

-- Shared helpers

local function get_parser(bufnr)
  local ft = vim.bo[bufnr].filetype
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
  if not ok or not parser then
    return nil
  end
  return parser
end

local function type_matches(node, types)
  if not types or #types == 0 then
    return true
  end
  for _, t in ipairs(types) do
    if node:type() == t then
      return true
    end
  end
  return false
end

local function node_in_field(node, parent, name)
  for _, f in ipairs(parent:field(name)) do
    if f == node then
      return true
    end
  end
  return false
end

-- collect named children of `parent`, filtered by opts (names AND types)
local function collect_children(parent, opts)
  local candidates = {}
  if opts and opts.names and #opts.names > 0 then
    local seen = {}
    for _, name in ipairs(opts.names) do
      for _, child in ipairs(parent:field(name)) do
        if not seen[child] then
          seen[child] = true
          table.insert(candidates, child)
        end
      end
    end
  else
    for i = 0, parent:named_child_count() - 1 do
      table.insert(candidates, parent:named_child(i))
    end
  end
  if not opts or not opts.types or #opts.types == 0 then
    return candidates
  end
  local result = {}
  for _, child in ipairs(candidates) do
    if type_matches(child, opts.types) then
      table.insert(result, child)
    end
  end
  return result
end

-- check if `node` matches opts, given its `parent` for field-name checking (names AND types)
local function node_matches(node, parent, opts)
  if not opts then
    return true
  end
  if not type_matches(node, opts.types) then
    return false
  end
  if opts.names and #opts.names > 0 then
    if not parent then
      return false
    end
    for _, name in ipairs(opts.names) do
      if node_in_field(node, parent, name) then
        return true
      end
    end
    return false
  end
  return true
end

-- Base methods (shared by Multi and Single)

---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
function Base:children(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      for _, child in ipairs(collect_children(node, opts)) do
        table.insert(result, child)
      end
    end
    return result
  end)
end

local function make_or_else(self, constructor)
  if not self._prev then
    return self
  end
  local current_exec = self._exec
  local prev_exec = self._prev._exec
  return constructor(function(bufnr)
    local nodes = current_exec(bufnr)
    if #nodes > 0 then
      return nodes
    end
    return prev_exec(bufnr)
  end)
end

-- MultiCursor methods

---@param fn bufsitter.cursor.fn
---@return bufsitter.MultiCursor
function Multi:filter(fn)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      if fn(bufnr, node) then
        table.insert(result, node)
      end
    end
    return result
  end, prev)
end

---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
function Multi:parents(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p and node_matches(p, p:parent(), opts) then
        table.insert(result, p)
      end
    end
    return result
  end)
end

---@return bufsitter.MultiCursor
function Multi:or_else()
  return make_or_else(self, new_multi)
end

---@param n integer 1-based; negative counts from end (-1 = last); 0 is an error
---@return bufsitter.SingleCursor
function Multi:nth(n)
  assert(n ~= 0, "nth: index cannot be 0")
  local prev = self
  return new_single(function(bufnr)
    local nodes = prev._exec(bufnr)
    if #nodes == 0 then
      return {}
    end
    local idx = n > 0 and n or (#nodes + n + 1)
    local node = nodes[idx]
    return node and { node } or {}
  end)
end

---@return bufsitter.SingleCursor
function Multi:first()
  return self:nth(1)
end

---@return bufsitter.SingleCursor
function Multi:last()
  return self:nth(-1)
end

---@param fn bufsitter.cursor.fn
---@return bufsitter.SingleCursor
function Multi:any(fn)
  return self:filter(fn):first()
end

---@param msg? string
---@param fn? bufsitter.cursor.fn
---@return bufsitter.MultiCursor
function Multi:assert(msg, fn)
  local prev = self
  return new_multi(function(bufnr)
    local nodes = prev._exec(bufnr)
    if #nodes == 0 then
      error(msg or "bufsitter: no nodes found", 2)
    end
    if fn then
      for _, node in ipairs(nodes) do
        if not fn(bufnr, node) then
          error(msg or "bufsitter: assertion failed", 2)
        end
      end
    end
    return nodes
  end, prev._prev)
end

-- SingleCursor methods

---@param opts? bufsitter.cursor.opts
---@return bufsitter.SingleCursor
function Single:parent(opts)
  local prev = self
  return new_single(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p and node_matches(p, p:parent(), opts) then
        table.insert(result, p)
      end
    end
    return result
  end, prev)
end

---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
function Single:siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p then
        for _, sib in ipairs(collect_children(p, opts)) do
          if sib ~= node then
            table.insert(result, sib)
          end
        end
      end
    end
    return result
  end)
end

---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
function Single:next_siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      local sib = node:next_named_sibling()
      while sib ~= nil do
        if node_matches(sib, p, opts) then
          table.insert(result, sib)
        end
        sib = sib:next_named_sibling()
      end
    end
    return result
  end)
end

---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
function Single:prev_siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      local sib = node:prev_named_sibling()
      while sib ~= nil do
        if node_matches(sib, p, opts) then
          table.insert(result, sib)
        end
        sib = sib:prev_named_sibling()
      end
    end
    return result
  end)
end

---@return bufsitter.SingleCursor
function Single:or_else()
  return make_or_else(self, new_single)
end

---@param msg? string
---@param fn? bufsitter.cursor.fn
---@return bufsitter.SingleCursor
function Single:assert(msg, fn)
  local prev = self
  return new_single(function(bufnr)
    local nodes = prev._exec(bufnr)
    if fn then
      local node = nodes[1]
      if not node or not fn(bufnr, node) then
        error(msg or "bufsitter: assertion failed", 2)
      end
    elseif #nodes == 0 then
      error(msg or "bufsitter: no nodes found", 2)
    end
    return nodes
  end, prev._prev)
end

-- Public API

local M = {}

---@return bufsitter.MultiCursor
function M.root()
  return new_multi(function(bufnr)
    local parser = get_parser(bufnr)
    if not parser then
      return {}
    end
    local root = parser:parse()[1]:root()
    return root and { root } or {}
  end)
end

---@param query_str string
---@return bufsitter.MultiCursor
function M.query(query_str)
  return new_multi(function(bufnr)
    local parser = get_parser(bufnr)
    if not parser then
      return {}
    end
    local ft = vim.bo[bufnr].filetype
    local query = vim.treesitter.query.parse(ft, query_str)
    local root = parser:parse()[1]:root()
    local result = {}
    for _, node in query:iter_captures(root, bufnr) do
      table.insert(result, node)
    end
    return result
  end)
end

return M
