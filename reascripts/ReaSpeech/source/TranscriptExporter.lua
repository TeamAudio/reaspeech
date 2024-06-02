--[[

  TranscriptExporter.lua - Transcript export UI

]]--

TranscriptExporter = {
  TITLE = 'Export',
  WIDTH = 650,
  HEIGHT = 200,
  BUTTON_WIDTH = 120,
  INPUT_WIDTH = 120,
  FILE_WIDTH = 500,
}

TranscriptExporter.__index = TranscriptExporter

TranscriptExporter.new = function (o)
  o = o or {}
  setmetatable(o, TranscriptExporter)
  o:init()
  return o
end

function TranscriptExporter:init()
  assert(self.transcript, 'missing transcript')
  self.is_open = false
  self.export_formats = TranscriptExporterFormats.new {
    TranscriptExportFormat.exporter_json(),
    TranscriptExportFormat.exporter_srt(),
    TranscriptExportFormat.exporter_csv(),
  }
  self.export_options = {}
  self.file = ''
  self.success = AlertPopup.new { title = 'Export Successful' }
  self.failure = AlertPopup.new { title = 'Export Failed' }
end

function TranscriptExporter:show_success()
  self.success.onclose = function ()
    self.success.onclose = nil
    self:close()
  end
  self.success:show('Exported ' .. self.export_formats:selected_key() .. ' to: ' .. self.file)
end

function TranscriptExporter:show_error(msg)
  self.failure:show(msg)
end

function TranscriptExporter:render()
  if not self.is_open then
    return
  end

  local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
  ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, self.WIDTH, self.HEIGHT, ImGui.Cond_FirstUseEver())

  local flags = (
    0
    | ImGui.WindowFlags_AlwaysAutoResize()
    | ImGui.WindowFlags_NoCollapse()
    | ImGui.WindowFlags_NoDocking()
  )

  local visible, open = ImGui.Begin(ctx, self.TITLE, true, flags)
  if visible then
    app:trap(function ()
      self:render_content()
      self.success:render()
      self.failure:render()
    end)
    ImGui.End(ctx)
  end
  if not open then
    self:close()
  end
end

function TranscriptExporter:render_content()
  self.export_formats:render_combo(self.INPUT_WIDTH)

  ImGui.Spacing(ctx)

  self.export_formats:render_format_options(self.export_options)

  self:render_file_selector()

  self:render_separator()

  self:render_buttons()
end

-- Display a text input for the output filename, with a Browse button if
-- the js_ReaScriptAPI extension is available.
function TranscriptExporter:render_file_selector()
  ImGui.Text(ctx, 'File')
  if app:has_js_ReaScriptAPI() then
    if ImGui.Button(ctx, 'Choose File', self.BUTTON_WIDTH, 0) then
      local rv, file = app:show_file_dialog {
        title = 'Save transcript',
        file = self.file,
        save = true,
        ext = self.export_formats:file_selector_spec(),
      }
      if rv == 1 then
        self.file = file
      end
    end
    ImGui.SameLine(ctx)
  end

  ImGui.SetNextItemWidth(ctx, self.FILE_WIDTH)
  local file_changed, file = ImGui.InputText(ctx, '##file', self.file, 256)
  if file_changed then
    self.file = file
  end

  if not app:has_js_ReaScriptAPI() then
    ImGui.Text(ctx, "For a better experience, install js_ReaScriptAPI")
    ImGui.Spacing(ctx)
  end
end

function TranscriptExporter:render_buttons()
  ReaUtil.disabler(ctx)(self.file == '', function()
    if ImGui.Button(ctx, 'Export', self.BUTTON_WIDTH, 0) then
      if self:handle_export() then
        self:show_success()
      end
    end
  end)

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Cancel', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptExporter:render_separator()
  ImGui.Dummy(ctx, 0, 0)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 0)
end

