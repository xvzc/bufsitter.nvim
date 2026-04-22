local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local h = require("tests.helpers")

local SAMPLE = "tests/filetypes/markdown/sample.md"

describe("ft.markdown", function()
  local bufnr

  before_each(function()
    bufnr = h.buf_from_file(SAMPLE)
  end)

  after_each(h.clean_bufs)

  local function heading_text(text)
    return function(b, node)
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        if child:type() == "inline" then
          return vim.trim(vim.treesitter.get_node_text(child, b)) == text
        end
      end
      return false
    end
  end

  local function section_with(match)
    return function(b, node)
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        if child:type() == "atx_heading" and match(b, child) then
          return true
        end
      end
      return false
    end
  end

  local function heading_level(level)
    return function(b, node)
      for i = 0, node:child_count() - 1 do
        if node:child(i):type() == ("atx_h%d_marker"):format(level) then
          return true
        end
      end
      return false
    end
  end

  local function fenced_lang(lang)
    return function(b, node)
      for i = 0, node:named_child_count() - 1 do
        local child = node:named_child(i)
        if child:type() == "info_string" then
          return vim.trim(vim.treesitter.get_node_text(child, b)) == lang
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
        if items[1]:named_child(i):type() == "atx_heading" then
          heading = items[1]:named_child(i)
          break
        end
      end
      assert.are.same(true, heading ~= nil)
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
    it("finds atx_heading inside Installation section", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children({ types = { "atx_heading" } })
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("atx_heading", actual)
    end)

    it("finds h2 heading by level inside Installation", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children({ types = { "section" } })
        :first()
        :children()
        :filter(heading_level(2))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("atx_heading", actual)
    end)
  end)

  describe("fenced_code_block navigation", function()
    it("finds lua code block in Installation section", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children()
        :filter(fenced_lang("lua"))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("fenced_code_block", actual)
    end)

    it("finds xml code block in Configuration section", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Configuration")))
        :first()
        :children()
        :filter(fenced_lang("xml"))
        :first()
        :exec(bufnr)
      assert.are.same(true, #items > 0)
    end)

    it("returns empty for nonexistent language", function()
      local items = cursor
        .root()
        :children()
        :filter(section_with(heading_text("Installation")))
        :first()
        :children()
        :filter(fenced_lang("python"))
        :first()
        :exec(bufnr)
      assert.are.same(0, #items)
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
      local before_usage_row
      local lines_before = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, l in ipairs(lines_before) do
        if l == "# Usage" then
          before_usage_row = i - 1
        end
      end

      io.insert(bufnr, { "<!-- injected -->" }, {
        cursor = cursor
          .root()
          :children()
          :filter(section_with(heading_text("Installation")))
          :first(),
      })

      local lines_after = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local injected_row, usage_row
      for i, l in ipairs(lines_after) do
        if l == "<!-- injected -->" then
          injected_row = i - 1
        end
        if l == "# Usage" then
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
        if l == "# Installation" then
          has_installation = true
        end
        if l == "# Usage" then
          has_usage = true
        end
      end
      assert.are.same(false, has_installation)
      assert.are.same(true, has_usage)
    end)
  end)

  describe("usage example", function()
    it("inserts a list item into a section matched by heading text", function()
      local input = {
        "# Shopping List",
        "",
        "- apples",
        "- oranges",
        "",
        "# Todo",
      }
      local expected = {
        "# Shopping List",
        "",
        "- apples",
        "- oranges",
        "- milk",
        "",
        "# Todo",
      }

      local example_bufnr = h.make_buf(input, "markdown")

      io.insert(example_bufnr, { "- milk" }, {
        cursor = cursor
          .root()
          :children({ types = { "section" } })
          :children({ types = { "atx_heading" } })
          :children({ names = { "heading_content" }, texts = { "Shopping List" } })
          :first()
          :parent()
          :next_siblings({ types = { "list" } })
          :last(),
      })

      local actual = vim.api.nvim_buf_get_lines(example_bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)
  end)
end)
