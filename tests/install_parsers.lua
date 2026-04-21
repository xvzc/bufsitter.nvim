vim.opt.runtimepath:append(vim.fn.getcwd() .. "/.deps/start/nvim-treesitter")
vim.cmd("runtime! plugin/nvim-treesitter.lua")
require("nvim-treesitter.install").prefer_git = false
vim.cmd("TSInstall! go typst")
