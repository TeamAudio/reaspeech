LUA53=lua5.3
LUAC53=luac5.3
LUA54=lua5.4
LUAC54=luac5.4
LUACHECK=luacheck
GIT=git

LOKASENNAGUI_REPO=https://github.com/TeamAudio/lokasenna-gui.git
LOKASENNAGUI_BRANCH=develop

source:=$(wildcard libs/*.lua tests/*.lua)
tests:=$(wildcard tests/Test*.lua)

all: lint test

lint: $(source)
	$(LUACHECK) $?

test: $(source) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)

.PHONY: build/lokasenna-gui
build/lokasenna-gui:
	rm -rf build/lokasenna-gui
	$(GIT) clone '$(LOKASENNAGUI_REPO)' build/lokasenna-gui
	pushd build/lokasenna-gui; $(GIT) checkout '$(LOKASENNAGUI_BRANCH)'; popd

.PHONY: build/lokasenna-gui.lua
build/lokasenna-gui.lua: build/lokasenna-gui
	echo "GUI = {}\r" > build/lokasenna-gui.lua
	awk '/-- Error handling --/{p++;if(p==1){next}}p' 'build/lokasenna-gui/Lokasenna_GUI v2/Library/Core.lua' >> build/lokasenna-gui.lua
	find 'build/lokasenna-gui/Lokasenna_GUI v2/Library/Classes' -name '*.lua' -exec cat {} + >> build/lokasenna-gui.lua

.PHONY: vendor/lokasenna-gui.lua
vendor/lokasenna-gui.lua: build/lokasenna-gui.lua
	mkdir -p vendor
	cp -v build/lokasenna-gui.lua vendor/lokasenna-gui.lua