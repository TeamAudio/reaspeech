--[[

  ReaSpeechUI.lua - ReaSpeech user interface

]]--

ReaSpeechUI = {
  VERSION = "unknown (development)",
  -- Set to show ImGui Metrics/Debugger window
  METRICS = false,

  TITLE = 'ReaSpeech',
  WIDTH = 1000,
  HEIGHT = 600,

  -- Copied from whisper.tokenizer.LANGUAGES
  LANGUAGES = {
    ['en'] = 'english', ['zh'] = 'chinese', ['de'] = 'german',
    ['es'] = 'spanish', ['ru'] = 'russian', ['ko'] = 'korean',
    ['fr'] = 'french', ['ja'] = 'japanese', ['pt'] = 'portuguese',
    ['tr'] = 'turkish', ['pl'] = 'polish', ['ca'] = 'catalan',
    ['nl'] = 'dutch', ['ar'] = 'arabic', ['sv'] = 'swedish',
    ['it'] = 'italian', ['id'] = 'indonesian', ['hi'] = 'hindi',
    ['fi'] = 'finnish', ['vi'] = 'vietnamese', ['he'] = 'hebrew',
    ['uk'] = 'ukrainian', ['el'] = 'greek', ['ms'] = 'malay',
    ['cs'] = 'czech', ['ro'] = 'romanian', ['da'] = 'danish',
    ['hu'] = 'hungarian', ['ta'] = 'tamil', ['no'] = 'norwegian',
    ['th'] = 'thai', ['ur'] = 'urdu', ['hr'] = 'croatian',
    ['bg'] = 'bulgarian', ['lt'] = 'lithuanian', ['la'] = 'latin',
    ['mi'] = 'maori', ['ml'] = 'malayalam', ['cy'] = 'welsh',
    ['sk'] = 'slovak', ['te'] = 'telugu', ['fa'] = 'persian',
    ['lv'] = 'latvian', ['bn'] = 'bengali', ['sr'] = 'serbian',
    ['az'] = 'azerbaijani', ['sl'] = 'slovenian', ['kn'] = 'kannada',
    ['et'] = 'estonian', ['mk'] = 'macedonian', ['br'] = 'breton',
    ['eu'] = 'basque', ['is'] = 'icelandic', ['hy'] = 'armenian',
    ['ne'] = 'nepali', ['mn'] = 'mongolian', ['bs'] = 'bosnian',
    ['kk'] = 'kazakh', ['sq'] = 'albanian', ['sw'] = 'swahili',
    ['gl'] = 'galician', ['mr'] = 'marathi', ['pa'] = 'punjabi',
    ['si'] = 'sinhala', ['km'] = 'khmer', ['sn'] = 'shona',
    ['yo'] = 'yoruba', ['so'] = 'somali', ['af'] = 'afrikaans',
    ['oc'] = 'occitan', ['ka'] = 'georgian', ['be'] = 'belarusian',
    ['tg'] = 'tajik', ['sd'] = 'sindhi', ['gu'] = 'gujarati',
    ['am'] = 'amharic', ['yi'] = 'yiddish', ['lo'] = 'lao',
    ['uz'] = 'uzbek', ['fo'] = 'faroese', ['ht'] = 'haitian creole',
    ['ps'] = 'pashto', ['tk'] = 'turkmen', ['nn'] = 'nynorsk',
    ['mt'] = 'maltese', ['sa'] = 'sanskrit', ['lb'] = 'luxembourgish',
    ['my'] = 'myanmar', ['bo'] = 'tibetan', ['tl'] = 'tagalog',
    ['mg'] = 'malagasy', ['as'] = 'assamese', ['tt'] = 'tatar',
    ['haw'] = 'hawaiian', ['ln'] = 'lingala', ['ha'] = 'hausa',
    ['ba'] = 'bashkir', ['jw'] = 'javanese', ['su'] = 'sundanese'
  },
  LANGUAGE_CODES = {},
  DEFAULT_LANGUAGE = 'en',

  FLOAT_FORMAT = '%.4f',

  COLUMN_WIDTH = 55,
  LARGE_COLUMN_WIDTH = 300,

  ITEM_WIDTH = 125,
  LARGE_ITEM_WIDTH = 375,
}

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

