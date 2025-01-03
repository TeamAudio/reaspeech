LUA53=lua5.3
LUAC53=luac5.3
LUA54=lua5.4
LUAC54=luac5.4
LUACHECK=luacheck
LUA=lua

VENDOR=json.lua url.lua
SOURCE_ROOT=source

# Miscellaneous directly-referenced bundle components
BUNDLE_INCLUDE=$(SOURCE_ROOT)/include
BUNDLE_TARGET=build/ReaSpeechBundle.lua

find_lua_sources=$(foreach p, $(1), $(wildcard $(1)/*.lua) $(foreach d, $(wildcard $(1)/*/.), $(call find_lua_sources, $(d))))

dest=../../app/static/reascripts/ReaSpeech

SOURCES=libs ui main

# All the luas!
source:=$(call find_lua_sources, $(SOURCE_ROOT))
tests:=$(wildcard tests/Test*.lua tests/*/Test*.lua)

# Bundle contents, in order
headers:=$(foreach h, header globals, $(BUNDLE_INCLUDE)/$(h).lua)
vendor:=$(foreach lib, $(VENDOR), vendor/$(lib))
images:=$(wildcard resources/images/*.lua)
sources:=$(foreach s, $(SOURCES), $(call find_lua_sources, $(SOURCE_ROOT)/$(s)))
version:=version.lua
main:=$(BUNDLE_INCLUDE)/main.lua

bundle_contents:=$(headers) $(vendor) $(images) $(sources) $(version) $(main)

all: lint test publish

lint: $(source)
	$(LUACHECK) $?

test: $(source) $(libs) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)

test-noversion: $(source) $(libs) $(tests)
	true $(foreach test, $(tests), && $(LUA) $(test) -v)

.PHONY: build
build: build/ReaSpeech-5.3.luac build/ReaSpeech-5.4.luac

$(BUNDLE_TARGET): $(source) $(libs) $(vendor) $(version)
	cat $(bundle_contents) > $(BUNDLE_TARGET)

build/ReaSpeech-5.3.luac: $(BUNDLE_TARGET)
	$(LUAC53) -o build/ReaSpeech-5.3.luac -s $(BUNDLE_TARGET)

build/ReaSpeech-5.4.luac: $(BUNDLE_TARGET)
	$(LUAC54) -o build/ReaSpeech-5.4.luac -s $(BUNDLE_TARGET)

.PHONY: publish
publish: build
	cp build/ReaSpeech-5.3.luac $(dest)/
	cp build/ReaSpeech-5.4.luac $(dest)/

.PHONY: tags
tags : tagged_paths = $(SOURCE_ROOT) libs
tags:
	-rm -f TAGS
	@for path in $(tagged_paths); do \
		echo "Tagging $$path"; \
		find $$path -type f -iname '*.lua' -print0 | xargs -0 etags --append; \
	done

.PHONY: clean
clean:
	rm -f build/ReaSpeech-5.3.luac build/ReaSpeech-5.4.luac $(BUNDLE_TARGET) TAGS
