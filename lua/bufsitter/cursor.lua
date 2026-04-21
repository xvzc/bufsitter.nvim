---@mod bufsitter.cursor Cursor
---@brief [[
---Lazy treesitter node traversal API.
---
---A cursor is a reusable, lazy query — it describes a traversal chain but does
---not touch any buffer until |bufsitter.Cursor:exec| is called. The same cursor
---instance can be passed to multiple |bufsitter.io| functions or evaluated
---against different buffers without rebuilding the chain.
---
---Two cursor types exist:
---
--- - |bufsitter.MultiCursor|  — holds zero or more nodes
--- - |bufsitter.SingleCursor| — holds at most one node
---
---|bufsitter.Cursor:exec| evaluates the chain and returns a flat list of TSNode
---values matched in that buffer at that moment. Each TSNode exposes the standard
---treesitter API (`:type()`, `:range()`, `:named_child()`, etc.).
---
---Entry points are |bufsitter.cursor.root| and |bufsitter.cursor.query|.
---Cursors are passed to `io.*` functions via the `cursor` field in opts.
---@brief ]]

---@class bufsitter.cursor.opts
---@field names? string[]
---@field types? string[]
---@field texts? string[]

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

local function text_matches(node, bufnr, texts)
  if not texts or #texts == 0 then
    return true
  end
  local text = vim.treesitter.get_node_text(node, bufnr)
  for _, t in ipairs(texts) do
    if text == t then
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

-- collect named children of `parent`, filtered by opts (names AND types AND texts)
local function collect_children(parent, opts, bufnr)
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
  if not opts or (not opts.types and not opts.texts) then
    return candidates
  end
  local result = {}
  for _, child in ipairs(candidates) do
    if type_matches(child, opts.types) and text_matches(child, bufnr, opts.texts) then
      table.insert(result, child)
    end
  end
  return result
end

-- check if `node` matches opts, given its `parent` for field-name checking (names AND types AND texts)
local function node_matches(node, parent, opts, bufnr)
  if not opts then
    return true
  end
  if not type_matches(node, opts.types) then
    return false
  end
  if not text_matches(node, bufnr, opts.texts) then
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

---Evaluates the cursor chain against `bufnr` and returns the matched TSNodes.
---@param bufnr integer
---@return TSNode[]
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local nodes = cursor.root():children({ types = { "function_declaration" } }):exec(bufnr)
---for _, node in ipairs(nodes) do
---  print(node:type())
---end
---@usage ]]
function Base:exec(bufnr)
  return self._exec(bufnr)
end

---Returns the named children of every node in the cursor.
---`opts.names` filters by field name; `opts.types` filters by node type.
---Both filters are ANDed when both are specified.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():exec(bufnr)
---cursor.root():children({ types = { "function_declaration" } }):exec(bufnr)
---cursor.root():children({ names = { "parameters" }, types = { "parameter_list" } }):exec(bufnr)
---@usage ]]
function Base:children(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      for _, child in ipairs(collect_children(node, opts, bufnr)) do
        table.insert(result, child)
      end
    end
    return result
  end, prev)
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

---Keeps only nodes for which `fn` returns true.
---@param fn bufsitter.cursor.fn
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():filter(function(b, node)
---  return vim.treesitter.get_node_text(node, b):find("TODO") ~= nil
---end):exec(bufnr)
---@usage ]]
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

---Returns the parent of every node in the cursor, optionally filtered by
---`opts.types` and `opts.names`.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():parents():exec(bufnr)
---cursor.root():children():parents({ types = { "source_file" } }):exec(bufnr)
---@usage ]]
function Multi:parents(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p and node_matches(p, p:parent(), opts, bufnr) then
        table.insert(result, p)
      end
    end
    return result
  end, prev)
end

---Falls back to the previous cursor step if the current step yields no nodes.
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local fn = function(b, node) return node:type() == "identifier" end
----- use all children if filter yields nothing
---cursor.root():children():filter(fn):or_else():exec(bufnr)
---@usage ]]
function Multi:or_else()
  return make_or_else(self, new_multi)
end

---Selects the nth node. Positive indices are 1-based from the front;
---negative indices count from the end (-1 = last). 0 is an error.
---@param n integer 1-based; negative counts from end (-1 = last); 0 is an error
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():nth(2):exec(bufnr)   -- second child
---cursor.root():children():nth(-2):exec(bufnr)  -- second-to-last child
---@usage ]]
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
  end, prev)