ReaSpeechUI.table_flags = function (sortable)
  local sort_flags = 0
  if sortable then
    sort_flags = ImGui.TableFlags_Sortable() | ImGui.TableFlags_SortTristate()
  end
  return (
    sort_flags
    | ImGui.TableFlags_Borders()
    | ImGui.TableFlags_Hideable()
    | ImGui.TableFlags_Resizable()
    | ImGui.TableFlags_Reorderable()
    | ImGui.TableFlags_RowBg()
    | ImGui.TableFlags_ScrollX()
    | ImGui.TableFlags_ScrollY()
    | ImGui.TableFlags_SizingFixedFit()
  )
end

ReaSpeechUI.log_time = function ()
  return os.date('%Y-%m-%d %H:%M:%S')
end

ReaSpeechUI.__index = ReaSpeechUI
ReaSpeechUI.new = function (o)
  o = o or {}
  setmetatable(o, ReaSpeechUI)
  o:init()
  return o
end

function ReaSpeechUI:init()
  self.onerror = function (e)
    self:log(e)
  end

  self.requests = {}
  self.responses = {}
  self.logs = {}

  self.log_enable = false
  self.log_debug = false

  self.words = false
  self.colorize_words = false
  self.autoplay = true

  self.worker = ReaSpeechWorker.new({
    requests = self.requests,
    responses = self.responses,
    logs = self.logs,
    asr_url = 'http://' .. Script.host .. '/asr',
  })

  self.language = self.DEFAULT_LANGUAGE
  self.translate = false
  self.initial_prompt = ''

  self.transcript = Transcript.new()
  self.transcript_editor = TranscriptEditor.new { transcript = self.transcript }
  self.transcript_exporter = TranscriptExporter.new { transcript = self.transcript }
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
    not ImGui.BeginTooltip(ctx) then return end
  ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 42)
  ImGui.Text(ctx, text)
  ImGui.PopTextWrapPos(ctx)
  ImGui.EndTooltip(ctx)
end

function ReaSpeechUI:react()
  -- Handle responses from worker
  self:trap(function ()
    local response = table.remove(self.responses, 1)
    if response then
      self:debug('Response: ' .. dump(response))
      if response.segments then
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
    end
  end)

  -- Handle logs
  self:trap(function ()
    for _, log in pairs(self.logs) do
      local msg, dbg = table.unpack(log)
      if dbg and self.log_enable and self.log_debug then
        reaper.ShowConsoleMsg(self:log_time() .. ' [DBG] ' .. tostring(msg) .. '\n')
      elseif not dbg and self.log_enable then
        reaper.ShowConsoleMsg(self:log_time() .. ' [LOG] ' .. tostring(msg) .. '\n')
      end
    end
    self.logs = {}
  end)

  -- Allow worker to make progress
  self:trap(function ()
    self.worker:react()
  end)

  -- Render UI
  self:trap(function ()
    self:render()
  end)
end

function ReaSpeechUI:render()
  ImGui.PushItemWidth(ctx, self.ITEM_WIDTH)
  self:trap(function ()
        self:render_main()
  end)
  ImGui.PopItemWidth(ctx)
end

function ReaSpeechUI:render_main()
  self:render_inputs()
  self:render_actions()
  if self.transcript:has_segments() then
    ImGui.SeparatorText(ctx, "Transcript")
    self:render_result_actions()
    self:render_table()
  end
  self.transcript_editor:render()
  self.transcript_exporter:render()
end

