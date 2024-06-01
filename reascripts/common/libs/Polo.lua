--[[

  Polo.lua - Plain Old Lua Object (POLO) class generator

]]--

function Polo(definition)
  definition.__index = definition

  local new_override = definition.new

  definition.new = function(...)
    local o = ... or {}

    if new_override then
      local args = table.pack(...)
      o = new_override(table.unpack(args))
    end

    setmetatable(o, definition)
    if o.init then o:init() end

    return o
  end

  return definition
end
