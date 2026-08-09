LUA53=lua5.3
LUA54=lua5.4
LUACHECK=luacheck
LUA=lua
PYTHON=python3

REASCRIPTS_DIR?=$(abspath ../../../reascripts)

VENDOR=json.lua
SOURCE_ROOT=source
TEST_ROOT=tests

# Miscellaneous directly-referenced bundle components
BUNDLE_INCLUDE=$(SOURCE_ROOT)/include
BUNDLE_TARGET=build/ReaSpeech.lua

# usage: $(call lua_sources,<directory>,<file_prefix>)
# e.g. $(call lua_sources,tests,Test) -> tests/Test*.lua tests/**/Test*.lua
lua_sources=$(wildcard $(1)/$(2)*.lua) $(foreach d, $(wildcard $(1)/*), $(call lua_sources, $(d),$(2)))

SOURCES=libs ui main

# All the luas!
source:=$(call lua_sources, $(SOURCE_ROOT))
tests:=$(call lua_sources, $(TEST_ROOT),Test)

# Bundle contents, in order
headers:=$(foreach h, header globals, $(BUNDLE_INCLUDE)/$(h).lua)
vendor:=$(foreach lib, $(VENDOR), vendor/$(lib))
images:=$(wildcard resources/images/*.lua)
sources:=$(foreach s, $(SOURCES), $(call lua_sources, $(SOURCE_ROOT)/$(s)))
version:=version.lua
main:=$(BUNDLE_INCLUDE)/main.lua

bundle_contents:=$(headers) $(vendor) $(images) $(sources) $(version) $(main)

all: lint test publish

lint: $(source)
	$(LUACHECK) $?

test: $(source) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)

test-noversion: $(source) $(tests)
	true $(foreach test, $(tests), && $(LUA) $(test) -v)

.PHONY: build
build: $(BUNDLE_TARGET)

$(BUNDLE_TARGET): $(bundle_contents)
	mkdir -p $(dir $(BUNDLE_TARGET))
	cat $(bundle_contents) | sed 's/@REASPEECH_VERSION@/$(shell sed -n 's/.*VERSION = "\([^"]*\)"/\1/p' version.lua)/' > $(BUNDLE_TARGET)

.PHONY: publish-check
publish-check: $(BUNDLE_TARGET)
	$(PYTHON) ../../scripts/publish_reapack.py --check --reascripts-dir "$(REASCRIPTS_DIR)" "$(BUNDLE_TARGET)"

.PHONY: publish
publish: $(BUNDLE_TARGET)
	$(PYTHON) ../../scripts/publish_reapack.py --push --reascripts-dir "$(REASCRIPTS_DIR)" "$(BUNDLE_TARGET)"

.PHONY: tags
tags : tagged_paths = $(SOURCE_ROOT)
tags:
	-rm -f TAGS
	@for path in $(tagged_paths); do \
		echo "Tagging $$path"; \
		find $$path -type f -iname '*.lua' -print0 | xargs -0 etags --append; \
	done

.PHONY: clean
clean:
	rm -f $(BUNDLE_TARGET) TAGS
