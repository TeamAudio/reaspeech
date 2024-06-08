--[[

  ReaSpeechUI.lua - ReaSpeech user interface

]]--

ReaSpeechUI = Polo {
  VERSION = "unknown (development)",
  -- Set to show ImGui Metrics/Debugger window
  METRICS = false,

  TITLE = 'ReaSpeech',
  WIDTH = 1000,
  HEIGHT = 600,

  ITEM_WIDTH = 125,
}

function ReaSpeechUI:init()
  self.onerror = function (e)
    self:log(e)
  end

  self.disabler = ReaUtil.disabler(ctx, self.onerror)

  self.requests = {}
  self.responses = {}
  self.logs = {}

  ReaSpeechAPI:init('http://' .. Script.host)

  self.worker = ReaSpeechWorker.new({
    requests = self.requests,
    responses = self.responses,
    logs = self.logs,
  })

  self.product_activation = ReaSpeechProductActivation.new()
  self.product_activation_ui = ReaSpeechProductActivationUI.new {
    product_activation = self.product_activation
  }

  self.controls_ui = ReaSpeechControlsUI.new()

  self.transcript = Transcript.new()
  self.transcript_ui = TranscriptUI.new { transcript = self.transcript }

  self.failure = AlertPopup.new { title = 'Transcription Failed' }

  self.react_handlers = self:get_react_handlers()
end

ReaSpeechUI.config_flags = function ()
  return ImGui.ConfigFlags_DockingEnable()
end

ReaSpeechUI.log_time = function ()
  return os.date('%Y-%m-%d %H:%M:%S')
end

function ReaSpeechUI:log(msg)
  table.insert(self.logs, {msg, false})
end

function ReaSpeechUI:debug(msg)
  table.insert(self.logs, {msg, true})
end

function ReaSpeechUI:trap(f)
  return xpcall(f, self.onerror)
end

function ReaSpeechUI:has_js_ReaScriptAPI()
  if reaper.JS_Dialog_BrowseForSaveFile then
    return true
  end
  return false
end

function ReaSpeechUI:show_file_dialog(options)
  local title = options.title or 'Save file'
  local folder = options.folder or ''
  local file = options.file or ''
  local ext = options.ext or ''
  local save = options.save or false
  local multi = options.multi or false
  if self:has_js_ReaScriptAPI() then
    if save then
      return reaper.JS_Dialog_BrowseForSaveFile(title, folder, file, ext)
    else
      return reaper.JS_Dialog_BrowseForOpenFiles(title, folder, file, ext, multi)
    end
  else
    return nil
  end
end

function ReaSpeechUI:tooltip(text)
  if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal()) or
     not ImGui.BeginTooltip(ctx)
  then return end

  self:trap(function()
    ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 42)
    self:trap(function()
      ImGui.Text(ctx, text)
    end)
    ImGui.PopTextWrapPos(ctx)
  end)

  ImGui.EndTooltip(ctx)
end

function ReaSpeechUI:react()
  for _, handler in pairs(self.react_handlers) do
    self:trap(handler)
  end
end

function ReaSpeechUI:get_react_handlers()
  return {
    function() self:react_to_worker_response() end,
    function() self:react_to_logging() end,
    function() self.worker:react() end,
    function() self:render() end
  }
end

function ReaSpeechUI:react_to_worker_response()
  local response = table.remove(self.responses, 1)

  if not response then
    return
  end

  self:debug('Response: ' .. dump(response))

  if response.error then
    self.failure:show(response.error)
    self.worker:cancel()
    return
  end

  if not response.segments then
    return
  end

  for _, segment in pairs(response.segments) do
    for _, s in pairs(
      TranscriptSegment.from_whisper(segment, response._job.item, response._job.take)
    ) do
      if s:get('text') then
        self.transcript:add_segment(s)
      end
    end
  end

  self.transcript:update()
end

function ReaSpeechUI:react_to_logging()
  for _, log in pairs(self.logs) do
    local msg, dbg = table.unpack(log)
    if dbg and self.controls_ui.log_enable and self.controls_ui.log_debug then
      reaper.ShowConsoleMsg(self:log_time() .. ' [DBG] ' .. tostring(msg) .. '\n')
    elseif not dbg and self.controls_ui.log_enable then
      reaper.ShowConsoleMsg(self:log_time() .. ' [LOG] ' .. tostring(msg) .. '\n')
    end
  end

  self.logs = {}
