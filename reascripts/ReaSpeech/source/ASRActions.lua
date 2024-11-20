--[[

  ASRActions.lua - Actions for ASR plugin

]]--

ASRActions = PluginActions {
  actions = function(self)
    return {
      self:selected_tracks_button(),
      self:selected_items_button(),
      self:all_items_button(),
      self:import_button(),
    }
  end
}

function ASRActions:init()
  assert(self.plugin, 'ASRActions: plugin is required')

  Logging.init(self, 'ASRActions')

  self.disabler = ReaUtil.disabler(ctx)
end

function ASRActions:selected_tracks_button()
  local selected_track_count = reaper.CountSelectedTracks(ReaUtil.ACTIVE_PROJECT)

  if self._selected_track_count and selected_track_count == self._selected_track_count then
    return self._selected_tracks_button
  end

  self._selected_track_count = selected_track_count

  if selected_track_count == 0 then
    self._selected_tracks_button = ReaSpeechButton.new({
      label = "Process Selected Tracks",
      disabled = true,
    })
    return self._selected_tracks_button
  end

  local button_text = ("Process %sSelected Track%s")
    :format(self.pluralizer(selected_track_count, 's'))

  self._selected_tracks_button = ReaSpeechButton.new({
    label = button_text,
    on_click = function ()
      self:process_jobs(self.jobs_for_selected_tracks)
    end,
  })

  return self._selected_tracks_button
end

function ASRActions:selected_items_button()
  local selected_item_count = reaper.CountSelectedMediaItems(ReaUtil.ACTIVE_PROJECT)

  if self._selected_item_count and selected_item_count == self._selected_item_count then
    return self._selected_items_button
  end

  self._selected_item_count = selected_item_count

  if selected_item_count == 0 then
    self._selected_items_button = ReaSpeechButton.new({
      label = "Process Selected Items",
      disabled = true,
    })
    return self._selected_items_button
  end

  local button_text = ("Process %sSelected Item%s")
    :format(self.pluralizer(selected_item_count, 's'))

  self._selected_items_button = ReaSpeechButton.new({
    label = button_text,
    on_click = function ()
      self:process_jobs(self.jobs_for_selected_items)
    end,
  })

  return self._selected_items_button
end

function ASRActions:all_items_button()
  if self._all_items_button then
    return self._all_items_button
  end

  self._all_items_button = ReaSpeechButton.new({
    label = "Process All Items",
    on_click = function ()
      self:process_jobs(self.jobs_for_all_items)
    end,
  })

  return self._all_items_button
end

function ASRActions:import_button()
  if self._import_button then
    return self._import_button
  end

  self._import_button = ReaSpeechButton.new({
    label = "Import Transcript",
    on_click = function () app.importer:open() end
  })

  return self._import_button
end

function ASRActions.pluralizer(count, suffix)
  if count == 0 then
    return '', suffix
  elseif count == 1 then
    return '', ''
  else
    return count .. ' ', suffix
  end
end

function ASRActions:process_jobs(job_generator)
  local jobs = job_generator()

  if #jobs == 0 then
    reaper.MB("No media found to process.", "No media", 0)
    return
  end

  self.plugin:asr(jobs)
end

function ASRActions.make_job(media_item, take)
  local path = ReaUtil.get_source_path(take)

  if path then
    return {item = media_item, take = take, path = path}
  else
    return nil
  end
end

function ASRActions.jobs_for_selected_tracks()
  local jobs = {}
  for track in ReaIter.each_selected_track() do
    for item in ReaIter.each_track_item(track) do
      for take in ReaIter.each_take(item) do
        local job = ASRActions.make_job(item, take)
        if job then
          table.insert(jobs, job)
        end
      end
    end
  end
  return jobs
end

function ASRActions.jobs_for_selected_items()
  local jobs = {}
  for item in ReaIter.each_selected_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ASRActions.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end

function ASRActions.jobs_for_all_items()
  local jobs = {}
  for item in ReaIter.each_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ASRActions.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end