function ReaSpeechUI.png_from_rle(image_key, offset_x, offset_y)
  if not IMAGES[image_key] then
    return
  end

  local image = IMAGES[image_key]
  local pixels = image.pixels

  offset_x = offset_x or 0
  offset_y = offset_y or 0

  -- Cache arguments to pass to ImGui_DrawList_AddRectFilled
  if not image.draw_list_rectangles then
    image.draw_list_rectangles = {}

    for i = 1, #pixels do
      local row = pixels[i]
      local x = 0
      local y = i - 1

      for j = 1, #row, 5 do
        local length = row[j]

        local color = row[j + 1] << 24
                    | row[j + 2] << 16
                    | row[j + 3] << 8
                    | row[j + 4]

        table.insert(image.draw_list_rectangles, {
          x, y, x + length, y + 1, color
        })

        x = x + length
      end
    end
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)

  for i = 1, #image.draw_list_rectangles do
    local start_x, start_y, end_x, end_y, color = table.unpack(image.draw_list_rectangles[i])

    start_x = start_x + origin_x + offset_x
    start_y = start_y + origin_y + offset_y
    end_x = end_x + origin_x + offset_x
    end_y = end_y + origin_y + offset_y

    ImGui.DrawList_AddRectFilled(draw_list, start_x, start_y, end_x, end_y, color)
  end
  ImGui.Dummy(ctx, image.width, image.height)
end

function ReaSpeechUI:render_inputs()
  --start input table so logo and inputs sit side-by-side
  if ImGui.BeginTable(ctx, 'InputTable', 2) then
    --column settings
    ImGui.TableSetupColumn(ctx, 'Logo',ImGui.TableColumnFlags_WidthFixed())
    ImGui.TableSetupColumn(ctx, 'Inputs',ImGui.TableColumnFlags_WidthFixed())
    -- first column
    ImGui.TableNextColumn(ctx)
    ImGui.SameLine(ctx, -10)
    app.png_from_rle('reaspeech-logo-small')
    -- second column
    ImGui.TableNextColumn(ctx)
    -- start language selection
    if ImGui.BeginCombo(ctx, "language", self.LANGUAGES[self.language]) then
      local combo_items = self.LANGUAGE_CODES
      for _, combo_item in pairs(combo_items) do
        local is_selected = (combo_item == self.language)
        if ImGui.Selectable(ctx, self.LANGUAGES[combo_item], is_selected) then
          self.language = combo_item
        end
      end
      ImGui.EndCombo(ctx)
    end
    local rv, value
    ImGui.SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, "translate", self.translate)
    if rv then
      self.translate = value
    end
    ImGui.Dummy(ctx,0, 10)
    -- start advanced options
    if ImGui.TreeNode(ctx, 'Advanced Options') then
      ImGui.Dummy(ctx,0, 25)
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
      ImGui.TreePop(ctx)
      ImGui.Spacing(ctx)
    end
    -- end advanced options
    ImGui.EndTable(ctx)
  end
  -- end input table
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH + 65)
  app.png_from_rle('heading-logo-tech-audio')
end

function ReaSpeechUI:render_actions()
  local progress = self.worker:progress()

  if progress then
    ImGui.BeginDisabled(ctx)
  end

  if ImGui.Button(ctx, "Process Selected Tracks") then
    self:process_selected_tracks()
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Process Selected Items") then
    self:process_selected_items()
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Process All Items") then
    self:process_all_items()
  end

  if progress then
    ImGui.EndDisabled(ctx)

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel") then
      self.worker:cancel()
    end

    ImGui.SameLine(ctx)
    ImGui.ProgressBar(ctx, progress)
  end
  ImGui.Dummy(ctx,0, 5)
end

function ReaSpeechUI:render_result_actions()
  if ImGui.Button(ctx, "Create Regions") then
    self:handle_create_markers(true)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Create Markers") then
    self:handle_create_markers(false)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Create Notes Track") then
    self:handle_create_notes_track()
  end

  ImGui.SameLine(ctx)
  rv, value = ImGui.Checkbox(ctx, "words", self.words)
  if rv then
    self.words = value
  end

  if self.words then
    ImGui.SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, "colorize", self.colorize_words)
    if rv then
      self.colorize_words = value
    end
  end

  local label_width, _ = ImGui.CalcTextSize(ctx, "search")
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH - label_width - 10)
  local search_changed, search = ImGui.InputText(ctx, 'search', self.transcript.search)
  if search_changed then
    self:handle_search(search)
  end
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH - label_width - 110)
  rv, value = ImGui.Checkbox(ctx, "auto-play", self.autoplay)
  if rv then
    self.autoplay = value
  end

  if self.transcript:has_segments() then
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Export") then
      self:handle_export()
    end

    ImGui.SameLine(ctx)
     if ImGui.Button(ctx, "Clear") then
      self:handle_transcript_clear()
    end
  end
