RUBY=ruby

input:=$(wildcard *.png)
output:=$(input:.png=.lua)

all: $(output)

%.lua: %.png
	$(RUBY) ../../../common/scripts/png_to_lua.rb $< $@

.PHONY: clean
clean:
	rm -f *.lua
