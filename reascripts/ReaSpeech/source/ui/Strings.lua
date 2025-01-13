--[[

  Strings.lua - module to use localization definitions

]]--

Strings = {}

Strings.localize = function(tag)
  local language, region = tag:match('^(%a%a)-(%a%a)$')

  if not language then
    language = tag:match('^(%a%a)$')
  end

  if not language then
    language = 'en'
    region = 'US'
  end

  if not Strings[language] then
    assert('invalid language: ' .. dump(language))
  end

  strings = Strings[language]

  if region then
    if not strings[region] then
      assert('invalid region: ' .. dump(region))
    end

    strings = strings[region]
  end

  local fallback = function(_) return nil end
  if strings._fallback then
    fallback = function(key)
      return Strings.localize(strings._fallback)[key]
    end
  end

  return setmetatable({}, {
    __index = function(_, key)
      return Strings.indexer(strings._strings or {}, key, fallback)
    end
  })
end

Strings.indexer = function(strs, key, fallback)
  if strs[key] then
    if type(strs[key]) == 'table' then
      return setmetatable({}, {
        __index = function(_, key1)
          return Strings.indexer(strs[key] or {}, key1)
        end
      })
    end

    return strs[key]
  else
    return fallback(key)
  end
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