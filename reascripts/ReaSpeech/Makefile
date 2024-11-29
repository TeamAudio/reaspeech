LUA53=lua5.3
LUAC53=luac5.3
LUA54=lua5.4
LUAC54=luac5.4
LUACHECK=luacheck

LIBS=EnvUtil.lua ExecProcess.lua ImGuiTheme.lua PathUtil.lua Polo.lua ReaIter.lua ReaUtil.lua Storage.lua TableUtils.lua Tempfile.lua Trap.lua
VENDOR=json.lua url.lua

source:=$(wildcard libs/*.lua source/*.lua source/include/*.lua)
libs:=$(foreach lib, $(LIBS), ../common/libs/$(lib))
vendor:=$(foreach lib, $(VENDOR), ../common/vendor/$(lib))
tests:=$(wildcard tests/Test*.lua)
dest=../../app/static/reascripts/ReaSpeech

all: lint test publish

lint: $(source) $(libs)
	$(LUACHECK) $?

test: $(source) $(libs) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)

.PHONY: build
build: build/ReaSpeech-5.3.luac build/ReaSpeech-5.4.luac

build/ReaSpeechBundle.lua: $(source) $(libs) $(vendor) version.lua
	cat source/include/header.lua source/include/globals.lua $(libs) $(vendor) resources/images/*.lua libs/*.lua source/*.lua version.lua source/include/main.lua > build/ReaSpeechBundle.lua

build/ReaSpeech-5.3.luac: build/ReaSpeechBundle.lua
	$(LUAC53) -o build/ReaSpeech-5.3.luac -s build/ReaSpeechBundle.lua

build/ReaSpeech-5.4.luac: build/ReaSpeechBundle.lua
	$(LUAC54) -o build/ReaSpeech-5.4.luac -s build/ReaSpeechBundle.lua

.PHONY: publish
publish: build
	cp build/ReaSpeech-5.3.luac $(dest)/
	cp build/ReaSpeech-5.4.luac $(dest)/

.PHONY: tags
tags:
	find source/ -type f -iname '*.lua' -print0 | xargs -0 etags
	find libs/ -type f -iname '*.lua' -print0 | xargs -0 etags
	find ../common/libs/ -type f -iname '*.lua' -print0 | xargs -0 etags --append
	find ../common/vendor/ -type f -iname '*.lua' -print0 | xargs -0 etags --append

.PHONY: clean
clean:
	rm -f build/ReaSpeech-5.3.luac build/ReaSpeech-5.4.luac build/ReaSpeechBundle.lua TAGS
