--[[

  Strings.lua - module to use localization definitions

]]--

Strings = {
  DEFAULT_LANGUAGE = 'en',
  DEFAULT_REGION = 'US',
}

Strings.localize = function(tag)
  local strings = Strings._get_language_and_region_strings(tag)

  if strings._fallback then
    local f = Strings.localize(strings._fallback) or {}
    strings._strings = Strings._overlay_strings(f, strings._strings)
  end

  return strings._strings
end

Strings._overlay_strings = function(base, strings)
  local result = table.shallow_clone(base or {})

  for key, value in pairs(strings) do
    if type(value) == 'table' then
      result[key] = Strings._overlay_strings(result[key], value)
    else
      result[key] = value
    end
  end

  return result
end

Strings._decompose_tag = function(tag)
  local language, region = tag:match('^(%a%a)-(%a%a)$')

  if not language then
    language = tag:match('^(%a%a)$')
  end

  if not language then
    language = Strings.DEFAULT_LANGUAGE
    region = Strings.DEFAULT_REGION
  end

  if not Strings[language] then
    assert('invalid language: ' .. dump(language))
  end

  return language, region
end

Strings._get_language_and_region_strings = function(tag)
  local language, region = Strings._decompose_tag(tag)

  local strings = Strings[language]

  if region and strings[region] then
    strings = strings[region]
  end

  return strings
end

Strings.available_languages = function()
  if Strings._available_languages then return Strings._available_languages end

  local languages = {}

  for language, definition in pairs(Strings) do
    if language:match('^%a%a$') then
      -- look for base level definition
      if definition._name then
        languages[language] = definition._name
      end

      -- look for regional definitions
      for region, region_definition in pairs(definition) do
        if region:match('^%a%a$') then
          if region_definition._name then
            local tag = ('%s-%s'):format(language, region)
            languages[tag] = region_definition._name
          end
        end
      end
    end
  end

  Strings._available_languages = languages
  return languages
end