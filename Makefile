test:
	nvim \
    --headless \
    -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

docs:
	mkdir -p doc
	lemmy-help -f -t \
		lua/bufsitter/init.lua \
		lua/bufsitter/config.lua \
		lua/bufsitter/cursor.lua \
		lua/bufsitter/io.lua \
		lua/bufsitter/ref.lua \
		lua/bufsitter/scratch.lua \
		> doc/bufsitter.txt
	nvim --headless -c "helptags doc/" -c "q"
