lua_fmt:
	echo "===> Formatting"
	stylua lua/ --config-path=.stylua.toml

lua_lint:
	echo "===> Linting"
	luacheck lua/ --globals vim

lua_test:
	echo "===> Testing"
	nvim --headless --noplugin -u scripts/tests/minimal.vim \
        -c "PlenaryBustedDirectory lua/99 {minimal_init = 'scripts/tests/minimal.vim'}"

lua_clean:
	echo "===> Cleaning"
	rm /tmp/lua_*

pr-ready: lua_clean lua_fmt lua_lint lua_test