end

function ReaSpeechUI:handle_create_markers(regions)
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  self.transcript:create_markers(0, regions, self.words)
  reaper.Undo_EndBlock(
    ("Create %s from speech"):format(regions and 'regions' or 'markers'), -1)
  reaper.PreventUIRefresh(-1)
end

function ReaSpeechUI:handle_create_notes_track()
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  self.transcript:create_notes_track(self.words)
  reaper.Undo_EndBlock("Create notes track from speech", -1)
  reaper.PreventUIRefresh(-1)
end

function ReaSpeechUI:handle_export()
  self.transcript_exporter:open()
end

function ReaSpeechUI:handle_transcript_clear()
  self.transcript:clear()
end

function ReaSpeechUI:handle_search(search)
  self.transcript.search = search
  self.transcript:update()
end

function ReaSpeechUI:render_table()
  local columns = self.transcript:get_columns()
  local num_columns = #columns + 1

  local ok = ImGui.BeginTable(ctx, "results", num_columns, self.table_flags(true))
  if ok then
    self:trap(function ()
      ImGui.TableSetupColumn(ctx, "##actions", ImGui.TableColumnFlags_NoSort(), 20)

      for _, column in pairs(columns) do
        local column_flags = 0
        if TranscriptSegment.default_hide(column) then
          column_flags = column_flags | ImGui.TableColumnFlags_DefaultHide()
        end
        local init_width = self.COLUMN_WIDTH
        if column == "text" or column == "file" then
          init_width = self.LARGE_COLUMN_WIDTH
        end
        ImGui.TableSetupColumn(ctx, column, column_flags, init_width)
      end

      ImGui.TableSetupScrollFreeze(ctx, num_columns, 1)
      ImGui.TableHeadersRow(ctx)

      self:sort_table()

      for index, segment in pairs(self.transcript:get_segments()) do
        ImGui.TableNextRow(ctx)
        ImGui.TableNextColumn(ctx)
        self:render_segment_actions(segment, index)
        for _, column in pairs(columns) do
          ImGui.TableNextColumn(ctx)
          self:render_table_cell(segment, column)
        end
      end
    end)
    ImGui.EndTable(ctx)
  end
end

function ReaSpeechUI:render_segment_actions(segment, index)
  ImGui.PushFont(ctx, Fonts.icons)
  ImGui.Text(ctx, Fonts.ICON.pencil)
  ImGui.PopFont(ctx)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
  if ImGui.IsItemClicked(ctx) then
    self.transcript_editor:edit_segment(segment, index)
  end
  self:tooltip("Edit")
end

function ReaSpeechUI:render_table_cell(segment, column)
  if column == "text" or column == "word" then
    self:render_text(segment, column)
  elseif column == "score" then
    self:render_score(segment:get(column, 0.0))
  elseif column == "start" or column == "end" then
    ImGui.Text(ctx, reaper.format_timestr(segment:get(column, 0.0), ''))
  else
    local value = segment:get(column)
    if type(value) == 'table' then
      value = table.concat(value, ', ')
    elseif math.type(value) == 'float' then
      value = self.FLOAT_FORMAT:format(value)
    end
    ImGui.Text(ctx, tostring(value))
  end
end

function ReaSpeechUI:render_link(text, onclick, text_color, underline_color)
  text_color = text_color or 0xffffffff
  underline_color = underline_color or 0xffffffa0

  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), text_color)
  ImGui.Text(ctx, text)
  ImGui.PopStyleColor(ctx, 1)

  if ImGui.IsItemHovered(ctx) then
    local rect_min_x, rect_min_y = ImGui.GetItemRectMin(ctx)
    local rect_max_x, _ = ImGui.GetItemRectMax(ctx)
    local _, rect_size_y = ImGui.GetItemRectSize(ctx)
    local line_y = rect_min_y + rect_size_y - 1

    ImGui.DrawList_AddLine(
      ImGui.GetWindowDrawList(ctx),
      rect_min_x, line_y, rect_max_x, line_y,
      underline_color, 1.0)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end

  if ImGui.IsItemClicked(ctx) then
    onclick()
  end
