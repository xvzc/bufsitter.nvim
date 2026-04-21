local io = require("bufsitter.io")
local cursor = require("bufsitter.cursor")
local config = require("bufsitter")
local h = require("tests.helpers")

describe("io", function()
  after_each(h.clean_bufs)

  describe("insert", function()
    it("should insert contents with prepend=false", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line1", "line2", "added1", "added2", "line3" }

      local bufnr = h.make_buf(contents)
      io.insert(
        bufnr,
        { "added1", "added2" },
        { start_row = 1, end_row = 2, prepend = false }
      )

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("should insert contents with prepend=true", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line1", "added1", "added2", "line2", "line3" }

      local bufnr = h.make_buf(contents)
      io.insert(
        bufnr,
        { "added1", "added2" },
        { start_row = 1, end_row = 2, prepend = true }
      )

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("should do nothing when cursor returns empty", function()
      local contents = { "line1" }
      local expected = { "line1" }

      local bufnr = h.make_buf(contents)
      io.insert(bufnr, { "added" }, {
        cursor = cursor.root():children(),
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("inline=true prepend attaches at character position without newline", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line1", "[prefix]line2", "line3" }

      local bufnr = h.make_buf(contents)
      io.insert(bufnr, { "[prefix]" }, {
        start_row = 1,
        end_row = 2,
        prepend = true,
        inline = true,
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("inline=false prepend inserts as new line above", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line1", "added", "line2", "line3" }

      local bufnr = h.make_buf(contents)
      io.insert(bufnr, { "added" }, {
        start_row = 1,
        end_row = 2,
        prepend = true,
        inline = false,
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("inline=true append attaches at character position without newline", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line1", "line2[suffix]", "line3" }

      local bufnr = h.make_buf(contents)
      io.insert(bufnr, { "[suffix]" }, {
        start_row = 1,
        end_row = 1,
        end_col = #"line2",
        prepend = false,
        inline = true,
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)
  end)

  describe("select", function()
    it("should select contents in range", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { { "line2" } }

      local bufnr = h.make_buf(contents)
      local actual = io.select(bufnr, { start_row = 1, end_row = 2 })

      assert.are.same(expected, actual)
    end)

    it("should select with hook", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { { "hooked" } }

      local bufnr = h.make_buf(contents)
      local actual = io.select(bufnr, {
        start_row = 1,
        end_row = 2,
        hook = function()
          return { "hooked" }
        end,
      })

      assert.are.same(expected, actual)
    end)

    it("should return nil when cursor returns empty", function()
      local contents = { "line1", "line2", "line3" }
      local expected = nil

      local bufnr = h.make_buf(contents)
      local actual = io.select(bufnr, {
        cursor = cursor.root():children(),
      })

      assert.are.same(expected, actual)
    end)
  end)

  describe("select_text", function()
    it("should return joined strings per node", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "line2" }

      local bufnr = h.make_buf(contents)
      local actual = io.select_text(bufnr, { start_row = 1, end_row = 2 })

      assert.are.same(expected, actual)
    end)

    it("should return nil when cursor returns empty", function()
      local contents = { "line1" }

      local bufnr = h.make_buf(contents)
      local actual = io.select_text(bufnr, {
        cursor = cursor.root():children(),
      })

      assert.are.same(nil, actual)
    end)
  end)

  describe("delete", function()
    it("should delete single line", function()
      local contents = { "leave0", "delete1", "leave2", "leave3" }
      local expected = { "leave0", "leave2", "leave3" }

      local bufnr = h.make_buf(contents)
      io.delete(bufnr, { start_row = 1, end_row = 2 })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("should delete multiple lines", function()
      local contents = { "leave0", "delete1", "delete2", "delete3", "leave4", "leave5" }
      local expected = { "leave0", "leave4", "leave5" }

      local bufnr = h.make_buf(contents)
      io.delete(bufnr, { start_row = 1, end_row = 4 })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("should do nothing when cursor returns empty", function()
      local contents = { "line1", "line2" }
      local expected = { "line1", "line2" }

      local bufnr = h.make_buf(contents)
      io.delete(bufnr, {
        cursor = cursor.root():children(),
      })

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)
  end)

  describe("on_error", function()
    after_each(function()
      config.setup({})
    end)

    it("per-call on_error catches assert error from cursor", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local captured
      io.select(bufnr, {
        cursor = cursor.root():children({ types = { "nonexistent" } }):assert("boom"),
        on_error = function(err)
          captured = err
        end,
      })
      assert.are.same(true, captured ~= nil)
      assert.are.same(true, captured:find("boom") ~= nil)
    end)

    it("per-call on_error: no error when cursor succeeds", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local captured
      local results = io.select(bufnr, {
        cursor = cursor.root():children():first():assert(),
        on_error = function(err)
          captured = err
        end,
      })
      assert.are.same(nil, captured)
      assert.are.same(true, results ~= nil)
    end)

    it("global config.io.on_error catches assert error", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local captured
      config.setup({
        io = {
          on_error = function(err)
            captured = err
          end,
        },
      })
      io.delete(bufnr, {
        cursor = cursor
          .root()
          :children({ types = { "nonexistent" } })
          :assert("global boom"),
      })
      assert.are.same(true, captured ~= nil)
      assert.are.same(true, captured:find("global boom") ~= nil)
    end)

    it("per-call on_error overrides global", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      local global_captured, local_captured
      config.setup({
        io = {
          on_error = function(err)
            global_captured = err
          end,
        },
      })
      io.insert(bufnr, { "x" }, {
        cursor = cursor.root():children({ types = { "nonexistent" } }):assert("local"),
        on_error = function(err)
          local_captured = err
        end,
      })
      assert.are.same(nil, global_captured)
      assert.are.same(true, local_captured ~= nil)
      assert.are.same(true, local_captured:find("local") ~= nil)
    end)

    it("without on_error, assert error propagates as lua error", function()
      local bufnr = h.make_buf({ "# Title" }, "markdown")
      assert.has_error(function()
        io.select(bufnr, {
          cursor = cursor
            .root()
            :children({ types = { "nonexistent" } })
            :assert("raw error"),
        })
      end)
    end)
  end)

  describe("clear", function()
    it("should clear contents", function()
      local contents = { "line1", "line2", "line3" }
      local expected = { "" }

      local bufnr = h.make_buf(contents)
      io.clear(bufnr)

      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)
  end)
end)
