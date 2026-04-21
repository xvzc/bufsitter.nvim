DOCS_DIR ?= doc
DEPS_DIR = .deps/start
PARSER_DIR = .deps/parsers
NVIM_PARSER_DIR = $(shell nvim --headless -c "lua io.write(vim.fn.stdpath('data'))" -c "q" 2>/dev/null)/site/parser

$(DEPS_DIR)/plenary.nvim:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@

$(DEPS_DIR)/nvim-treesitter:
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter $@

$(PARSER_DIR)/tree-sitter-go:
	git clone --depth 1 https://github.com/tree-sitter/tree-sitter-go $@

$(PARSER_DIR)/tree-sitter-typst:
	git clone --depth 1 https://github.com/uben0/tree-sitter-typst $@

_deps: $(DEPS_DIR)/plenary.nvim $(DEPS_DIR)/nvim-treesitter

_install-parsers: _deps $(PARSER_DIR)/tree-sitter-go $(PARSER_DIR)/tree-sitter-typst
	mkdir -p $(NVIM_PARSER_DIR)
	gcc -shared -fPIC -o $(NVIM_PARSER_DIR)/go.so -I$(PARSER_DIR)/tree-sitter-go/src \
		$(PARSER_DIR)/tree-sitter-go/src/parser.c
	gcc -shared -fPIC -o $(NVIM_PARSER_DIR)/typst.so -I$(PARSER_DIR)/tree-sitter-typst/src \
		$(PARSER_DIR)/tree-sitter-typst/src/parser.c \
		$(PARSER_DIR)/tree-sitter-typst/src/scanner.c

test: _install-parsers
	nvim \
    --headless \
    -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

_gen-docs:
	mkdir -p $(DOCS_DIR)
	lemmy-help -f -t \
		lua/bufsitter/init.lua \
		lua/bufsitter/cursor.lua \
		lua/bufsitter/io.lua \
		lua/bufsitter/ref.lua \
		lua/bufsitter/scratch.lua \
		> $(DOCS_DIR)/bufsitter.nvim.txt

docs:
	$(MAKE) _gen-docs DOCS_DIR=doc
	nvim --headless -c "helptags doc/" -c "q"

check-docs:
	mkdir -p .cache/doc/expected .cache/doc/actual
	cp doc/bufsitter.nvim.txt .cache/doc/expected/bufsitter.nvim.txt
	$(MAKE) _gen-docs DOCS_DIR=.cache/doc/actual
	diff .cache/doc/expected .cache/doc/actual

clean:
	rm -rf .cache .deps
