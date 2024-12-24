--[[

  DetectLanguageActions.lua - Actions definitions for DetectLanguagePlugin

]]--

DetectLanguageActions = PluginActions {
  actions = function(self) return { self._button } end
}

function DetectLanguageActions:init()
  assert(self.plugin, 'DetectLanguageActions: plugin is required')
  Logging.init(self, 'DetectLanguageActions')
  self:init_button()
end

function DetectLanguageActions:init_button()
  self._button = Widgets.Button.new({
    label = "Label Track Languages",
    on_click = function()
      self:label_track_languages()
    end
  })
end

function DetectLanguageActions:label_track_languages()
  local selected_track_count = reaper.CountSelectedTracks(ReaUtil.ACTIVE_PROJECT)

  local iterator = selected_track_count > 0 and ReaIter.each_selected_track or ReaIter.each_track

  local jobs = {}
  for track in iterator() do
    for item in ReaIter.each_track_item(track) do
      for take in ReaIter.each_take(item) do
        local job = DetectLanguageActions.make_job(item, take)
        if job then
          table.insert(jobs, job)
        end
      end
    end
  end

  self.plugin:detect_language(jobs)
end

function DetectLanguageActions.make_job(media_item, take)
  local path = ReaUtil.get_source_path(take)

  if path then
    return {item = media_item, take = take, path = path}
  else
    return nil
  end
end
