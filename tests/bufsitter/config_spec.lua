local config = require("bufsitter")

describe("config", function()
  before_each(function()
    config.setup()
  end)

  describe("setup", function()
    describe("defaults", function()
      it("should set scratch.ext to md", function()
        assert.are.same("md", config.config.scratch.ext)
      end)

      it("should set scratch.init_contents as a table", function()
        assert.are.same("table", type(config.config.scratch.init_contents))
      end)

      it("should set scratch.on_attach to nil", function()
        assert.are.same(nil, config.config.scratch.on_attach)
      end)

      it("should set scratch.force_quit to true", function()
        assert.is_true(config.config.scratch.force_quit)
      end)

      it("should set default win options", function()
        local win = config.config.scratch.win
        assert.are.same("editor", win.relative)
        assert.are.same(0.5, win.width)
        assert.are.same(0.7, win.height)
        assert.is_nil(win.min_width)
        assert.is_nil(win.min_height)
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
        assert.are.same(0.7, win.height)
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

      it("should set min_width and min_height in scratch.win", function()
        config.setup({ scratch = { win = { min_width = 40, min_height = 10 } } })
        local win = config.config.scratch.win
        assert.are.same(40, win.min_width)
        assert.are.same(10, win.min_height)
      end)
    end)
  end)
end)
