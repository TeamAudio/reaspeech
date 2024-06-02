--[[

  Polo.lua - Plain Old Lua Object (POLO) class generator

]]--

function Polo(definition)
  definition.__index = definition

  local new_override = definition.new

  definition.new = function(...)
    local o = new_override and new_override(...) or ... or {}
    assert(type(o) == 'table')

    setmetatable(o, definition)
    if o.init then o:init() end

    return o
  end

  return definition
end
