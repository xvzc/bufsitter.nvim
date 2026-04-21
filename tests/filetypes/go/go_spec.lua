local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local h = require("tests.helpers")

local SAMPLE = "tests/filetypes/go/sample.go"

local ts_parser = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/parser/go.so"
if vim.fn.filereadable(ts_parser) == 0 then
  return
end
vim.treesitter.language.add("go", { path = ts_parser })

describe("ft.go", function()
  local bufnr

  before_each(function()
    bufnr = h.buf_from_file(SAMPLE)
  end)

  after_each(h.clean_bufs)

  local function func_named(name)
    return function(b, node)
      if node:type() ~= "function_declaration" then
        return false
      end
      local n = node:field("name")[1]
      return n and vim.treesitter.get_node_text(n, b) == name
    end
  end

  local function type_named(name)
    return function(b, node)
      if node:type() ~= "type_declaration" then
        return false
      end
      for i = 0, node:named_child_count() - 1 do
        local spec = node:named_child(i)
        local n = spec:field("name")[1]
        if n and vim.treesitter.get_node_text(n, b) == name then
          return true
        end
      end
      return false
    end
  end

  describe("function_declaration", function()
    it("finds NewUserProfile by name", function()
      local items =
        cursor.root():children():filter(func_named("NewUserProfile")):first()(bufnr)
      assert.are.same(true, #items > 0)
      assert.are.same("function_declaration", items[1].node:type())
    end)

    it("gets name field of NewUserProfile", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "name" } })(bufnr)
      assert.are.same(
        "NewUserProfile",
        vim.treesitter.get_node_text(items[1].node, bufnr)
      )
    end)

    it("gets parameters field", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "parameters" } })(bufnr)
      assert.are.same("parameter_list", items[1].node:type())
    end)

    it("gets parameter name 'name'", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "parameters" } })
        :first()
        :children()
        :first()
        :children({ names = { "name" } })(bufnr)
      assert.are.same("name", vim.treesitter.get_node_text(items[1].node, bufnr))
    end)

    it("gets result field (return type)", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "result" } })(bufnr)
      assert.are.same(true, #items > 0)
      local text = vim.treesitter.get_node_text(items[1].node, bufnr)
      assert.are.same(true, text:find("UserProfile") ~= nil)
    end)
  end)

  describe("type_declaration", function()
    it("finds Metadata type by name", function()
      local items = cursor.root():children():filter(type_named("Metadata")):first()(bufnr)
      assert.are.same(true, #items > 0)
    end)

    it("finds UserProfile type by name", function()
      local items =
        cursor.root():children():filter(type_named("UserProfile")):first()(bufnr)
      assert.are.same(true, #items > 0)
    end)

    it("Metadata struct has 4 fields", function()
      local items = cursor
        .root()
        :children()
        :filter(type_named("Metadata"))
        :first()
        :children({ types = { "type_spec" } })
        :first()
        :children({ names = { "type" } })
        :first()
        :children({ types = { "field_declaration_list" } })
        :first()
        :children()
        :filter(function(b, n)
          return n:type() == "field_declaration"
        end)(bufnr)
      assert.are.same(4, #items)
    end)

    it("finds ID field in Metadata by name", function()
      local items = cursor
        .root()
        :children()
        :filter(type_named("Metadata"))
        :first()
        :children({ types = { "type_spec" } })
        :first()
        :children({ names = { "type" } })
        :first()
        :children({ types = { "field_declaration_list" } })
        :first()
        :children()
        :filter(function(b, n)
          if n:type() ~= "field_declaration" then
            return false
          end
          local name = n:field("name")[1]
          return name and vim.treesitter.get_node_text(name, b) == "ID"
        end)
        :first()
        :children({ names = { "name" } })(bufnr)
      assert.are.same("ID", vim.treesitter.get_node_text(items[1].node, bufnr))
    end)
  end)

  describe("io integration", function()
    it("io.select returns exact lines of Metadata type_declaration", function()
      local results = io.select(bufnr, {
        cursor = cursor.root():children():filter(type_named("Metadata")):first(),
      })
      assert.are.same({
        "type Metadata struct {",
        '    ID        int64     `json:"id" check:"required"`',
        '    CreatedAt time.Time `json:"created_at"`',
        '    IsActive  bool      `json:"is_active"`',
        '    Version   string    `json:"version"`',
        "}",
      }, results[1])
    end)

    it("io.select returns exact lines of NewUserProfile function_declaration", function()
      local results = io.select(bufnr, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      assert.are.same({
        "func NewUserProfile(name string) *UserProfile {",
        "    return &UserProfile{",
        "        Username: &name,",
        '        Roles:    []string{"user", "guest"},',
        "        Settings: make(map[string]string),",
        "    }",
        "}",
      }, results[1])
    end)

    it("io.delete removes Metadata type_declaration", function()
      io.delete(bufnr, {
        cursor = cursor.root():children():filter(type_named("Metadata")):first(),
      })
      assert.are.same({
        "package main",
        "",
        'import "time"',
        "",
        "// Metadata demonstrates struct tags and basic types",
        "",
        "",
        "// UserProfile includes nested structs, pointers, and collections",
        "type UserProfile struct {",
        "    // 1. Embedded Struct (Named node: field_declaration)",
        "    Metadata",
        "",
        "    // 2. Basic pointers and strings",
        '    Username *string `json:"username"`',
        '    Email    string  `json:"email"`',
        "    ",
        "    // 3. Collections: Slices and Maps",
        '    Roles    []string          `json:"roles"`',
        '    Settings map[string]string `json:"settings"`',
        "",
        "    // 4. Nested Anonymous Struct",
        "    Address struct {",
        '        City    string `json:"city"`',
        '        ZipCode int    `json:"zip_code"`',
        '    } `json:"address"`',
        "",
        "    // 5. Interface member (for polymorphism tests)",
        '    Permissions any `json:"permissions"`',
        "    ",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "func NewUserProfile(name string) *UserProfile {",
        "    return &UserProfile{",
        "        Username: &name,",
        '        Roles:    []string{"user", "guest"},',
        "        Settings: make(map[string]string),",
        "    }",
        "}",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("io.delete removes NewUserProfile function_declaration", function()
      io.delete(bufnr, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      assert.are.same({
        "package main",
        "",
        'import "time"',
        "",
        "// Metadata demonstrates struct tags and basic types",
        "type Metadata struct {",
        '    ID        int64     `json:"id" check:"required"`',
        '    CreatedAt time.Time `json:"created_at"`',
        '    IsActive  bool      `json:"is_active"`',
        '    Version   string    `json:"version"`',
        "}",
        "",
        "// UserProfile includes nested structs, pointers, and collections",
        "type UserProfile struct {",
        "    // 1. Embedded Struct (Named node: field_declaration)",
        "    Metadata",
        "",
        "    // 2. Basic pointers and strings",
        '    Username *string `json:"username"`',
        '    Email    string  `json:"email"`',
        "    ",
        "    // 3. Collections: Slices and Maps",
        '    Roles    []string          `json:"roles"`',
        '    Settings map[string]string `json:"settings"`',
        "",
        "    // 4. Nested Anonymous Struct",
        "    Address struct {",
        '        City    string `json:"city"`',
        '        ZipCode int    `json:"zip_code"`',
        '    } `json:"address"`',
        "",
        "    // 5. Interface member (for polymorphism tests)",
        '    Permissions any `json:"permissions"`',
        "    ",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("io.insert prepends before NewUserProfile function_declaration", function()
      io.insert(bufnr, { "// generated function" }, {
        prepend = true,
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      assert.are.same({
        "package main",
        "",
        'import "time"',
        "",
        "// Metadata demonstrates struct tags and basic types",
        "type Metadata struct {",
        '    ID        int64     `json:"id" check:"required"`',
        '    CreatedAt time.Time `json:"created_at"`',
        '    IsActive  bool      `json:"is_active"`',
        '    Version   string    `json:"version"`',
        "}",
        "",
        "// UserProfile includes nested structs, pointers, and collections",
        "type UserProfile struct {",
        "    // 1. Embedded Struct (Named node: field_declaration)",
        "    Metadata",
        "",
        "    // 2. Basic pointers and strings",
        '    Username *string `json:"username"`',
        '    Email    string  `json:"email"`',
        "    ",
        "    // 3. Collections: Slices and Maps",
        '    Roles    []string          `json:"roles"`',
        '    Settings map[string]string `json:"settings"`',
        "",
        "    // 4. Nested Anonymous Struct",
        "    Address struct {",
        '        City    string `json:"city"`',
        '        ZipCode int    `json:"zip_code"`',
        '    } `json:"address"`',
        "",
        "    // 5. Interface member (for polymorphism tests)",
        '    Permissions any `json:"permissions"`',
        "    ",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "// generated function",
        "func NewUserProfile(name string) *UserProfile {",
        "    return &UserProfile{",
        "        Username: &name,",
        '        Roles:    []string{"user", "guest"},',
        "        Settings: make(map[string]string),",
        "    }",
        "}",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("io.replace swaps NewUserProfile implementation", function()
      io.replace(bufnr, {
        "func NewUserProfile() *UserProfile {",
        "    return nil",
        "}",
      }, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      assert.are.same({
        "package main",
        "",
        'import "time"',
        "",
        "// Metadata demonstrates struct tags and basic types",
        "type Metadata struct {",
        '    ID        int64     `json:"id" check:"required"`',
        '    CreatedAt time.Time `json:"created_at"`',
        '    IsActive  bool      `json:"is_active"`',
        '    Version   string    `json:"version"`',
        "}",
        "",
        "// UserProfile includes nested structs, pointers, and collections",
        "type UserProfile struct {",
        "    // 1. Embedded Struct (Named node: field_declaration)",
        "    Metadata",
        "",
        "    // 2. Basic pointers and strings",
        '    Username *string `json:"username"`',
        '    Email    string  `json:"email"`',
        "    ",
        "    // 3. Collections: Slices and Maps",
        '    Roles    []string          `json:"roles"`',
        '    Settings map[string]string `json:"settings"`',
        "",
        "    // 4. Nested Anonymous Struct",
        "    Address struct {",
        '        City    string `json:"city"`',
        '        ZipCode int    `json:"zip_code"`',
        '    } `json:"address"`',
        "",
        "    // 5. Interface member (for polymorphism tests)",
        '    Permissions any `json:"permissions"`',
        "    ",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "func NewUserProfile() *UserProfile {",
        "    return nil",
        "}",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)
end)
