package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

local guid_counter = 0
reaper = {
  genGuid = function()
    guid_counter = guid_counter + 1
    return ('{GUID-%d}'):format(guid_counter)
  end
}

-- Minimal storage stand-in: table accessors backed by plain values
Storage = {
  ProjectJSON = function()
    return {
      table = function(_self, _name, default)
        local data = default
        return {
          get = function() return data end,
          set = function(_s, value) data = value end,
        }
      end
    }
  end
}

-- Classification is content-derived and covered by TestMatchability;
-- here it just needs to not blow up
Matchability = {
  classify = function(_content) return { class = 'text' } end,
}

require('main/script_match/curation/NeedleGenerator')

--

local function make_generator()
  return NeedleGenerator.new {
    session_id = 'session-1',
    script_materials = {},
    materials_service = {},
  }
end

--

TestResolveNeedle = {}

function TestResolveNeedle:testExistingLocatorKeepsGuidButRefreshesData()
  local generator = make_generator()
  local existing = {
    guid = '{OLD-GUID}',
    locator = 'worksheet_1:row_5',
    content = 'Old content',
    metadata = {},
  }
  local fresh = {
    locator = 'worksheet_1:row_5',
    content = 'New content',
    metadata = { { tag = 'character', value = 'SOLACE' } },
  }

  local resolved = generator:resolve_needle(fresh, { ['worksheet_1:row_5'] = existing })

  lu.assertEquals(resolved.guid, '{OLD-GUID}')
  lu.assertEquals(resolved.content, 'New content')
  lu.assertEquals(resolved.metadata, { { tag = 'character', value = 'SOLACE' } })
end

function TestResolveNeedle:testUnknownLocatorGetsFreshGuid()
  local generator = make_generator()
  local fresh = { locator = 'worksheet_1:row_9', content = 'Brand new' }

  local resolved = generator:resolve_needle(fresh, {})

  lu.assertStrContains(resolved.guid, '{GUID-')
  lu.assertEquals(resolved.content, 'Brand new')
end

function TestResolveNeedle:testDeduplicatePreservesGuidsAcrossRegeneration()
  local generator = make_generator()
  local existing = {
    guid = '{STABLE}',
    locator = 'worksheet_1:row_5',
    metadata = {},
  }
  local fresh_needles = {
    { locator = 'worksheet_1:row_5', content = 'Line', metadata = { { tag = 'character', value = 'BRINE' } } },
    { locator = 'worksheet_1:row_8', content = 'Other line', metadata = {} },
  }

  local deduplicated = generator:deduplicate_needles(
    fresh_needles,
    { ['worksheet_1:row_5'] = existing },
    { name = 'Material.xlsx' })

  lu.assertEquals(#deduplicated, 2)
  lu.assertEquals(deduplicated[1].guid, '{STABLE}')
  lu.assertEquals(deduplicated[1].metadata[1].value, 'BRINE')
  lu.assertNotEquals(deduplicated[2].guid, '{STABLE}')
  lu.assertEquals(deduplicated[1].navigation[1], 'Material.xlsx')
end

--

os.exit(lu.LuaUnit.run())
