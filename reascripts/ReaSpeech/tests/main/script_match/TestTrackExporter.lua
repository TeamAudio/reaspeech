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

-- Scripted project double: tracks are tables holding items holding
-- takes, regions live in an id-keyed map; the reaper API below reads
-- and mutates this structure
local project

local function reset_project(tracks)
  project = { tracks = tracks or {}, regions = {}, next_region_id = 0 }
end

local function make_track(guid, name, folder_depth)
  return { guid = guid, name = name, ext = {}, items = {},
    values = {}, folder_depth = folder_depth or 0 }
end

local function track_index(track)
  for i, t in ipairs(project.tracks) do
    if t == track then return i end
  end
end

local function region_ids()
  local ids = {}
  for id in pairs(project.regions) do table.insert(ids, id) end
  table.sort(ids)
  return ids
end

local new_track_counter = 0

reaper = {
  time_precise = function() return 0 end,
  Undo_BeginBlock = function() end,
  Undo_EndBlock = function() end,
  UpdateArrange = function() end,

  CountTracks = function() return #project.tracks end,
  GetTrack = function(_, i) return project.tracks[i + 1] end,
  GetTrackGUID = function(track) return track.guid end,
  GetMediaTrackInfo_Value = function(track, key)
    if key == 'IP_TRACKNUMBER' then return track_index(track) end
    if key == 'I_FOLDERDEPTH' then return track.folder_depth end
    return track.values[key] or 0
  end,
  SetMediaTrackInfo_Value = function(track, key, value)
    if key == 'I_FOLDERDEPTH' then
      track.folder_depth = value
    else
      track.values[key] = value
    end
  end,
  InsertTrackAtIndex = function(index, _)
    new_track_counter = new_track_counter + 1
    table.insert(project.tracks, index + 1,
      make_track('NEW-' .. new_track_counter, ''))
  end,
  GetSetMediaTrackInfo_String = function(track, key, value, set)
    if key == 'P_NAME' then
      if set then track.name = value end
      return true, track.name
    end
    if set then track.ext[key] = value end
    return true, track.ext[key] or ''
  end,

  CountTrackMediaItems = function(track) return #track.items end,
  GetTrackMediaItem = function(track, i) return track.items[i + 1] end,
  DeleteTrackMediaItem = function(track, item)
    for i, candidate in ipairs(track.items) do
      if candidate == item then
        table.remove(track.items, i)
        return
      end
    end
  end,
  AddMediaItemToTrack = function(track)
    local item = { values = {}, takes = {} }
    table.insert(track.items, item)
    return item
  end,
  SetMediaItemInfo_Value = function(item, key, value)
    item.values[key] = value
  end,
  GetSetMediaItemInfo_String = function(item, key, value, set)
    if set then item[key] = value end
    return true, item[key] or ''
  end,

  AddTakeToMediaItem = function(item)
    local take = { values = {} }
    table.insert(item.takes, take)
    return take
  end,
  PCM_Source_CreateFromFile = function(path) return { path = path } end,
  SetMediaItemTake_Source = function(take, source) take.source = source end,
  SetMediaItemTakeInfo_Value = function(take, key, value)
    take.values[key] = value
  end,
  GetSetMediaItemTakeInfo_String = function(take, key, value, set)
    if set then take[key] = value end
    return true, take[key] or ''
  end,

  ColorToNative = function(r, g, b) return r | (g << 8) | (b << 16) end,

  AddProjectMarker2 = function(_, isrgn, pos, rgnend, name, _, color)
    project.next_region_id = project.next_region_id + 1
    project.regions[project.next_region_id] =
      { isrgn = isrgn, pos = pos, rgnend = rgnend, name = name, color = color }
    return project.next_region_id
  end,
  DeleteProjectMarker = function(_, id, _)
    project.regions[id] = nil
  end,
  EnumProjectMarkers3 = function(_, i)
    local id = region_ids()[i + 1]
    if not id then return 0 end
    local r = project.regions[id]
    return i + 1, r.isrgn, r.pos, r.rgnend, r.name, id, r.color
  end,
}

-- The exporter resolves timeline positions through this global; tests
-- script it per match via a .resolved field
SuggestionTimeline = {
  resolve = function(match) return match.resolved end,
}

