LUA53=lua5.3
LUAC53=luac5.3
LUA54=lua5.4
LUAC54=luac5.4
LUACHECK=luacheck

LIBS=Ctx.lua EnvUtil.lua ExecProcess.lua ImGuiTheme.lua PathUtil.lua Polo.lua ReaIter.lua ReaUtil.lua Storage.lua TableUtils.lua Tempfile.lua Trap.lua
VENDOR=json.lua url.lua
COMMON_ROOT=../common
SOURCE_ROOT=source

# Directory to scan for split-out components (like big stateful widgets)
COMPONENTS_ROOT=$(SOURCE_ROOT)/components

# If a component has a _module.lua file, it will be included before the rest of the lua files found alongside it.
MODULE_HEADER=_module.lua

# Miscellaneous directly-referenced bundle components
BUNDLE_INCLUDE=$(SOURCE_ROOT)/include
BUNDLE_TARGET=build/ReaSpeechBundle.lua

find_lua_sources = $(foreach p, $(1), $(shell find $(p) -type f -name '*.lua'))

dest=../../app/static/reascripts/ReaSpeech

# All the luas!
source:=$(call find_lua_sources, .)
tests:=$(wildcard tests/Test*.lua)

# Find all components under $(COMPONENTS_ROOT) and separate headers from sources.
# With these two lists we can ensure that module initializers are included before sources.
component_source:= $(call find_lua_sources, $(COMPONENTS_ROOT))
component_initializers:=$(filter %/$(MODULE_HEADER), $(component_source))
component_sources:=$(filter-out %/$(MODULE_HEADER), $(component_source))

# Bundle contents, in order
headers:=$(foreach h, header globals, $(BUNDLE_INCLUDE)/$(h).lua)
libs:=$(foreach lib, $(LIBS), $(COMMON_ROOT)/libs/$(lib))
vendor:=$(foreach lib, $(VENDOR), $(COMMON_ROOT)/vendor/$(lib))
images:=$(wildcard resources/images/*.lua)
components:=$(component_initializers) $(component_sources)
sources:=libs/*.lua $(SOURCE_ROOT)/*.lua $(components)
version:=version.lua
main:=$(BUNDLE_INCLUDE)/main.lua

bundle_contents:=$(headers) $(libs) $(vendor) $(images) $(sources) $(version) $(main)

all: lint test publish

lint: $(source) $(libs)
	$(LUACHECK) $?

test: $(source) $(libs) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)

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
tags : tagged_paths = $(SOURCE_ROOT) libs $(COMMON_ROOT)
tags:
	-rm -f TAGS
	@for path in $(tagged_paths); do \
		echo "Tagging $$path"; \
		find $$path -type f -iname '*.lua' -print0 | xargs -0 etags --append; \
	done

.PHONY: clean
clean:
	rm -f build/ReaSpeech-5.3.luac build/ReaSpeech-5.4.luac $(BUNDLE_TARGET) TAGS
