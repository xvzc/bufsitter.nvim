local config = require("bufsitter")

describe("config", function()
  before_each(function()
    config.setup()
  end)

  describe("setup", function()
    describe("defaults", function()
      it("should set scratch.ft to markdown", function()
        assert.are.same("markdown", config.config.scratch.ft)
      end)

      it("should set scratch.init_contents as a table", function()
        assert.are.same("table", type(config.config.scratch.init_contents))
      end)

      it("should set scratch.on_attach to nil", function()
        assert.are.same(nil, config.config.scratch.on_attach)
      end)

      it("should set default win options", function()
        local win = config.config.scratch.win
        assert.are.same("editor", win.relative)
        assert.are.same(0.6, win.width)
        assert.are.same(0.4, win.height)
        assert.is_nil(win.row)
        assert.is_nil(win.col)
        assert.are.same("minimal", win.style)
        assert.are.same("rounded", win.border)
      end)

      it("should set default io options", function()
        local io = config.config.io
        assert.is_nil(io.on_error)
      end)

      it("should set default ref options", function()
        assert.is_false(config.config.ref.expand)
      end)
    end)

    describe("user opts", function()
      it("should override scratch.ft", function()
        config.setup({ scratch = { ft = "lua" } })
        assert.are.same("lua", config.config.scratch.ft)
      end)

      it("should deep merge scratch.win", function()
        config.setup({ scratch = { win = { width = 100 } } })
        local win = config.config.scratch.win
        assert.are.same(100, win.width)
        assert.are.same(0.4, win.height)
        assert.are.same("rounded", win.border)
      end)

      it("should override io options", function()
        config.setup({ io = { prepend = true, start_line = 3 } })
        assert.is_true(config.config.io.prepend)
        assert.are.same(3, config.config.io.start_line)
        assert.is_nil(config.config.io.end_line)
      end)

      it("should override ref options", function()
        config.setup({ ref = { expand = true } })
        assert.is_true(config.config.ref.expand)
      end)
    end)
  end)
end)