end

function ReaSpeechUI:render()
  ImGui.PushItemWidth(ctx, self.ITEM_WIDTH)

  self:trap(function ()
    if self.product_activation:is_activated() then
      self:render_main()
    else
      self.product_activation_ui:render()
    end
  end)

  ImGui.PopItemWidth(ctx)
end

function ReaSpeechUI:render_main()
  self.controls_ui:render()
  self:render_actions()
  self.transcript_ui:render()
  self.failure:render()
end

function ReaSpeechUI.png_from_bytes(image_key)
  if not IMAGES[image_key] or not IMAGES[image_key].bytes then
    return
  end

  local image = IMAGES[image_key]

  if not ImGui.ValidatePtr(image.imgui_image, 'ImGui_Image*') then
    image.imgui_image = ImGui.CreateImageFromMem(image.bytes)
  end

  ImGui.Image(ctx, image.imgui_image, image.width, image.height)
end

function ReaSpeechUI:render_actions()
  local disable_if = self.disabler
  local progress = self.worker:progress()

  disable_if(progress, function()
    local selected_track_count = reaper.CountSelectedTracks(ReaUtil.ACTIVE_PROJECT)
    disable_if(selected_track_count == 0, function()
      local button_text

      if selected_track_count == 0 then
        button_text = "Process Selected Tracks"
      elseif selected_track_count == 1 then
        button_text = "Process 1 Selected Track"
      else
        button_text = string.format("Process %d Selected Tracks", selected_track_count)
      end

      if ImGui.Button(ctx, button_text) then
        self:process_jobs(ReaSpeechUI.jobs_for_selected_tracks)
      end
    end)

    ImGui.SameLine(ctx)

    local selected_item_count = reaper.CountSelectedMediaItems(ReaUtil.ACTIVE_PROJECT)
    disable_if(selected_item_count == 0, function()
      local button_text

      if selected_item_count == 0 then
        button_text = "Process Selected Items"
      elseif selected_item_count == 1 then
        button_text = "Process 1 Selected Item"
      else
        button_text = string.format("Process %d Selected Items", selected_item_count)
      end

      if ImGui.Button(ctx, button_text) then
        self:process_jobs(ReaSpeechUI.jobs_for_selected_items)
      end
    end)

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Process All Items") then
      self:process_jobs(ReaSpeechUI.jobs_for_all_items)
    end
  end)

  if progress then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel") then
      self.worker:cancel()
    end

    ImGui.SameLine(ctx)
    ImGui.ProgressBar(ctx, progress)
  end
  ImGui.Dummy(ctx,0, 5)
end

function ReaSpeechUI.make_job(media_item, take)
  local path = ReaSpeechUI.get_source_path(take)

  if path then
    return {item = media_item, take = take, path = path}
  else
    return nil
  end
end

function ReaSpeechUI.jobs_for_selected_tracks()
  local jobs = {}
  for track in ReaIter.each_selected_track() do
    for item in ReaIter.each_track_item(track) do
      for take in ReaIter.each_take(item) do
        local job = ReaSpeechUI.make_job(item, take)
        if job then
          table.insert(jobs, job)
        end
      end
    end
  end
  return jobs
end

function ReaSpeechUI.jobs_for_selected_items()
  local jobs = {}
  for item in ReaIter.each_selected_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ReaSpeechUI.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end

function ReaSpeechUI.jobs_for_all_items()
  local jobs = {}
  for item in ReaIter.each_media_item() do
    for take in ReaIter.each_take(item) do
      local job = ReaSpeechUI.make_job(item, take)
      if job then
        table.insert(jobs, job)
      end
    end
  end
  return jobs
end

function ReaSpeechUI:process_jobs(job_generator)
  local jobs = job_generator()

  if #jobs == 0 then
    reaper.MB("No media found to process.", "No media", 0)
    return
  end

  local request = self.controls_ui:get_request_data()
  request.jobs = jobs
  self:debug('Request: ' .. dump(request))

  self.transcript:clear()
  table.insert(self.requests, request)
end

function ReaSpeechUI.get_source_path(take)
  local source = reaper.GetMediaItemTake_Source(take)
  if source then
    local source_path = reaper.GetMediaSourceFileName(source)
    return source_path
  end
  return nil
end