end

function ReaSpeechUI:render_text(segment, column)
  if self.words then
    self:render_text_words(segment, column)
  else
    self:render_text_simple(segment, column)
  end
end

function ReaSpeechUI:render_text_simple(segment, column)
  self:render_link(segment:get(column, ""), function () segment:navigate(nil,self.autoplay) end)
end

function ReaSpeechUI:render_text_words(segment, _)
  if segment.words then
    for i, word in pairs(segment.words) do
      if i > 1 then
        ImGui.SameLine(ctx, 0, 0)
        ImGui.Text(ctx, ' ')
        ImGui.SameLine(ctx, 0, 0)
      end
      local color = nil
      if self.colorize_words then
        color = self:score_color(word:score())
      end
      self:render_link(word.word, function () segment:navigate(i, self.autoplay) end, color)
    end
  end
end

function ReaSpeechUI:render_score(value)
  local w, h = 50 * value, 3
  local color = self:score_color(value)
  if color then
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    y = y + 7
    ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, color)
  end
  ImGui.Dummy(ctx, w, h)
end

function ReaSpeechUI:score_color(value)
  if value > 0.9 then
    return 0xa3ff00a6
  elseif value > 0.8 then
    return 0x2cba00a6
  elseif value > 0.7 then
    return 0xffa700a6
  elseif value > 0.0 then
    return 0xff0000a6
  else
    return nil
  end
end

function ReaSpeechUI:sort_table()
  local specs_dirty, has_specs = ImGui.TableNeedSort(ctx)
  if has_specs and specs_dirty then
    local columns = self.transcript:get_columns()
    column = nil
    ascending = true

    for next_id = 0, math.huge do
      local ok, _, col_idx, _, sort_direction =
        ImGui.TableGetColumnSortSpecs(ctx, next_id)
      if not ok then break end

      column = columns[col_idx]
      ascending = (sort_direction == ImGui.SortDirection_Ascending())
    end

    if column then
      self.transcript:sort(column, ascending)
    else
      self.transcript:update()
    end
  end
end

function ReaSpeechUI:process_selected_tracks()
  local jobs = {}
  for track in ReaIter.each_selected_track() do
    for item in ReaIter.each_track_item(track) do
      for take in ReaIter.each_take(item) do
        local path = self:get_source_path(take)
        if path then
          table.insert(jobs, {item = item, take = take, path = path})
        end
      end
    end
  end
  self:process_jobs(jobs)
end

function ReaSpeechUI:process_selected_items()
  local jobs = {}
  for item in ReaIter.each_selected_media_item() do
    for take in ReaIter.each_take(item) do
      local path = self:get_source_path(take)
      if path then
        table.insert(jobs, {item = item, take = take, path = path})
      end
    end
  end
  self:process_jobs(jobs)
end

function ReaSpeechUI:process_all_items()
  local jobs = {}
  for item in ReaIter.each_media_item() do
    for take in ReaIter.each_take(item) do
      local path = self:get_source_path(take)
      if path then
        table.insert(jobs, {item = item, take = take, path = path})
      end
    end
  end
  self:process_jobs(jobs)
end

function ReaSpeechUI:process_jobs(jobs)
  if #jobs == 0 then
    reaper.MB("No media found to process.", "No media", 0)
    return
  end
  local request = {
    language = self.language,
    translate = self.translate,
    initial_prompt = self.initial_prompt,
    jobs = jobs,
  }
  self:debug('Request: ' .. dump(request))
  self.transcript:clear()
  table.insert(self.requests, request)
end

function ReaSpeechUI:get_source_path(take)
  local source = reaper.GetMediaItemTake_Source(take)
  if source then
    local source_path = reaper.GetMediaSourceFileName(source)
    return source_path
  end
  return nil
end
