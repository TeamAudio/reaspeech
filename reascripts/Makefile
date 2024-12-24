LUA=lua
LUACHECK=luacheck
luacheckrc=ReaSpeech/.luacheckrc
modules=common/libs ReaSpeech/source
find_lua_sources = $(foreach p, $(1), $(shell find $(p) -type f -name '*.lua'))
source_files=$(foreach module, $(modules), $(call find_lua_sources, $(module)))
tests=$(realpath $(foreach module, $(modules), $(wildcard $(dir $(module))tests/Test*lua)))

all: lint test

lint: $(source_files)
	$(LUACHECK) --codes --config $(luacheckrc) $?

test:
	true $(foreach test, $(tests), \
		&& pushd $(dir $(test))../ \
		&& $(LUA) $(test) -v \
		&& popd)