function TranscriptExporter:handle_export()
  if self.file == '' then
    self:show_error('Please specify a file name.')
    return false
  end
  local file = io.open(self.file, 'w')
  if not file then
    self:show_error('Could not open file: ' .. self.file)
    return false
  end
  self.export_formats:write(self.transcript, file)
  file:close()
  return true
end

function TranscriptExporter:open()
  self.is_open = true
end

function TranscriptExporter:close()
  self.is_open = false
end

TranscriptExporterFormats = {}
TranscriptExporterFormats.__index = TranscriptExporterFormats

TranscriptExporterFormats.new = function (formatters)
  local o = {
    format_list = {},
    format_map = {},
  }
  setmetatable(o, TranscriptExporterFormats)

  for _, formatter in ipairs(formatters) do
    o:add_format(formatter)
  end

  return o
end

function TranscriptExporterFormats:add_format(format)
  table.insert(self.format_list, format)
  self.format_map[format.key] = #self.format_list
end

function TranscriptExporterFormats:render_combo(width)
  ImGui.Text(ctx, 'Format')
  ImGui.SetNextItemWidth(ctx, width)
  if ImGui.BeginCombo(ctx, "##format", self.selected_format_key) then
    for _, format in pairs(self.format_list) do
      local is_selected = self.selected_format_key == format.key
      if ImGui.Selectable(ctx, format.key, is_selected) then
        self.selected_format_key = format.key
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end
end

function TranscriptExporterFormats:selected_key()
  return self:selected_format().key
end

function TranscriptExporterFormats:file_selector_spec()
  return self:selected_format():file_selector_spec()
end

function TranscriptExporterFormats:write(transcript, output_file)
  return self:selected_format().writer(transcript, output_file)
end

function TranscriptExporterFormats:selected_format()
  if not self.selected_format_key then
    if not self.format_list or #self.format_list < 1 then
      app:debug('no formats to set for default')
      return
    end

    self.selected_format_key = self.format_list[1].key
  end

  local index = self.format_map[self.selected_format_key]

  return self.format_list[index]
end

function TranscriptExporterFormats:render_format_options(options)
  app:trap(function()
    local format = self:selected_format()

    if format then
      format.option_renderer(options)
    end
  end)
end

TranscriptExportFormat = {
  FILE_SELECTOR_SPEC_FORMAT_STRING = '%s files (*.%s)\0*.%s\0All files (*.*)\0*.*\0\0',
  OPTIONS_NOOP = function(_options) end,
}
TranscriptExportFormat.__index = TranscriptExportFormat

TranscriptExportFormat.new = function (key, extension, option_renderer, writer_f)
  local o = {
    key = key,
    extension = extension,
    option_renderer = option_renderer,
    writer = writer_f,
  }
  setmetatable(o, TranscriptExportFormat)
  return o
end

function TranscriptExportFormat:file_selector_spec()
  return TranscriptExportFormat.FILE_SELECTOR_SPEC_FORMAT_STRING:format(
    self.key, self.extension, self.extension)
end

function TranscriptExportFormat.exporter_json()
  return TranscriptExportFormat.new(
    'JSON', 'json',
    TranscriptExportFormat.OPTIONS_NOOP,
    TranscriptExportFormat.writer_json
  )
end

function TranscriptExportFormat.writer_json(transcript, output_file)
  output_file:write(transcript:to_json())
end

function TranscriptExportFormat.exporter_srt()
  return TranscriptExportFormat.new(
    'SRT', 'srt',
    TranscriptExportFormat.OPTIONS_NOOP,
    TranscriptExportFormat.writer_srt
  )
end

function TranscriptExportFormat.writer_srt(transcript, output_file)
  local writer = SRTWriter.new { file = output_file }
  writer:write(transcript)
end

function TranscriptExportFormat.exporter_csv()
  return TranscriptExportFormat.new(
    'CSV', 'csv',
    TranscriptExportFormat.OPTIONS_NOOP,
    TranscriptExportFormat.writer_csv
  )
end

function TranscriptExportFormat.writer_csv(transcript, output_file)
  local writer = CSVWriter.new { file = output_file }
  writer:write(transcript)
end
