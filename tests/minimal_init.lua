vim.cmd([[set runtimepath+=.]])

vim.opt.swapfile = false
vim.opt.undofile = false

local deps_dir = vim.fn.getcwd() .. "/.deps/start/"
vim.opt.runtimepath:append(deps_dir .. "plenary.nvim")
vim.opt.runtimepath:append(deps_dir .. "nvim-treesitter")

require("plenary.busted")