end

---Selects the first node. Equivalent to `nth(1)`.
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children({ types = { "function_declaration" } }):first():exec(bufnr)
---@usage ]]
function Multi:first()
  return self:nth(1)
end

---Selects the last node. Equivalent to `nth(-1)`.
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children({ types = { "function_declaration" } }):last():exec(bufnr)
---@usage ]]
function Multi:last()
  return self:nth(-1)
end

---Returns the first node for which `fn` returns true.
---Equivalent to `filter(fn):first()`.
---@param fn bufsitter.cursor.fn
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():any(function(b, node)
---  return node:type() == "function_declaration"
---end):exec(bufnr)
---@usage ]]
function Multi:any(fn)
  return self:filter(fn):first()
end

---Errors if the cursor holds no nodes, or if `fn` returns false for any node.
---`msg` overrides the default error message.
---@param msg? string
---@param fn? bufsitter.cursor.fn
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root()
---  :children({ types = { "function_declaration" } })
---  :assert("no functions found"):exec(bufnr)
---@usage ]]
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

---Returns the parent of the node, optionally filtered by `opts`.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():first():parent():exec(bufnr)
---cursor.root():children():first():parent({ types = { "source_file" } }):exec(bufnr)
---@usage ]]
function Single:parent(opts)
  local prev = self
  return new_single(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p and node_matches(p, p:parent(), opts, bufnr) then
        table.insert(result, p)
      end
    end
    return result
  end, prev)
end

---Returns all siblings of the node (excluding itself), optionally filtered by `opts`.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():first():siblings():exec(bufnr)
---cursor.root():children():first():siblings({ types = { "function_declaration" } }):exec(bufnr)
---@usage ]]
function Single:siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      if p then
        for _, sib in ipairs(collect_children(p, opts, bufnr)) do
          if sib ~= node then
            table.insert(result, sib)
          end
        end
      end
    end
    return result
  end)
end

---Returns all named siblings that appear after the node in source order,
---optionally filtered by `opts`.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():first():next_siblings():exec(bufnr)
---cursor.root():children():first():next_siblings({ types = { "comment" } }):exec(bufnr)
---@usage ]]
function Single:next_siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      local sib = node:next_named_sibling()
      while sib ~= nil do
        if node_matches(sib, p, opts, bufnr) then
          table.insert(result, sib)
        end
        sib = sib:next_named_sibling()
      end
    end
    return result
  end)
end

---Returns all named siblings that appear before the node in source order,
---optionally filtered by `opts`.
---@param opts? bufsitter.cursor.opts
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():last():prev_siblings():exec(bufnr)
---cursor.root():children():last():prev_siblings({ types = { "comment" } }):exec(bufnr)
---@usage ]]
function Single:prev_siblings(opts)
  local prev = self
  return new_multi(function(bufnr)
    local result = {}
    for _, node in ipairs(prev._exec(bufnr)) do
      local p = node:parent()
      local sib = node:prev_named_sibling()
      while sib ~= nil do
        if node_matches(sib, p, opts, bufnr) then
          table.insert(result, sib)
        end
        sib = sib:prev_named_sibling()
      end
    end
    return result
  end)
end

---Falls back to the previous cursor step if the current step yields no node.
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local fn = function(b, node) return node:type() == "identifier" end
----- fall back to any child if filter finds nothing
---cursor.root():children():filter(fn):first():or_else():exec(bufnr)
---@usage ]]
function Single:or_else()
  return make_or_else(self, new_single)
end

---Errors if the cursor holds no node, or if `fn` returns false for the node.
---`msg` overrides the default error message.
---@param msg? string
---@param fn? bufsitter.cursor.fn
---@return bufsitter.SingleCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---cursor.root():children():first():assert("expected a child"):exec(bufnr)
---@usage ]]
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

---Returns a cursor seeded with the root node of the buffer's syntax tree.
---@return bufsitter.MultiCursor
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local nodes = cursor.root():children():exec(bufnr)
---@usage ]]
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

---Returns a cursor seeded with all nodes captured by the given treesitter
---query string, evaluated against the buffer's filetype.
---@param query_str string
---@return bufsitter.MultiCursor
---
---@usage [[
---local cursor = require("bufsitter.cursor")
---local bufnr = vim.api.nvim_get_current_buf()
---local nodes = cursor.query("(function_declaration) @fn"):exec(bufnr)
---@usage ]]
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
