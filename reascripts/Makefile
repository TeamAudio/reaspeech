LUA=lua
LUACHECK=luacheck
luacheckrc=ReaSpeech/.luacheckrc
modules=common/libs ReaSpeech/source
source_files=$(foreach module, $(modules), $(wildcard $(module)/*.lua) $(wildcard $(module)/*/*.lua))
tests=$(realpath $(foreach module, $(modules), $(wildcard $(dir $(module))tests/Test*lua)))

all: lint test

lint: $(source_files)
	$(LUACHECK) --config $(luacheckrc) $?

test:
	true $(foreach test, $(tests), \
		&& pushd $(dir $(test))../ \
		&& $(LUA) $(test) -v \
		&& popd)