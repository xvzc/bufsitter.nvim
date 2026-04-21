local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local h = require("tests.helpers")

local SAMPLE = "tests/filetypes/typst/sample.typ"

describe("ft.typst", function()
  local bufnr

  before_each(function()
    bufnr = h.buf_from_file(SAMPLE)
  end)

  after_each(h.clean_bufs)

  local function heading_text(text)
    return function(b, node)
      local raw = vim.treesitter.get_node_text(node, b)
      return vim.trim(raw:gsub("^=+%s*", "")) == text
    end
  end

  local function heading_level(level)
    return function(b, node)
      for i = 0, node:child_count() - 1 do
        local t = node:child(i):type()
        if t:match("^=+$") and #t == level then
          return true
        end
      end
      return false
    end
  end

  local function section_with(match)
    return function(b, node)
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        if child:type() == "heading" and match(b, child) then
          return true
        end
      end
      return false
    end
  end

  describe("section navigation", function()
    it("document has 3 top-level sections", function()
      local items = cursor.root():children():exec(bufnr)
      assert.are.same(3, #items)
    end)

    it("finds Installation section by heading text", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("section", actual)
    end)

    it("finds Configuration section (last)", function()
      local items = cursor.root():children():last():exec(bufnr)
      assert.are.same(true, #items > 0)
      local heading = nil
      for i = 0, items[1]:named_child_count() - 1 do
        if items[1]:named_child(i):type() == "heading" then
          heading = items[1]:named_child(i)
          break
        end
      end
      local actual = vim.treesitter.get_node_text(heading, bufnr)
      assert.are.same(true, actual:find("Configuration") ~= nil)
    end)

    it("navigates to next section from Installation", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :next_siblings({ types = { "section" } })
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = vim.treesitter.get_node_text(items[1]:named_child(0), bufnr)
      assert.are.same(true, actual:find("Usage") ~= nil)
    end)

    it("navigates to prev section from Configuration", function()
      local items = cursor
        .root()
        :children()
        :last()
        :prev_siblings({ types = { "section" } })
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = vim.treesitter.get_node_text(items[1]:named_child(0), bufnr)
      assert.are.same(true, actual:find("Usage") ~= nil)
    end)
  end)

  describe("heading navigation", function()
    it("finds heading inside Installation section", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children({ types = { "heading" } })
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("heading", actual)
    end)

    it("finds level-1 heading in Installation", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children()
        :filter(heading_level(1))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
    end)

    it("finds level-2 heading (Basic Setup) inside Installation", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children({ types = { "content" } })
        :first()
        :children({ types = { "section" } })
        :first()
        :children()
        :filter(heading_level(2))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = vim.treesitter.get_node_text(items[1], bufnr)
      assert.are.same(true, actual:find("Basic Setup") ~= nil)
    end)
  end)

  describe("io integration", function()
    it("io.select returns content of Installation section", function()
      local results = io.select(bufnr, {
        cursor = cursor
          .root()
          :children()
          :filter(section_with(heading_text("Installation")))
          :first(),
      })
      assert.are.same(true, results ~= nil and #results > 0)
      assert.are.same(true, results[1][1]:find("Installation") ~= nil)
    end)

    it("io.insert appends after Installation without touching Usage", function()
      io.insert(bufnr, { "// injected" }, {
        cursor = cursor
          .root()
          :children()
          :filter(section_with(heading_text("Installation")))
          :first(),
      })
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local injected_row, usage_row
      for i, l in ipairs(lines) do
        if l == "// injected" then
          injected_row = i - 1
        end
        if l == "= Usage" then
          usage_row = i - 1
        end
      end
      assert.are.same(true, injected_row ~= nil)
      assert.are.same(true, injected_row < usage_row)
    end)

    it("io.delete removes Installation section, Usage remains", function()
      io.delete(bufnr, {
        cursor = cursor
          .root()
          :children()
          :filter(section_with(heading_text("Installation")))
          :first(),
      })
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_installation, has_usage = false, false
      for _, l in ipairs(lines) do
        if l == "= Installation" then
          has_installation = true
        end
        if l == "= Usage" then
          has_usage = true
        end
      end
      assert.are.same(false, has_installation)
      assert.are.same(true, has_usage)
    end)
  end)
end)
