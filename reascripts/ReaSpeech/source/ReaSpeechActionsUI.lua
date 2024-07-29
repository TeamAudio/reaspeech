--[[

ReaSpeechActionsUI.lua - Main action bar UI in ReaSpeech

]]--

ReaSpeechActionsUI = Polo {}

function ReaSpeechActionsUI:init()
  self.disabler = ReaUtil.disabler(ctx)
end

function ReaSpeechActionsUI.pluralizer(count, suffix)
  if count == 0 then
    return '', suffix
  elseif count == 1 then
    return '1', ''
  else
    return '', suffix
  end
end

function ReaSpeechActionsUI:render()
  local disable_if = self.disabler
  local progress = self.worker:progress()

  disable_if(progress, function()
    local selected_track_count = reaper.CountSelectedTracks(ReaUtil.ACTIVE_PROJECT)
    disable_if(selected_track_count == 0, function()
      local button_text = ("Process %s Selected Track%s")
        :format(self.pluralizer(selected_track_count, 's'))

      if ImGui.Button(ctx, button_text) then
        self:process_jobs(self.jobs_for_selected_tracks)
      end
    end)

    ImGui.SameLine(ctx)

    local selected_item_count = reaper.CountSelectedMediaItems(ReaUtil.ACTIVE_PROJECT)
    disable_if(selected_item_count == 0, function()
      local button_text = ("Process %s Selected Item%s")
        :format(self.pluralizer(selected_item_count, 's'))

      if ImGui.Button(ctx, button_text) then
        self:process_jobs(self.jobs_for_selected_items)
      end
    end)

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Process All Items") then
      self:process_jobs(self.jobs_for_all_items)
    end
  end)

  if progress then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel") then
      self.worker:cancel()
    end

    ImGui.SameLine(ctx)
    local overlay = string.format("%.0f%%", progress * 100)
    local status = self.worker:status()
    if status then
      overlay = overlay .. ' - ' .. status
    end
    ImGui.ProgressBar(ctx, progress, nil, nil, overlay)
  end
end

function ReaSpeechActionsUI.make_job(media_item, take)
  local path = ReaSpeechUI.get_source_path(take)

  if path then
    return {item = media_item, take = take, path = path}
  else
    return nil
  end
end

function ReaSpeechActionsUI.jobs_for_selected_tracks()
  local jobs = {}
  for track in ReaIter.each_selected_track() do
    for item in ReaIter.each_track_item(track) do
      for take in ReaIter.each_take(item) do
        local job = ReaSpeechActionsUI.make_job(item, take)
        if job then
          table.insert(jobs, job)
        end
      end
    end
  end
  return jobs
end

function ReaSpeechActionsUI.jobs_for_selected_items()
  local jobs = {}
  for item in ReaIter.each_selected_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ReaSpeechActionsUI.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end

function ReaSpeechActionsUI.jobs_for_all_items()
  local jobs = {}
  for item in ReaIter.each_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ReaSpeechActionsUI.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end

function ReaSpeechActionsUI:process_jobs(job_generator)
  local jobs = job_generator()

  if #jobs == 0 then
    reaper.MB("No media found to process.", "No media", 0)
    return
  end

  app.transcript:clear()

  app:new_jobs(jobs, function(response)
    if not response.segments then
      return
    end

    for _, segment in pairs(response.segments) do
      for _, s in pairs(
        TranscriptSegment.from_whisper(segment, response._job.item, response._job.take)
      ) do
        if s:get('text') then
          app.transcript:add_segment(s)
        end
      end
    end

    app.transcript:update()
  end)
end
