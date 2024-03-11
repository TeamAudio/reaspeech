--[[

  OptionsConfig.lua - General options configuration data model

]]--

OptionsConfig = {}
OptionsConfig.__index = OptionsConfig

-- Constructor
--
-- Parameters:
--   section: Section to write in reaper-extstate.ini
--   options: Mapping from option names to {type, default} pairs
--            type can be one of: 'string', 'number', 'boolean'
--
-- Example:
--   local options = OptionsConfig:new {
--     section = "FXPermutator.Options",
--     options = {
--       plugins_per_chain = {'number', 2},
--       ...
--     }
--   }
--
function OptionsConfig:new(o)
  o = o or {}
  setmetatable(o, self)
  assert(o.section, 'section is required')
  o.options = o.options or {}
  return o
end

function OptionsConfig:get(name)
  local option = self.options[name]
  assert(option, 'undefined option ' .. name)

  local option_type, option_default = table.unpack(option)

  if self:exists(name) then
    local str = reaper.GetExtState(self.section, name)

    if option_type == 'number' then
      return self:_string_to_number(str)
    elseif option_type == 'boolean' then
      return self:_string_to_boolean(str)
    else
      return str
    end
  else
    return option_default
  end
end

function OptionsConfig:set(name, value)
  local option = self.options[name]
  assert(option, 'undefined option ' .. name)

  local option_type, _ = table.unpack(option)

  local str
  if option_type == 'number' then
    str = self:_number_to_string(value)
  elseif option_type == 'boolean' then
    str = self:_boolean_to_string(value)
  else
    str = tostring(value)
  end

  reaper.SetExtState(self.section, name, str, true)
end

function OptionsConfig:delete(name)
  assert(self.options[name], 'undefined option ' .. name)
  reaper.DeleteExtState(self.section, name, true)
end

function OptionsConfig:exists(name)
  assert(self.options[name], 'undefined option ' .. name)
  return reaper.HasExtState(self.section, name)
end

function OptionsConfig:_string_to_number(str)
  return tonumber(str) or 0
end

function OptionsConfig:_string_to_boolean(str)
  return str == 'true'
end

function OptionsConfig:_number_to_string(num)
  return tostring(tonumber(num) or 0)
end

function OptionsConfig:_boolean_to_string(bool)
  return bool and 'true' or 'false'
end
