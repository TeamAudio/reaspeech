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

  -- Copied from whisper.tokenizer.LANGUAGES
  LANGUAGES = {
    en = 'english', zh = 'chinese', de = 'german',
    es = 'spanish', ru = 'russian', ko = 'korean',
    fr = 'french', ja = 'japanese', pt = 'portuguese',
    tr = 'turkish', pl = 'polish', ca = 'catalan',
    nl = 'dutch', ar = 'arabic', sv = 'swedish',
    it = 'italian', id = 'indonesian', hi = 'hindi',
    fi = 'finnish', vi = 'vietnamese', he = 'hebrew',
    uk = 'ukrainian', el = 'greek', ms = 'malay',
    cs = 'czech', ro = 'romanian', da = 'danish',
    hu = 'hungarian', ta = 'tamil', no = 'norwegian',
    th = 'thai', ur = 'urdu', hr = 'croatian',
    bg = 'bulgarian', lt = 'lithuanian', la = 'latin',
    mi = 'maori', ml = 'malayalam', cy = 'welsh',
    sk = 'slovak', te = 'telugu', fa = 'persian',
    lv = 'latvian', bn = 'bengali', sr = 'serbian',
    az = 'azerbaijani', sl = 'slovenian', kn = 'kannada',
    et = 'estonian', mk = 'macedonian', br = 'breton',
    eu = 'basque', is = 'icelandic', hy = 'armenian',
    ne = 'nepali', mn = 'mongolian', bs = 'bosnian',
    kk = 'kazakh', sq = 'albanian', sw = 'swahili',
    gl = 'galician', mr = 'marathi', pa = 'punjabi',
    si = 'sinhala', km = 'khmer', sn = 'shona',
    yo = 'yoruba', so = 'somali', af = 'afrikaans',
    oc = 'occitan', ka = 'georgian', be = 'belarusian',
    tg = 'tajik', sd = 'sindhi', gu = 'gujarati',
    am = 'amharic', yi = 'yiddish', lo = 'lao',
    uz = 'uzbek', fo = 'faroese', ht = 'haitian creole',
    ps = 'pashto', tk = 'turkmen', nn = 'nynorsk',
    mt = 'maltese', sa = 'sanskrit', lb = 'luxembourgish',
    my = 'myanmar', bo = 'tibetan', tl = 'tagalog',
    mg = 'malagasy', as = 'assamese', tt = 'tatar',
    haw = 'hawaiian', ln = 'lingala', ha = 'hausa',
    ba = 'bashkir', jw = 'javanese', su = 'sundanese'
  },
  LANGUAGE_CODES = {},
  DEFAULT_LANGUAGE = 'en',

  ITEM_WIDTH = 125,
  LARGE_ITEM_WIDTH = 375,
}

function ReaSpeechUI:init()
  self.onerror = function (e)
    self:log(e)
  end

  self.disabler = ReaUtil.disabler(ctx, self.onerror)

  self.requests = {}
  self.responses = {}
  self.logs = {}

  self.log_enable = true
  self.log_debug = true

  ReaSpeechAPI:init('http://' .. Script.host)

  self.worker = ReaSpeechWorker.new({
    requests = self.requests,
    responses = self.responses,
    logs = self.logs,
  })

  self.product_activation = ReaSpeechProductActivation.new()
  self.license_input = ''

  self.language = self.DEFAULT_LANGUAGE
  self.translate = false
  self.initial_prompt = ''
  self.model_name = nil

  self.transcript = Transcript.new()
  self.transcript_ui = TranscriptUI.new { transcript = self.transcript }
  self.react_handlers = self:get_react_handlers()
end

ReaSpeechUI._init_languages = function ()
  for code, _ in pairs(ReaSpeechUI.LANGUAGES) do
    table.insert(ReaSpeechUI.LANGUAGE_CODES, code)
  end

  table.sort(ReaSpeechUI.LANGUAGE_CODES, function (a, b)
    return ReaSpeechUI.LANGUAGES[a] < ReaSpeechUI.LANGUAGES[b]
  end)

  table.insert(ReaSpeechUI.LANGUAGE_CODES, 1, '')
  ReaSpeechUI.LANGUAGES[''] = 'detect'
end

ReaSpeechUI._init_languages()

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
    function() self:handle_interval_functions(reaper.time_precise()) end,
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
    if dbg and self.log_enable and self.log_debug then
      reaper.ShowConsoleMsg(self:log_time() .. ' [DBG] ' .. tostring(msg) .. '\n')
    elseif not dbg and self.log_enable then
      reaper.ShowConsoleMsg(self:log_time() .. ' [LOG] ' .. tostring(msg) .. '\n')
    end
  end

  self.logs = {}
end

function ReaSpeechUI:interval_functions()
  if self._interval_functions then
    return self._interval_functions
  end

  self._interval_functions = {
    -- IntervalFunction.new(5, function()
    --   -- run no more often than once every 5 seconds
    --   -- chill interval to check on states that don't
    --   -- need to feel so snappy
    -- end),

    -- IntervalFunction.new(-15, function ()
    --   -- run every 15 ticks, ~0.5 seconds
    --   -- maybe a good interval for updating some states
    --   -- in a way that feels responsive, like selections
    -- end)
  }

  return self._interval_functions
end

function ReaSpeechUI:handle_interval_functions(time)
  local fs = self:interval_functions()
  for i = 1, #fs do
    fs[i]:react(time)
  end
end

