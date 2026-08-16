--[[

  TrackExporter.lua - land accepted matches in the project as tracks

  The second export target: each source track with accepted matches
  gets a CHILD track holding just the matched sections as distinct
  media items at their timeline positions. Items reference the
  ORIGINAL source files with take start offsets - no new audio is
  written to disk. The source stays long and contiguous; its child is
  spotty.

  Child placement is deliberate: children route through their parent,
  so soloing a matched item auditions through the source's exact FX
  chain and fader. Because the matched spans double the source audio
  in any shared mix path, the child is created MUTED - the heatmap
  stays visible, playback and stem renders stay clean, and auditioning
  is a solo away. Source item and take gain are copied onto matched
  items so they audition at the source's loudness.

  The timeline doubles as a curation heatmap: item colors run green
  (high confidence) to amber (the auto-accept floor), long shots fly
  pink, and time-adjusted windows get their own tint. Take names come
  from the filename template; item notes carry the script line, the
  matched transcript text, and the confidence.

  Optionally the same spans land as named, heatmap-colored project
  REGIONS - the ruler becomes the heatmap too, and REAPER's region
  render matrix can batch-render matches. A ledger of created region
  ids travels with the caller; on re-export we delete only regions
  whose id AND current name both match the ledger (never delete a
  region we can't prove is ours), then recreate.

  Matched tracks are tagged via P_EXT with the session and source
  track they mirror, so re-exports refill the same tracks instead of
  stacking new ones.

  Caveat: items are placed at SuggestionTimeline's resolved positions
  with unit playrate; a source item playing at a non-1 rate will land
  at the right position but play at the file's natural rate.

]]--

TrackExporter = Polo {
  EXT_KEY = 'P_EXT:ReaSpeech_SM_Matches',

  -- Confidence heatmap endpoints (RGB), lerped between the floor and
  -- the ceiling; outside tints override
  COLOR_GREEN = { 0x4C, 0xAF, 0x50 },      -- at/above CONF_CEILING
  COLOR_AMBER = { 0xFF, 0xB7, 0x4D },      -- at/below CONF_FLOOR
  COLOR_LONG_SHOT = { 0xE2, 0x40, 0x97 },  -- theme pink: a gamble on the timeline
  COLOR_TIME_ADJUSTED = { 0x4F, 0xA8, 0xD8 },
  CONF_FLOOR = 0.70,
  CONF_CEILING = 0.95,
}

function TrackExporter:init()
  Logging().init(self, 'TrackExporter')

  assert(self.session_id, 'TrackExporter: session_id is required')

  self:log('Initialized TrackExporter')
end

-- Export a flat list of export items (as built by ExportDataService:
-- each carries .match and a template-resolved .display_name) onto
-- child tracks. opts.tracks = false skips the tracks and lands only
-- what else was asked for (regions need no tracks to exist).
-- opts.regions lands the spans as project regions too;
-- opts.region_ledger is the previous run's ledger to replace.
-- Returns { placed, skipped, tracks, regions, region_ledger }.
function TrackExporter:export(export_items, opts)
  local placed, skipped = 0, 0
  local children = {}
  local region_records = {}
  local tracks_on = not (opts and opts.tracks == false)

  reaper.Undo_BeginBlock()

  for _, item in ipairs(export_items or {}) do
    local match = item.match or item
    local resolved = SuggestionTimeline.resolve(match)

    if resolved and resolved.source_path and resolved.source_path ~= '' then
      local name = TrackExporter.take_name(match, item.display_name)

      if tracks_on then
        local child = self:matched_track_for(resolved.track, children)
        self:place_item(child, match, resolved, name)
        placed = placed + 1
      end

      table.insert(region_records, {
        start_time = resolved.start_time,
        end_time = resolved.end_time,
        name = name,
        color = TrackExporter.item_color(match),
      })
    else
      skipped = skipped + 1
      self:log('Track export: could not resolve match '
        .. tostring(match.guid) .. ' to the timeline; skipped')
    end
  end

  local result = { placed = placed, skipped = skipped, regions = 0 }

  local track_count = 0
  for _ in pairs(children) do track_count = track_count + 1 end
  result.tracks = track_count

  if opts and opts.regions then
    result.region_ledger = self:replace_regions(region_records, opts.region_ledger)
    result.regions = #result.region_ledger
  end

  reaper.Undo_EndBlock(tracks_on and 'ReaSpeech: export matches to tracks'
    or 'ReaSpeech: export match regions', -1)
  reaper.UpdateArrange()

  self:log(('Track export: %d items on %d tracks, %d regions, %d skipped')
    :format(placed, result.tracks, result.regions, skipped))

  return result
end

-- Find or create the matched-track child for a source track, once per
-- run. Reused tracks (tagged with this session + source in P_EXT) are
-- emptied first: a re-export replaces its previous landing.
function TrackExporter:matched_track_for(source_track, children)
  local source_guid = reaper.GetTrackGUID(source_track)
  if children[source_guid] then return children[source_guid] end

  local tag = self.session_id .. '|' .. source_guid
  local child = self:find_tagged_track(tag)

  if child then
    self:clear_track_items(child)
  else
    -- IP_TRACKNUMBER is 1-based; inserting at that 0-based index
    -- lands the new track directly under its source
    local source_number = math.floor(
      reaper.GetMediaTrackInfo_Value(source_track, 'IP_TRACKNUMBER'))
    reaper.InsertTrackAtIndex(source_number, true)
    child = reaper.GetTrack(0, source_number)

    -- Parent the child under its source: the source becomes a folder
    -- parent (unless it already is one, where the new track lands as
    -- its first child by position alone), and the child takes over
    -- any folder-closing duties the source had - one level deeper,
    -- since it also closes the source's new folder. Without this a
    -- folder-closing source (negative depth) would close its folder
    -- before the new track and strand it outside.
    local source_depth = reaper.GetMediaTrackInfo_Value(
      source_track, 'I_FOLDERDEPTH')
    if source_depth <= 0 then
      reaper.SetMediaTrackInfo_Value(source_track, 'I_FOLDERDEPTH', 1)
      reaper.SetMediaTrackInfo_Value(child, 'I_FOLDERDEPTH', source_depth - 1)
    end

    -- Muted from birth: matched spans double the source audio in any
    -- shared mix path, so the heatmap arrives silent - solo to
    -- audition. Only at creation; a re-export respects the user's
    -- current mute state.
    reaper.SetMediaTrackInfo_Value(child, 'B_MUTE', 1)

    local _, source_name = reaper.GetSetMediaTrackInfo_String(
      source_track, 'P_NAME', '', false)
    reaper.GetSetMediaTrackInfo_String(child, 'P_NAME',
      ('%s (matched)'):format(source_name), true)
    reaper.GetSetMediaTrackInfo_String(child, TrackExporter.EXT_KEY, tag, true)
  end

  children[source_guid] = child
  return child
end

function TrackExporter:find_tagged_track(tag)
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, value = reaper.GetSetMediaTrackInfo_String(
      track, TrackExporter.EXT_KEY, '', false)
    if value == tag then
      return track
    end
  end
end

function TrackExporter:clear_track_items(track)
  for i = reaper.CountTrackMediaItems(track) - 1, 0, -1 do
    reaper.DeleteTrackMediaItem(track, reaper.GetTrackMediaItem(track, i))
  end
end

-- One media item: positioned at the resolved timeline span, its take
-- playing the original source file from the match's file-relative
-- start offset, at the source item's gain
function TrackExporter:place_item(track, match, resolved, take_name)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemInfo_Value(item, 'D_POSITION', resolved.start_time)
  reaper.SetMediaItemInfo_Value(item, 'D_LENGTH',
    resolved.end_time - resolved.start_time)
  reaper.SetMediaItemInfo_Value(item, 'D_VOL', resolved.item_volume or 1)
  reaper.SetMediaItemInfo_Value(item, 'I_CUSTOMCOLOR',
    reaper.ColorToNative(table.unpack(TrackExporter.item_color(match))) | 0x1000000)
  reaper.GetSetMediaItemInfo_String(item, 'P_NOTES',
    TrackExporter.item_notes(match), true)

  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take,
    reaper.PCM_Source_CreateFromFile(resolved.source_path))
  reaper.SetMediaItemTakeInfo_Value(take, 'D_STARTOFFS', match.start_time)
  reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL', resolved.take_volume or 1)
  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)

  return item
