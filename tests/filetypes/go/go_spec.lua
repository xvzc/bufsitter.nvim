local cursor = require("bufsitter.cursor")
local io = require("bufsitter.io")
local h = require("tests.helpers")

local SAMPLE = "tests/filetypes/go/sample.go"

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
        cursor.root():children():filter(func_named("NewUserProfile")):first():exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = items[1]:type()
      assert.are.same("function_declaration", actual)
    end)

    it("gets name field of NewUserProfile", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "name" } })
        :exec(bufnr)
      local actual = vim.treesitter.get_node_text(items[1], bufnr)
      assert.are.same("NewUserProfile", actual)
    end)

    it("gets parameters field", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "parameters" } })
        :exec(bufnr)
      local actual = items[1]:type()
      assert.are.same("parameter_list", actual)
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
        :children({ names = { "name" } })
        :exec(bufnr)
      local actual = vim.treesitter.get_node_text(items[1], bufnr)
      assert.are.same("name", actual)
    end)

    it("gets result field (return type)", function()
      local items = cursor
        .root()
        :children()
        :filter(func_named("NewUserProfile"))
        :first()
        :children({ names = { "result" } })
        :exec(bufnr)
      assert.are.same(true, #items > 0)
      local actual = vim.treesitter.get_node_text(items[1], bufnr)
      assert.are.same(true, actual:find("UserProfile") ~= nil)
    end)
  end)

  describe("type_declaration", function()
    it("finds Metadata type by name", function()
      local items =
        cursor.root():children():filter(type_named("Metadata")):first():exec(bufnr)
      assert.are.same(true, #items > 0)
    end)

    it("finds UserProfile type by name", function()
      local items =
        cursor.root():children():filter(type_named("UserProfile")):first():exec(bufnr)
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
        end)
        :exec(bufnr)
      local actual = #items
      assert.are.same(4, actual)
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
        :children({ names = { "name" } })
        :exec(bufnr)
      local actual = vim.treesitter.get_node_text(items[1], bufnr)
      assert.are.same("ID", actual)
    end)
  end)

  describe("io integration", function()
    it("io.select returns exact lines of Metadata type_declaration", function()
      local results = io.select(bufnr, {
        cursor = cursor.root():children():filter(type_named("Metadata")):first(),
      })
      local expected = {
        "type Metadata struct {",
        '    ID        int64     `json:"id" check:"required"`',
        '    CreatedAt time.Time `json:"created_at"`',
        '    IsActive  bool      `json:"is_active"`',
        '    Version   string    `json:"version"`',
        "}",
      }
      local actual = results[1]
      assert.are.same(expected, actual)
    end)

    it("io.select returns exact lines of NewUserProfile function_declaration", function()
      local results = io.select(bufnr, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      local expected = {
        "func NewUserProfile(name string) *UserProfile {",
        "    return &UserProfile{",
        "        Username: &name,",
        '        Roles:    []string{"user", "guest"},',
        "        Settings: make(map[string]string),",
        "    }",
        "}",
      }
      local actual = results[1]
      assert.are.same(expected, actual)
    end)

    it("io.delete removes Metadata type_declaration", function()
      io.delete(bufnr, {
        cursor = cursor.root():children():filter(type_named("Metadata")):first(),
      })
      local expected = {
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
        "",
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
        "",
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
      }
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("io.delete removes NewUserProfile function_declaration", function()
      io.delete(bufnr, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      local expected = {
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
        "",
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
        "",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "",
      }
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("io.insert prepends before NewUserProfile function_declaration", function()
      io.insert(bufnr, { "// generated function" }, {
        prepend = true,
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      local expected = {
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
        "",
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
        "",
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
      }
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)

    it("io.replace swaps NewUserProfile implementation", function()
      io.replace(bufnr, {
        "func NewUserProfile() *UserProfile {",
        "    return nil",
        "}",
      }, {
        cursor = cursor.root():children():filter(func_named("NewUserProfile")):first(),
      })
      local expected = {
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
        "",
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
        "",
        "    // 6. Channel for concurrency tests",
        '    StatusChan chan int `json:"-"`',
        "}",
        "",
        "// NewUserProfile is a constructor example to test return types",
        "func NewUserProfile() *UserProfile {",
        "    return nil",
        "}",
      }
      local actual = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same(expected, actual)
    end)
  end)
end)