require('main/script_match/export/TrackExporter')

local function make_exporter()
  return TrackExporter.new { session_id = 'SESSION' }
end

local function accepted(overrides)
  local source_track = overrides.source_track
  local match = {
    guid = overrides.guid or 'SUG-1',
    start_time = overrides.start_time or 10.0,
    end_time = overrides.end_time or 12.0,
    confidence = overrides.confidence or 0.9,
    long_shot = overrides.long_shot,
    time_adjusted = overrides.time_adjusted,
    needle_content = overrides.needle_content or 'And who taught you to juggle?',
    matching_text = overrides.matching_text or 'and who taught you to juggle',
    resolved = source_track and {
      track = source_track,
      start_time = overrides.timeline_start or 100.0,
      end_time = overrides.timeline_end or 102.0,
      source_path = overrides.source_path or '/media/VO Nova.wav',
      item_volume = overrides.item_volume,
      take_volume = overrides.take_volume,
    } or nil,
  }
  return { match = match, display_name = overrides.display_name or 'line001_take1.wav' }
end

--

TestTrackExporter = {}

function TestTrackExporter:setUp()
  reset_project({ make_track('SRC-A', 'VO Nova'), make_track('SRC-B', 'VO Quill') })
  new_track_counter = 0
end

function TestTrackExporter:testMatchedChildTrackPerSourceTrack()
  local src_a, src_b = project.tracks[1], project.tracks[2]
  local result = make_exporter():export({
    accepted { source_track = src_a, guid = 'S1' },
    accepted { source_track = src_a, guid = 'S2' },
    accepted { source_track = src_b, guid = 'S3' },
  })

  lu.assertEquals(result.placed, 3)
  lu.assertEquals(result.tracks, 2)
  lu.assertEquals(result.skipped, 0)
  lu.assertEquals(result.regions, 0)
  lu.assertEquals(#project.tracks, 4)

  -- Matched tracks land directly under their sources as CHILDREN:
  -- the source becomes a folder parent, the child closes its folder
  local child_a = project.tracks[2]
  lu.assertEquals(child_a.name, 'VO Nova (matched)')
  lu.assertEquals(child_a.ext[TrackExporter.EXT_KEY], 'SESSION|SRC-A')
  lu.assertEquals(#child_a.items, 2)
  lu.assertEquals(src_a.folder_depth, 1)
  lu.assertEquals(child_a.folder_depth, -1)

  local child_b = project.tracks[4]
  lu.assertEquals(child_b.name, 'VO Quill (matched)')
  lu.assertEquals(#child_b.items, 1)
end

function TestTrackExporter:testChildArrivesMuted()
  local src = project.tracks[1]
  make_exporter():export({ accepted { source_track = src } })

  local child = project.tracks[2]
  lu.assertEquals(child.values.B_MUTE, 1)

  -- Re-export respects the user's current mute state
  child.values.B_MUTE = 0
  make_exporter():export({ accepted { source_track = src } })
  lu.assertEquals(child.values.B_MUTE, 0)
end

function TestTrackExporter:testItemReferencesOriginalSourceAtSourceGain()
  local src = project.tracks[1]
  make_exporter():export({
    accepted {
      source_track = src,
      start_time = 33.5, end_time = 35.0,
      timeline_start = 210.0, timeline_end = 211.5,
      confidence = 0.97,
      item_volume = 2.75, take_volume = 1.5,
      display_name = 'nav/line042_take1.wav',
    },
  })

  local item = project.tracks[2].items[1]
  lu.assertEquals(item.values.D_POSITION, 210.0)
  lu.assertEquals(item.values.D_LENGTH, 1.5)
  lu.assertEquals(item.values.D_VOL, 2.75)

  local take = item.takes[1]
  lu.assertEquals(take.source.path, '/media/VO Nova.wav')
  lu.assertEquals(take.values.D_STARTOFFS, 33.5)
  lu.assertEquals(take.values.D_VOL, 1.5)
  lu.assertEquals(take.P_NAME, 'nav/line042_take1')

  lu.assertStrContains(item.P_NOTES, 'Line: And who taught you to juggle?')
  lu.assertStrContains(item.P_NOTES, 'Matched: "and who taught you to juggle"')
  lu.assertStrContains(item.P_NOTES, 'Confidence: 97%')
end

function TestTrackExporter:testGainDefaultsToUnityWhenUnresolved()
  local src = project.tracks[1]
  make_exporter():export({ accepted { source_track = src } })

  local item = project.tracks[2].items[1]
  lu.assertEquals(item.values.D_VOL, 1)
  lu.assertEquals(item.takes[1].values.D_VOL, 1)
end

function TestTrackExporter:testFolderClosingSourceStaysParentChildCloses()
  -- The Nova/Quill shape: a folder parent, a mid child, and a
  -- folder-closing last child (ISBUS 2 -1 in the RPP)
  reset_project({
    make_track('BUS', 'EQ Bus', 1),
    make_track('SRC-MID', 'VO Nova', 0),
    make_track('SRC-LAST', 'VO Quill', -1),
    make_track('OUTSIDE', 'VO Quill', 0),
  })

  make_exporter():export({
    accepted { source_track = project.tracks[3], guid = 'S1' },
  })

  -- The source becomes a folder parent; its child closes BOTH the
  -- new folder and the level the source used to close
  local source, child = project.tracks[3], project.tracks[4]
  lu.assertEquals(child.name, 'VO Quill (matched)')
  lu.assertEquals(source.folder_depth, 1)
  lu.assertEquals(child.folder_depth, -2)
end

function TestTrackExporter:testFolderParentSourceKeepsDepthChildIsFirstChild()
  reset_project({
    make_track('BUS', 'EQ Bus', 1),
    make_track('SRC-LAST', 'VO Nova', -1),
  })

  make_exporter():export({
    accepted { source_track = project.tracks[1], guid = 'S1' },
  })

  -- A source that is already a folder parent needs no depth repair:
  -- the new track lands as its first child by position alone
  lu.assertEquals(project.tracks[1].folder_depth, 1)
  lu.assertEquals(project.tracks[2].name, 'EQ Bus (matched)')
  lu.assertEquals(project.tracks[2].folder_depth, 0)
  lu.assertEquals(project.tracks[3].folder_depth, -1)
end

function TestTrackExporter:testReexportRefillsInsteadOfStacking()
  local src = project.tracks[1]
  local exporter = make_exporter()

  exporter:export({ accepted { source_track = src, guid = 'S1' } })
  local child = project.tracks[2]

  -- Second run, fresh exporter (as a fresh button press would be)
  local result = make_exporter():export({
    accepted { source_track = src, guid = 'S1' },
    accepted { source_track = src, guid = 'S2' },
  })

  lu.assertEquals(result.tracks, 1)
  lu.assertEquals(#project.tracks, 3)
  lu.assertEquals(project.tracks[2], child)
  lu.assertEquals(#child.items, 2)

  -- Depths untouched on reuse
  lu.assertEquals(src.folder_depth, 1)
  lu.assertEquals(child.folder_depth, -1)
end

function TestTrackExporter:testUnresolvableMatchesAreSkipped()
  local src = project.tracks[1]
  local result = make_exporter():export({
    accepted { source_track = src },
    accepted { source_track = nil },  -- resolve returns nil
  })

  lu.assertEquals(result.placed, 1)
  lu.assertEquals(result.skipped, 1)
  lu.assertEquals(#project.tracks, 3)
end

function TestTrackExporter:testRegionsLandWithNamesAndColors()
  local src = project.tracks[1]
  local result = make_exporter():export({
    accepted {
      source_track = src,
      timeline_start = 100.0, timeline_end = 102.0,
      confidence = 0.97,
      display_name = 'line001_take1.wav',
    },
  }, { regions = true })

  lu.assertEquals(result.regions, 1)
  lu.assertEquals(#result.region_ledger, 1)
  lu.assertEquals(result.region_ledger[1].name, 'line001_take1')

  local region = project.regions[result.region_ledger[1].id]
  lu.assertEquals(region.isrgn, true)
  lu.assertEquals(region.pos, 100.0)
  lu.assertEquals(region.rgnend, 102.0)
  lu.assertEquals(region.name, 'line001_take1')
  lu.assertEquals(region.color,
    reaper.ColorToNative(table.unpack(TrackExporter.COLOR_GREEN)) | 0x1000000)
end

-- Regions without tracks: opts.tracks = false lands the spans as
-- regions only - no child tracks, no items, sources left alone
function TestTrackExporter:testRegionsOnlyExportCreatesNoTracks()
  local src = project.tracks[1]
  local result = make_exporter():export({
    accepted { source_track = src, display_name = 'line001_take1.wav' },
  }, { tracks = false, regions = true })

  lu.assertEquals(result.placed, 0)
  lu.assertEquals(result.tracks, 0)
  lu.assertEquals(result.regions, 1)
  lu.assertEquals(#project.tracks, 2)
  lu.assertEquals(src.folder_depth, 0)

  local region = project.regions[result.region_ledger[1].id]
  lu.assertEquals(region.name, 'line001_take1')
end

function TestTrackExporter:testReexportReplacesOwnRegionsOnly()
  local src = project.tracks[1]
  local exporter = make_exporter()

  -- A pre-existing user region must survive every run
  local user_region_id = reaper.AddProjectMarker2(0, true, 5, 6, 'my cue', -1, 0)

  local first = exporter:export({
    accepted { source_track = src, guid = 'S1', display_name = 'a.wav' },
    accepted { source_track = src, guid = 'S2', display_name = 'b.wav' },
  }, { regions = true })
  lu.assertEquals(#region_ids(), 3)

  -- User renames one of ours: it is no longer provably ours, so the
  -- next run must leave it alone
  local kept_id = first.region_ledger[1].id
  project.regions[kept_id].name = 'mine now'

  local second = make_exporter():export({
    accepted { source_track = src, guid = 'S1', display_name = 'a.wav' },
    accepted { source_track = src, guid = 'S2', display_name = 'b.wav' },
  }, { regions = true, region_ledger = first.region_ledger })

  lu.assertEquals(second.regions, 2)
  -- user region + renamed survivor + 2 fresh = 4; NOT 5 (the
  -- still-ours region was replaced, not stacked)
  lu.assertEquals(#region_ids(), 4)
  lu.assertNotNil(project.regions[user_region_id])
  lu.assertEquals(project.regions[user_region_id].name, 'my cue')
  lu.assertNotNil(project.regions[kept_id])
end

function TestTrackExporter:testNoRegionsWithoutOptIn()
  local src = project.tracks[1]
  local result = make_exporter():export({ accepted { source_track = src } })

  lu.assertEquals(result.regions, 0)
  lu.assertNil(result.region_ledger)
  lu.assertEquals(#region_ids(), 0)
end

function TestTrackExporter:testConfidenceHeatmapColors()
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.99 }),
    TrackExporter.COLOR_GREEN)
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.95 }),
    TrackExporter.COLOR_GREEN)
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.70 }),
    TrackExporter.COLOR_AMBER)
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.30 }),
    TrackExporter.COLOR_AMBER)

  -- Midpoint lerps channel-wise between amber and green
  local mid = TrackExporter.item_color({ confidence = 0.825 })
  for i = 1, 3 do
    local amber, green = TrackExporter.COLOR_AMBER[i], TrackExporter.COLOR_GREEN[i]
    lu.assertEquals(mid[i], math.floor(amber + (green - amber) * 0.5 + 0.5))
  end

  -- Outside tints trump confidence
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.99, long_shot = true }),
    TrackExporter.COLOR_LONG_SHOT)
  lu.assertEquals(TrackExporter.item_color({ confidence = 0.99, time_adjusted = true }),
    TrackExporter.COLOR_TIME_ADJUSTED)
  -- Long shot beats time adjusted when both apply
  lu.assertEquals(
    TrackExporter.item_color({ long_shot = true, time_adjusted = true }),
    TrackExporter.COLOR_LONG_SHOT)
end

function TestTrackExporter:testTakeNameFallsBackToLineText()
  lu.assertEquals(
    TrackExporter.take_name({ needle_content = 'Hello there' }, 'line1_take1.wav'),
    'line1_take1')
  lu.assertEquals(
    TrackExporter.take_name({ needle_content = 'Hello there' }, nil),
    'Hello there')
  lu.assertEquals(TrackExporter.take_name({}, ''), '')
end

--

os.exit(lu.LuaUnit.run())