end

-- Replace our previous regions with this run's spans. The ledger
-- records { id, name } per region we created; deletion requires BOTH
-- to still match, so a region the user renamed, renumbered, or
-- replaced with their own survives us. (Lesson of the 170k-marker
-- era: annotation exports must converge, and must only ever touch
-- what is provably theirs.)
function TrackExporter:replace_regions(records, old_ledger)
  local current = {}
  local i = 0
  while true do
    local retval, isrgn, _, _, name, index = reaper.EnumProjectMarkers3(0, i)
    if retval == 0 then break end
    if isrgn then current[index] = name end
    i = i + 1
  end

  for _, entry in ipairs(old_ledger or {}) do
    if current[entry.id] == entry.name then
      reaper.DeleteProjectMarker(0, entry.id, true)
    end
  end

  local ledger = {}
  for _, record in ipairs(records) do
    local color = reaper.ColorToNative(table.unpack(record.color)) | 0x1000000
    local id = reaper.AddProjectMarker2(0, true,
      record.start_time, record.end_time, record.name, -1, color)
    table.insert(ledger, { id = id, name = record.name })
  end
  return ledger
end

-- The heatmap: long shots pink, hand-adjusted windows their own tint,
-- everything else green -> amber by confidence
function TrackExporter.item_color(match)
  if match.long_shot then return TrackExporter.COLOR_LONG_SHOT end
  if match.time_adjusted then return TrackExporter.COLOR_TIME_ADJUSTED end

  local floor_, ceiling = TrackExporter.CONF_FLOOR, TrackExporter.CONF_CEILING
  local confidence = match.confidence or 0
  local t = (confidence - floor_) / (ceiling - floor_)
  t = math.max(0, math.min(1, t))

  local color = {}
  for i = 1, 3 do
    color[i] = math.floor(
      TrackExporter.COLOR_AMBER[i]
      + (TrackExporter.COLOR_GREEN[i] - TrackExporter.COLOR_AMBER[i]) * t
      + 0.5)
  end
  return color
end

-- Takes are labeled by the filename template (sans extension), so the
-- timeline reads like the export tree
function TrackExporter.take_name(match, display_name)
  if display_name and display_name ~= '' then
    return (display_name:gsub('%.%w+$', ''))
  end
  return match.needle_content or ''
end

-- Hover an item in REAPER, know everything
function TrackExporter.item_notes(match)
  local lines = {}
  if match.needle_content and match.needle_content ~= '' then
    table.insert(lines, 'Line: ' .. match.needle_content)
  end
  if match.matching_text and match.matching_text ~= '' then
    table.insert(lines, 'Matched: "' .. match.matching_text .. '"')
  end
  if match.confidence then
    table.insert(lines, ('Confidence: %d%%'):format(
      math.floor(match.confidence * 100 + 0.5)))
  end
  if match.long_shot then
    table.insert(lines, 'Long shot')
  end
  if match.time_adjusted then
    table.insert(lines, 'Time adjusted by hand')
  end
  return table.concat(lines, '\n')
end