IntervalFunction = Polo {
  new = function(interval, f)
    return {
      interval = interval,
      f = f,
      last = 0
    }
  end
}

function IntervalFunction:react(time)
  if self.interval >= 0 then
    if time - self.last >= self.interval then
      self.f()
      self.last = time
    end
  else
    self.last = self.last - 1

    if self.last < self.interval then
      self.f()
      self.last = 0
    end
  end
end

function ReaSpeechUI:render()
  ImGui.PushItemWidth(ctx, self.ITEM_WIDTH)

  self:trap(function ()
    if self.product_activation.state ~= "activated" then
      self:render_activation_inputs()
      return
    end

    if not self.product_activation.config:get('eula_signed') then
      self:render_EULA_inputs()
      return
    end

    self:render_main()
  end)

  ImGui.PopItemWidth(ctx)
end

function ReaSpeechUI:render_main()
  self:render_inputs()
  self:render_actions()
  self.transcript_ui:render()
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

function ReaSpeechUI:render_inputs()
  --start input table so logo and inputs sit side-by-side
  if ImGui.BeginTable(ctx, 'InputTable', 2) then
    self:trap(function()
      --column settings
      ImGui.TableSetupColumn(ctx, 'Logo',ImGui.TableColumnFlags_WidthFixed())
      ImGui.TableSetupColumn(ctx, 'Inputs',ImGui.TableColumnFlags_WidthFixed())
      -- first column
      ImGui.TableNextColumn(ctx)
      ImGui.SameLine(ctx, -10)
      app.png_from_bytes('reaspeech-logo-small')
      -- second column
      ImGui.TableNextColumn(ctx)
      -- start language selection
      self:render_language_controls()
      ImGui.Dummy(ctx,0, 10)
      self:render_advanced_controls()
    end)
    ImGui.EndTable(ctx)
  end
  -- end input table
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH + 65)
  app.png_from_bytes('heading-logo-tech-audio')
end

function ReaSpeechUI:render_language_controls()
  if ImGui.TreeNode(ctx, 'Language Options', ImGui.TreeNodeFlags_DefaultOpen()) then
    self:trap(function()
      ImGui.Dummy(ctx, 0, 25)
      ImGui.SameLine(ctx)
      if ImGui.BeginCombo(ctx, "language", self.LANGUAGES[self.language]) then
        self:trap(function()
          local combo_items = self.LANGUAGE_CODES
          for _, combo_item in pairs(combo_items) do
            local is_selected = (combo_item == self.language)
            if ImGui.Selectable(ctx, self.LANGUAGES[combo_item], is_selected) then
              self.language = combo_item
            end
          end
        end)
        ImGui.EndCombo(ctx)
      end
      local rv, value
      ImGui.SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, "translate", self.translate)
      if rv then
        self.translate = value
      end
    end)

    ImGui.TreePop(ctx)
  end
end

function ReaSpeechUI:render_advanced_controls()
  local rv, value

  if ImGui.TreeNode(ctx, 'Advanced Options') then
    self:trap(function()
      ImGui.Dummy(ctx, 0, 25)

      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
      self:trap(function ()
        rv, value = ImGui.InputText(ctx, 'initial prompt', self.initial_prompt)
        if rv then
          self.initial_prompt = value
        end
      end)
      ImGui.PopItemWidth(ctx)

      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, 100)
      self:trap(function ()
        rv, value = ImGui.InputTextWithHint(ctx, 'model name', self.model_name or "<default>")
        if rv then
          self.model_name = value
        end
      end)
      ImGui.PopItemWidth(ctx)

      ImGui.SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, "log", self.log_enable)
      if rv then
        self.log_enable = value
      end

      if self.log_enable then
        ImGui.SameLine(ctx)
        rv, value = ImGui.Checkbox(ctx, "debug", self.log_debug)
        if rv then
          self.log_debug = value
        end
      end
    end)

    ImGui.TreePop(ctx)
    ImGui.Spacing(ctx)
  end
end

function ReaSpeechUI:render_activation_inputs()
  ImGui.Text(ctx, ('Welcome to ReaSpeech by Tech Audio'))
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
  ImGui.Text(ctx, ('Please enter your license key to get started'))
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 5)
  ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
  self:trap(function ()
    local rv, value = ImGui.InputText(ctx, '##', self.license_input)
    if rv then
      self.license_input = value
    end
    if self.product_activation.activation_message ~= "" then
      --Possibly make this ColorText with and change depending on message
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, self.product_activation.activation_message)
    end
  end)
  ImGui.PopItemWidth(ctx)
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 30)
  if ImGui.Button(ctx, "Submit") then
    self:handle_product_activation(self.license_input)
  end
end

function ReaSpeechUI:render_EULA_inputs()
  ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
  self:trap(function ()
    ImGui.Text(ctx, ('EULA'))
    ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
    ImGui.TextWrapped(ctx, ReaSpeechEULAContent)
    ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
     if ImGui.Button(ctx, "Agree") then
      self.product_activation.config:set('eula_signed', true)
    end
  end)
  ImGui.PopItemWidth(ctx)
end

function ReaSpeechUI:handle_product_activation(input_license)
  --reaper.ShowConsoleMsg(tostring(input_license) .. '\n')
  self.product_activation:handle_product_activation(input_license)
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
  local request = {
    language = self.language,
    translate = self.translate,
    initial_prompt = self.initial_prompt,
    model_name = self.model_name,
    jobs = jobs,
  }
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
