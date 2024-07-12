LUA53=lua5.3
LUAC53=luac5.3
LUA54=lua5.4
LUAC54=luac5.4
LUACHECK=luacheck

source:=$(wildcard libs/*.lua tests/*.lua)
tests:=$(wildcard tests/Test*.lua)

all: lint test

lint: $(source)
	$(LUACHECK) $?

test: $(source) $(tests)
	true $(foreach test, $(tests), && $(LUA53) $(test) -v)
	true $(foreach test, $(tests), && $(LUA54) $(test) -v)
