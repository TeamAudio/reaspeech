--[[

  ReaIter.lua - Reaper iterators

]]--

ReaIter = {}

ReaIter._make_iterator = function(count_f, item_f)
  return function(proj)
    proj = proj or 0
    local i = 0
    local n = count_f(proj)
    return function ()
      if i < n then
        local item = item_f(proj, i)
        i = i + 1
        return item
      end
    end
  end
end

ReaIter.each_media_item = ReaIter._make_iterator(reaper.CountMediaItems, reaper.GetMediaItem)

ReaIter.each_selected_media_item = ReaIter._make_iterator(reaper.CountSelectedMediaItems, reaper.GetSelectedMediaItem)

ReaIter.each_selected_track = ReaIter._make_iterator(reaper.CountSelectedTracks, reaper.GetSelectedTrack)

ReaIter.each_track = ReaIter._make_iterator(reaper.CountTracks, reaper.GetTrack)

ReaIter.each_take = ReaIter._make_iterator(reaper.CountTakes, reaper.GetTake)

ReaIter.each_track_item = ReaIter._make_iterator(reaper.CountTrackMediaItems, reaper.GetTrackMediaItem)
