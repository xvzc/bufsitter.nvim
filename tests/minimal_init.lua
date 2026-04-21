vim.cmd([[set runtimepath+=.]])

vim.opt.swapfile = false
vim.opt.undofile = false

local function load(plugin)
  local name = plugin:match(".*/(.*)")
  local deps_dir = vim.fn.getcwd() .. "/.deps/start/"
  local target_path = deps_dir .. name

  if not vim.loop.fs_stat(target_path) then
    print("Cloning " .. plugin .. "...")
    vim.fn.mkdir(deps_dir, "p")
    vim.fn.system({
      "git",
      "clone",
      "--depth",
      "1",
      "https://github.com/" .. plugin,
      target_path,
    })
  end

  vim.opt.runtimepath:append(target_path)
end

load("nvim-lua/plenary.nvim")
require("plenary.busted")
