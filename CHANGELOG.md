# Changelog

## 1.0.0 (2026-04-21)


### Features

* add min_width/min_height, row/col defaults, trim_end option, and io comments ([08eca74](https://github.com/xvzc/bufsitter.nvim/commit/08eca749b133c8ea170d8c7fcf429036b1e50ecf))
* add texts filter to cursor opts and update README usage example ([266c9e9](https://github.com/xvzc/bufsitter.nvim/commit/266c9e9509c7c7db3333f25bc1d5980aacc146ef))
* add texts filter to cursor opts and update README with usage example ([62ddd62](https://github.com/xvzc/bufsitter.nvim/commit/62ddd62d53aa362edc747ca044f1aa9c5f03fa5b))
* center floating window and support ratio-based width/height ([a3c916c](https://github.com/xvzc/bufsitter.nvim/commit/a3c916c709e4ee698eb1ca924b0f689b8abab4d3))
* resize floating window on VimResized ([7329d35](https://github.com/xvzc/bufsitter.nvim/commit/7329d359f712f741020f112323335a9d53f69049))


### Bug Fixes

* access config via require('bufsitter').config directly ([01b1617](https://github.com/xvzc/bufsitter.nvim/commit/01b1617ea08a76546dc375b33ea28f41547bf1e8))
* apply copilot review suggestions ([a60f6ed](https://github.com/xvzc/bufsitter.nvim/commit/a60f6ed8cd3117787215ebf10fa7ed5effb507a8))
* guard setup() with vim.g.bufsitter_loaded to prevent config reset on reload ([cc30501](https://github.com/xvzc/bufsitter.nvim/commit/cc305018bf5cb381f2448853e7d4652e08e56c9a))
* initialize M.config with defaults at module load time ([65116e0](https://github.com/xvzc/bufsitter.nvim/commit/65116e0ac9427ba38c933e7f39c6220499e4d74c))
