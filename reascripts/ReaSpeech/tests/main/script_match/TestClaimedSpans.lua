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

require('main/script_match/curation/ClaimedSpans')

--

local function make_claims(needle_records)
  local listeners = {}
  local state_manager = {
    get_needles_with_suggestions = function()
      local entries = {}
      for guid, record in pairs(needle_records) do
        table.insert(entries, { needle_guid = guid, count = #record })
      end
      table.sort(entries, function(a, b) return a.needle_guid < b.needle_guid end)
      return entries
    end,
    load_accepted_suggestions = function(_self, guid)
      local accepted = {}
      for _, suggestion in ipairs(needle_records[guid] or {}) do
        if suggestion.state == 'accepted' then
          table.insert(accepted, suggestion)
        end
      end
      return accepted
    end,
  }
  local workflow = {
    listeners = listeners,
    get_suggestion_state_manager = function() return state_manager end,
    listen_for_event = function(_self, name, callback)
      listeners[name] = listeners[name] or {}
      table.insert(listeners[name], callback)
    end,
    emit = function(self, name)
      for _, callback in ipairs(self.listeners[name] or {}) do callback() end
    end,
  }
  return ClaimedSpans.new { workflow = workflow }, workflow
end

TestClaimedSpans = {}

function TestClaimedSpans:testAcceptedSpansGroupByTrackAndNeedle()
  local claims = make_claims({
    N1 = {
      { state = 'accepted', start_time = 10, end_time = 12, track_guids = { 'T1' } },
      { state = 'pending', start_time = 20, end_time = 22, track_guids = { 'T1' } },
    },
    N2 = {
      { state = 'accepted', start_time = 30, end_time = 32, track_guids = { 'T2' } },
    },
  })

  local by_track = claims:by_track()
  lu.assertEquals(#by_track.T1, 1)
  lu.assertEquals(by_track.T1[1].needle_guid, 'N1')
  lu.assertEquals(by_track.T1[1].start_time, 10)
  lu.assertEquals(#by_track.T2, 1)

  local by_needle = claims:by_needle()
  lu.assertEquals(by_needle.N1[1].track_guid, 'T1')
  lu.assertNil(by_needle.N1[2]) -- pending never claims
end

function TestClaimedSpans:testEventInvalidationRecomputes()
  local records = {
    N1 = { { state = 'accepted', start_time = 1, end_time = 2, track_guids = { 'T1' } } },
  }
  local claims, workflow = make_claims(records)

  lu.assertEquals(#claims:by_track().T1, 1)

  table.insert(records.N1,
    { state = 'accepted', start_time = 5, end_time = 6, track_guids = { 'T1' } })

  -- Cached until an invalidating event fires
  lu.assertEquals(#claims:by_track().T1, 1)
  workflow:emit('suggestion_decided')
  lu.assertEquals(#claims:by_track().T1, 2)
end

function TestClaimedSpans:testEmptySessionYieldsEmptyMaps()
  local claims = make_claims({})
  lu.assertEquals(claims:by_track(), {})
  lu.assertEquals(claims:by_needle(), {})
end

--

os.exit(lu.LuaUnit.run())
