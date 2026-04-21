DOCS_DIR ?= doc
DEPS_DIR = .deps/start

$(DEPS_DIR)/plenary.nvim:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@

$(DEPS_DIR)/nvim-treesitter:
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter $@

_deps: $(DEPS_DIR)/plenary.nvim $(DEPS_DIR)/nvim-treesitter

_install-parsers: _deps
	nvim --headless -u tests/install_parsers.lua -c "q"

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
