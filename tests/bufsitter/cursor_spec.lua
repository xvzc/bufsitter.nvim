local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local h = require("tests.helpers")

describe("cursor", function()
  after_each(h.clean_bufs)

  describe("root()", function()
    it("should be callable", function()
      assert.are.same(true, vim.is_callable(cursor.root()))
    end)

    it("should return empty when parser fails", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local items = cursor.root()(bufnr)
      assert.are.same(0, #items)
    end)

    it("should return root node and full range", function()
      local bufnr = h.make_buf({ "# Title", "content" }, "markdown")
      local expected_root = h.get_root(bufnr)
      local items = cursor.root()(bufnr)
      assert.are.same(1, #items)
      assert.are.same(expected_root, items[1].node)
      assert.are.same({ sr = 0, sc = 0, er = 2, ec = 0 }, items[1].range)
    end)
  end)

  describe("query()", function()
    it("should return a Cursor", function()
      assert.are.same(true, vim.is_callable(cursor.query("(section) @node")))
    end)

    it("should return all matching nodes", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.query("(section) @node")(bufnr)
      assert.are.same(3, #items)
    end)

    it("should return empty when query matches nothing", function()
      local bufnr = h.make_buf({ "just text" }, "markdown")
      local items = cursor.query("(fenced_code_block) @node")(bufnr)
      assert.are.same(0, #items)
    end)

    it("should return empty when parser fails", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local items = cursor.query("(section) @node")(bufnr)
      assert.are.same(0, #items)
    end)

    it("should error on invalid query", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      assert.has_error(function()
        cursor.query("this is not valid")(bufnr)
      end)
    end)

    it("chains into cursor methods", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor.query("(section) @node"):first()(bufnr)
      assert.are.same(1, #items)
      assert.are.same("section", items[1].node:type())
    end)
  end)

  describe("children()", function()
    it("should return a Cursor", function()
      assert.are.same(true, vim.is_callable(cursor.root():children()))
    end)

    it("should return all named children", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children()(bufnr)
      assert.are.same(3, #items)
    end)

    it("should return empty list when no children", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local items = cursor.root():children()(bufnr)
      assert.are.same(0, #items)
    end)

    it("filters by type", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor.root():children({ types = { "section" } })(bufnr)
      assert.are.same(2, #items)
      for _, item in ipairs(items) do
        assert.are.same("section", item.node:type())
      end
    end)

    it("filters by multiple types (OR)", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items =
        cursor.root():children({ types = { "section", "atx_heading" } })(bufnr)
      assert.are.same(true, #items >= 2)
    end)

    it("returns empty when type filter matches nothing", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor.root():children({ types = { "fenced_code_block" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("filters by field name", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ names = { "nonexistent" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("returns empty when field does not exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local items = cursor.root():first():children({ names = { "name" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("type and name opts are AND", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      -- atx_heading exists as a child, but not in a field named "body"
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ names = { "body" }, types = { "atx_heading" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("chains: children({types}):first():children({types})", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ types = { "atx_heading" } })(bufnr)
      assert.are.same(1, #items)
      assert.are.same("atx_heading", items[1].node:type())
    end)

    it("stops chain when first() returns empty", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "nonexistent" } })
        :first()
        :children({ types = { "atx_heading" } })(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("parent()", function()
    it("should return parent node", function()
      local bufnr = h.make_buf({ "# Title", "content" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ types = { "atx_heading" } })
        :first()
        :parent()(bufnr)
      assert.are.same(1, #items)
      assert.are.same("section", items[1].node:type())
    end)

    it("should filter parent by type", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ types = { "atx_heading" } })
        :first()
        :parent({ types = { "section" } })(bufnr)
      assert.are.same(1, #items)
    end)

    it("should return empty when parent type does not match", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :first()
        :children({ types = { "atx_heading" } })
        :first()
        :parent({ types = { "document" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("should return empty when node has no parent", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor.root():first():parent()(bufnr)
      assert.are.same(0, #items)
    end)

    it("or_else() falls back to node when parent is empty", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items =
        cursor.root():first():parent({ types = { "nonexistent" } }):or_else()(bufnr)
      assert.are.same(1, #items)
      assert.are.same("document", items[1].node:type())
    end)
  end)

  describe("parents()", function()
    it("collects immediate parents of all nodes", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :children({ types = { "atx_heading" } })
        :parents()(bufnr)
      assert.are.same(2, #items)
      for _, item in ipairs(items) do
        assert.are.same("section", item.node:type())
      end
    end)

    it("filters parents by type", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :children({ types = { "atx_heading" } })
        :parents({ types = { "document" } })(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("siblings()", function()
    it("should return a Cursor", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      assert.are.same(
        true,
        vim.is_callable(
          cursor.root():children({ types = { "section" } }):first():siblings()
        )
      )
    end)

    it("should return all siblings excluding self", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items =
        cursor.root():children({ types = { "section" } }):first():siblings()(bufnr)
      assert.are.same(2, #items)
    end)

    it("should return empty when no siblings", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items =
        cursor.root():children({ types = { "section" } }):first():siblings()(bufnr)
      assert.are.same(0, #items)
    end)

    it("should return empty when node has no parent", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor.root():first():siblings()(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("next_siblings()", function()
    it("should return a Cursor", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      assert.are.same(
        true,
        vim.is_callable(cursor.root():children():first():next_siblings())
      )
    end)

    it("should return all next siblings", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():first():next_siblings()(bufnr)
      assert.are.same(2, #items)
    end)

    it("filters by type", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor
        .root()
        :children()
        :first()
        :next_siblings({ types = { "section" } })
        :first()(bufnr)
      assert.are.same(1, #items)
    end)

    it("should return empty when no next siblings exist", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():last():next_siblings()(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("prev_siblings()", function()
    it("should return a Cursor", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      assert.are.same(
        true,
        vim.is_callable(cursor.root():children():last():prev_siblings())
      )
    end)

    it("should return all prev siblings", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():last():prev_siblings()(bufnr)
      assert.are.same(2, #items)
    end)

    it("filters by type", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor
        .root()
        :children()
        :last()
        :prev_siblings({ types = { "section" } })
        :first()(bufnr)
      assert.are.same(1, #items)
    end)

    it("should return empty when no prev siblings exist", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():first():prev_siblings()(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("or_else()", function()
    it("falls back when filter returns empty", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor
        .root()
        :children()
        :filter(function()
          return false
        end)
        :or_else()(bufnr)
      assert.are.same(3, #items)
    end)

    it("does not fall back when filter has results", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor
        .root()
        :children()
        :filter(function(_, n)
          return n:type() == "section"
        end)
        :or_else()(bufnr)
      assert.are.same(3, #items)
    end)

    it("double or_else is no-op", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local base = cursor.root():children():filter(function()
        return false
      end)
      local once = base:or_else()(bufnr)
      local twice = base:or_else():or_else()(bufnr)
      assert.are.same(#once, #twice)
    end)
  end)

  describe("flatMap traversal", function()
    it("children() collects children from all nodes", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")
      local items = cursor.root():children():children()(bufnr)
      assert.are.same(true, #items >= 4)
    end)

    it("children({types}) filters across all nodes", function()
      local bufnr = h.make_buf({ "# A", "para a", "# B", "para b" }, "markdown")
      local items =
        cursor.root():children():children({ types = { "atx_heading" } })(bufnr)
      assert.are.same(2, #items)
      for _, item in ipairs(items) do
        assert.are.same("atx_heading", item.node:type())
      end
    end)

    it("parents() collects parents of all nodes", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :children({ types = { "atx_heading" } })
        :parents()(bufnr)
      assert.are.same(2, #items)
      for _, item in ipairs(items) do
        assert.are.same("section", item.node:type())
      end
    end)

    it("parents() with type filter skips non-matching parents", function()
      local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :children({ types = { "atx_heading" } })
        :parents({ types = { "document" } })(bufnr)
      assert.are.same(0, #items)
    end)

    it("deep chain: children({types}):children({types})", function()
      local bufnr = h.make_buf({ "# A", "para a", "# B", "para b" }, "markdown")
      local items = cursor
        .root()
        :children({ types = { "section" } })
        :children({ types = { "paragraph" } })(bufnr)
      assert.are.same(2, #items)
    end)
  end)

  describe("filter()", function()
    it("should filter items", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local count = 0
      local items = cursor
        .root()
        :children()
        :filter(function(b, n)
          count = count + 1
          return count <= 2
        end)(bufnr)
      assert.are.same(2, #items)
    end)

    it("should return empty when nothing matches", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local items = cursor
        .root()
        :children()
        :filter(function()
          return false
        end)(bufnr)
      assert.are.same(0, #items)
    end)
  end)

  describe("nth()", function()
    it("should return nth item (1-based)", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():nth(2)(bufnr)
      assert.are.same(1, #items)
      assert.are.same(h.get_root(bufnr):named_child(1), items[1].node)
    end)

    it("should support negative index (-1 = last)", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():nth(-1)(bufnr)
      local root = h.get_root(bufnr)
      assert.are.same(root:named_child(2), items[1].node)
    end)

    it("should return empty when index out of range", function()
      local bufnr = h.make_buf({ "# A" }, "markdown")
      local items = cursor.root():children():nth(5)(bufnr)
      assert.are.same(0, #items)
    end)

    it("should error on index 0", function()
      assert.has_error(function()
        cursor.root():children():nth(0)
      end)
    end)
  end)

  describe("first() / last()", function()
    it("first() returns first item", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():first()(bufnr)
      assert.are.same(1, #items)
      assert.are.same(h.get_root(bufnr):named_child(0), items[1].node)
    end)

    it("last() returns last item", function()
      local bufnr = h.make_buf({ "# A", "# B", "# C" }, "markdown")
      local items = cursor.root():children():last()(bufnr)
      local root = h.get_root(bufnr)
      assert.are.same(root:named_child(root:named_child_count() - 1), items[1].node)
    end)
  end)

  describe("assert()", function()
    describe("Multi:assert()", function()
      it("passes through nodes when non-empty", function()
        local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
        local items = cursor.root():children():assert()(bufnr)
        assert.are.same(2, #items)
      end)

      it("errors with default message when empty", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        assert.has_error(function()
          cursor.root():children({ types = { "nonexistent" } }):assert()(bufnr)
        end)
      end)

      it("errors with custom message when empty", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        local ok, err = pcall(function()
          cursor
            .root()
            :children({ types = { "nonexistent" } })
            :assert("missing node")(bufnr)
        end)
        assert.are.same(false, ok)
        assert.are.same(true, err:find("missing node") ~= nil)
      end)

      it("errors when fn returns false for a node", function()
        local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
        assert.has_error(function()
          cursor
            .root()
            :children()
            :assert("wrong type", function(_, node)
              return node:type() == "atx_heading"
            end)(bufnr)
        end)
      end)

      it("passes when fn returns true for all nodes", function()
        local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
        local items = cursor
          .root()
          :children()
          :assert("must be section", function(_, node)
            return node:type() == "section"
          end)(bufnr)
        assert.are.same(2, #items)
      end)

      it("errors when empty even if fn is provided", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        assert.has_error(function()
          cursor
            .root()
            :children({ types = { "nonexistent" } })
            :assert("boom", function()
              return true
            end)(bufnr)
        end)
      end)

      it("is chainable", function()
        local bufnr = h.make_buf({ "# A", "# B" }, "markdown")
        local items = cursor.root():children():assert():first()(bufnr)
        assert.are.same(1, #items)
      end)
    end)

    describe("Single:assert()", function()
      it("passes through node when present", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        local items = cursor.root():children():first():assert()(bufnr)
        assert.are.same(1, #items)
      end)

      it("errors with default message when empty", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        assert.has_error(function()
          cursor.root():children({ types = { "nonexistent" } }):first():assert()(bufnr)
        end)
      end)

      it("errors with custom message when empty", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        local ok, err = pcall(function()
          cursor
            .root()
            :children({ types = { "nonexistent" } })
            :first()
            :assert("not found")(bufnr)
        end)
        assert.are.same(false, ok)
        assert.are.same(true, err:find("not found") ~= nil)
      end)

      it("errors when fn returns false", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        assert.has_error(function()
          cursor
            .root()
            :children()
            :first()
            :assert("wrong type", function(_, node)
              return node:type() == "atx_heading"
            end)(bufnr)
        end)
      end)

      it("passes when fn returns true", function()
        local bufnr = h.make_buf({ "# Title" }, "markdown")
        local items = cursor
          .root()
          :children()
          :first()
          :assert("must be section", function(_, node)
            return node:type() == "section"
          end)(bufnr)
        assert.are.same(1, #items)
      end)

      it("is chainable", function()
        local bufnr = h.make_buf({ "# Title", "content" }, "markdown")
        local items = cursor.root():children():first():assert():children()(bufnr)
        assert.are.same(true, #items > 0)
      end)
    end)
  end)

  describe("io integration", function()
    it("io.insert: appends after matched section", function()
      local bufnr = h.make_buf({ "# Context", "content", "# Other", "more" }, "markdown")

      local function is_context(b, n)
        for i = 0, n:named_child_count() - 1 do
          local child = n:named_child(i)
          if child:type() == "atx_heading" then
            local raw = vim.treesitter.get_node_text(child, b)
            if vim.trim(raw:gsub("^#+%s*", "")) == "Context" then
              return true
            end
          end
        end
        return false
      end

      io.insert(bufnr, { "appended" }, {
        cursor = cursor.root():children():filter(is_context):first(),
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local appended_row, other_row
      for i, l in ipairs(actual) do
        if l == "appended" then
          appended_row = i - 1
        end
        if l == "# Other" then
          other_row = i - 1
        end
      end
      assert.are.same(true, appended_row ~= nil)
      assert.are.same(true, appended_row <= other_row)
    end)

    it("io.insert: inserts at all matched sections", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")

      io.insert(bufnr, { "---" }, {
        cursor = cursor.root():children(),
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local count = 0
      for _, l in ipairs(actual) do
        if l == "---" then
          count = count + 1
        end
      end
      assert.are.same(2, count)
    end)

    it("io.select: returns string[][] per matched node", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")
      local results = io.select(bufnr, {
        cursor = cursor.root():children(),
      })
      assert.are.same(true, results ~= nil and #results == 2)
    end)

    it("io.select: returns content of single matched node", function()
      local bufnr = h.make_buf({ "# A", "content" }, "markdown")
      local results = io.select(bufnr, {
        cursor = cursor.root():children({ types = { "section" } }):first(),
      })
      assert.are.same(true, results ~= nil and #results == 1)
      assert.are.same(true, results[1][1]:find("A") ~= nil)
    end)

    it("io.select_text: returns string[] per matched node", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")
      local results = io.select_text(bufnr, {
        cursor = cursor.root():children(),
      })
      assert.are.same(true, results ~= nil and #results == 2)
      for _, text in ipairs(results) do
        assert.are.same("string", type(text))
      end
    end)

    it("io.delete: deletes all matched sections", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")
      io.delete(bufnr, {
        cursor = cursor.root():children(),
      })
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_heading = false
      for _, l in ipairs(actual) do
        if l:find("^#") then
          has_heading = true
        end
      end
      assert.are.same(false, has_heading)
    end)

    it("io.delete: deletes only first matched section when using first()", function()
      local bufnr = h.make_buf({ "# A", "content", "# B" }, "markdown")
      io.delete(bufnr, {
        cursor = cursor.root():children({ types = { "section" } }):first(),
      })
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_b = false
      for _, l in ipairs(actual) do
        if l == "# B" then
          has_b = true
        end
      end
      assert.are.same(true, has_b)
    end)

    it("io.replace: replaces matched node content", function()
      local bufnr = h.make_buf({ "# Title", "old content" }, "markdown")
      io.replace(bufnr, { "replaced" }, {
        cursor = cursor.root():children({ types = { "section" } }):first(),
      })
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_replaced = false
      for _, l in ipairs(actual) do
        if l == "replaced" then
          has_replaced = true
        end
      end
      assert.are.same(true, has_replaced)
    end)

    it("io.replace: replaces all matched sections", function()
      local bufnr = h.make_buf({ "# A", "content a", "# B", "content b" }, "markdown")
      io.replace(bufnr, { "replaced" }, {
        cursor = cursor.root():children(),
      })
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local count = 0
      for _, l in ipairs(actual) do
        if l == "replaced" then
          count = count + 1
        end
      end
      assert.are.same(2, count)
    end)
  end)
end)
