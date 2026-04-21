local ref = require("bufsitter.ref")

describe("ref", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.fn.setpos("'<", { 0, 0, 0, 0 })
    vim.fn.setpos("'>", { 0, 0, 0, 0 })
  end)

  after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  -- helper: set buffer name and return the resolved name (handles macOS /var -> /private/var symlink)
  local function set_buf_name(tmp)
    vim.api.nvim_buf_set_name(bufnr, tmp)
    return vim.api.nvim_buf_get_name(bufnr)
  end

  describe("buffer_ref", function()
    it("should return [No Name] when buffer has no name", function()
      assert.are.same("[No Name]", ref.buffer())
    end)

    it("should return home-relative path by default", function()
      local name = set_buf_name(vim.fn.tempname())
      local expected = vim.fn.fnamemodify(name, ":~")

      assert.are.same(expected, ref.buffer())
    end)

    it("should return home-relative path when expand=false", function()
      local name = set_buf_name(vim.fn.tempname())
      local expected = vim.fn.fnamemodify(name, ":~")

      assert.are.same(expected, ref.buffer({ expand = false }))
    end)

    it("should return absolute path when expand=true", function()
      local name = set_buf_name(vim.fn.tempname())
      local expected = vim.fn.fnamemodify(name, ":p")

      assert.are.same(expected, ref.buffer({ expand = true }))
    end)
  end)

  describe("get", function()
    local original_get_mode

    before_each(function()
      original_get_mode = vim.api.nvim_get_mode
    end)

    after_each(function()
      vim.api.nvim_get_mode = original_get_mode
    end)

    it("should call buffer() in normal mode", function()
      vim.api.nvim_get_mode = function()
        return { mode = "n" }
      end
      local name = set_buf_name(vim.fn.tempname())
      assert.are.same(vim.fn.fnamemodify(name, ":~"), ref.get())
    end)

    it("should call visual_selection() in v mode", function()
      vim.api.nvim_get_mode = function()
        return { mode = "v" }
      end
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":~")
      vim.fn.setpos("'<", { 0, 3, 1, 0 })
      vim.fn.setpos("'>", { 0, 5, 1, 0 })
      assert.are.same(buf_name .. ":L3~L5", ref.get())
    end)

    it("should call visual_selection() in V mode", function()
      vim.api.nvim_get_mode = function()
        return { mode = "V" }
      end
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":~")
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 1, 1, 0 })
      assert.are.same(buf_name .. ":L1", ref.get())
    end)
  end)

  describe("visual_selection_ref", function()
    it("should return just buf_name when no visual selection (unnamed)", function()
      assert.are.same("[No Name]", ref.visual_selection())
    end)

    it("should return just buf_name when no visual selection (named)", function()
      local name = set_buf_name(vim.fn.tempname())
      local expected = vim.fn.fnamemodify(name, ":~")

      assert.are.same(expected, ref.visual_selection())
    end)

    it("should return single line ref for same-line selection", function()
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":~")
      vim.fn.setpos("'<", { 0, 5, 1, 0 })
      vim.fn.setpos("'>", { 0, 5, 10, 0 })

      assert.are.same(buf_name .. ":L5", ref.visual_selection())
    end)

    it("should return range ref for multi-line selection", function()
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":~")
      vim.fn.setpos("'<", { 0, 3, 1, 0 })
      vim.fn.setpos("'>", { 0, 7, 1, 0 })

      assert.are.same(buf_name .. ":L3~L7", ref.visual_selection())
    end)

    it("should use home-relative path by default", function()
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":~")
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 2, 1, 0 })

      assert.are.same(buf_name .. ":L1~L2", ref.visual_selection())
    end)

    it("should use absolute path when expand=true", function()
      local name = set_buf_name(vim.fn.tempname())
      local buf_name = vim.fn.fnamemodify(name, ":p")
      vim.fn.setpos("'<", { 0, 1, 1, 0 })
      vim.fn.setpos("'>", { 0, 3, 1, 0 })

      assert.are.same(buf_name .. ":L1~L3", ref.visual_selection({ expand = true }))
    end)
  end)
end)
