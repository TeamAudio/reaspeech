--[[

  TranscriptExporter.lua - Transcript export UI

]]--

TranscriptExporter = Polo {
  TITLE = 'Export',
  WIDTH = 650,
  HEIGHT = 200,
  BUTTON_WIDTH = 120,
  INPUT_WIDTH = 120,
  FILE_WIDTH = 500,
}

function TranscriptExporter:init()
  assert(self.transcript, 'missing transcript')

  Logging.init(self, 'TranscriptExporter')

  self.theme = ImGuiTheme.new {
    styles = {
      { ImGui.StyleVar_Alpha, 0 },
    }
  }

  ToolWindow.init(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    window_flags = 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
      | ImGui.WindowFlags_TopMost(),
    theme = self.theme,
  })

  self.export_formats = TranscriptExporterFormats.new {
    TranscriptExportFormat.exporter_json(),
    TranscriptExportFormat.exporter_srt(),
    TranscriptExportFormat.exporter_csv(),
  }
  self.export_options = {}
  self.file_selector = ReaSpeechFileSelector.new({
    label = 'File',
    save = true,
    button_width = self.BUTTON_WIDTH,
    input_width = self.FILE_WIDTH
  })

  self.alert_popup = AlertPopup.new {}
end

function TranscriptExporter:open()
  self.theme.styles[1][2] = Tween.linear(0.0, 1.0, 0.2)
end

function TranscriptExporter:show_success()
  self.alert_popup.onclose = function ()
    self.alert_popup.onclose = nil
    self:close()
  end
  self.alert_popup:show('Export Successful', 'Exported ' .. self.export_formats:selected_key() .. ' to: ' .. self.file_selector:value())
end

function TranscriptExporter:show_error(msg)
  self.alert_popup:show('Export Failed', msg)
end

function TranscriptExporter:render_content()
  self.alert_popup:render()

  self.export_formats:render_combo(self.INPUT_WIDTH)

  ImGui.Spacing(ctx)

  self.export_formats:render_format_options(self.export_options)

  ImGui.Spacing(ctx)

  self:render_file_selector()

  self:render_separator()

  self:render_buttons()
end

function TranscriptExporter:render_file_selector()
  self.file_selector:render()
end

function TranscriptExporter:render_buttons()
  ReaUtil.disabler(ctx)(self.file_selector:value() == '', function()
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

function TranscriptExporter:handle_export()
  if self.file_selector:value() == '' then
    self:show_error('Please specify a file name.')
    return false
  end
  local file = io.open(self.file_selector:value(), 'w')
  if not file then
    self:show_error('Could not open file: ' .. self.file_selector:value())
    return false
  end
  self.export_formats:write(self.transcript, file, self.export_options)
  file:close()
  return true
end

TranscriptExporterFormats = Polo {
  new = function(formatters)
    local format_map = {}

    for i, formatter in ipairs(formatters) do
      format_map[formatter.key] = i
    end

    return {
      formatters = formatters,
      format_map = format_map,
    }
  end,
}

function TranscriptExporterFormats:render_combo(width)
  ImGui.Text(ctx, 'Format')
  ImGui.SetNextItemWidth(ctx, width)
  if ImGui.BeginCombo(ctx, "##format", self.selected_format_key) then
    app:trap(function()
      for _, format in pairs(self.formatters) do
        local is_selected = self.selected_format_key == format.key
        if ImGui.Selectable(ctx, format.key, is_selected) then
          self.selected_format_key = format.key
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(ctx)
        end
      end
    end)
    ImGui.EndCombo(ctx)
  end
end

function TranscriptExporterFormats:selected_key()
  return self:selected_format().key
end

function TranscriptExporterFormats:file_selector_spec()
  return self:selected_format():file_selector_spec()
end

function TranscriptExporterFormats:write(transcript, output_file, options)
  return self:selected_format().writer(transcript, output_file, options)
end

function TranscriptExporterFormats:selected_format()
  if not self.selected_format_key then
    if not self.formatters or #self.formatters < 1 then
      self:debug('no formats to set for default')
      return
    end

    self.selected_format_key = self.formatters[1].key
  end

  local index = self.format_map[self.selected_format_key]

  return self.formatters[index]
end

function TranscriptExporterFormats:render_format_options(options)
  app:trap(function()
    local format = self:selected_format()

    if format then
      format.option_renderer(options)
    end
  end)
end

TranscriptExportFormat = Polo {
  OPTIONS_NOOP = function(_options) end,

  new = function (key, extension, option_renderer, writer_f)
    return {
      key = key,
      extension = extension,
      option_renderer = option_renderer,
      writer = writer_f,
    }
  end,
}

function TranscriptExportFormat:file_selector_spec()
  local selector_spec = '%s files (*.%s)\0*.%s\0All files (*.*)\0*.*\0\0'
  return selector_spec:format(self.key, self.extension, self.extension)
end

function TranscriptExportFormat.exporter_json()
  return TranscriptExportFormat.new(
    'JSON', 'json',
    TranscriptExportFormat.options_json,
    TranscriptExportFormat.writer_json
  )
end

function TranscriptExportFormat.options_json(options)
  local rv, value = ImGui.Checkbox(ctx, 'One Object per Transcript Segment', options.object_per_segment)
  if rv then
    options.object_per_segment = value
  end
end

function TranscriptExportFormat.writer_json(transcript, output_file, options)
  if options.object_per_segment then
    for _, segment in pairs(transcript:get_segments()) do
      output_file:write(segment:to_json())
      output_file:write('\n')
    end
  else
    output_file:write(transcript:to_json())
  end
end

function TranscriptExportFormat.exporter_srt()
  return TranscriptExportFormat.new(
    'SRT', 'srt',
    TranscriptExportFormat.options_srt,
    TranscriptExportFormat.writer_srt
  )
end

function TranscriptExportFormat.strip_non_numeric(value)
  return value:gsub("[^0-9]", ""):gsub("^0+", "")
end

function TranscriptExportFormat.options_srt(options)
  local rv, value

  rv, value = ImGui.InputText(ctx, 'X1', options.coords_x1, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_x1 = TranscriptExportFormat.strip_non_numeric(value)
  end

  ImGui.SameLine(ctx)

  rv, value = ImGui.InputText(ctx, 'Y1', options.coords_y1, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_y1 = TranscriptExportFormat.strip_non_numeric(value)
  end

  rv, value = ImGui.InputText(ctx, 'X2', options.coords_x2, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_x2 = TranscriptExportFormat.strip_non_numeric(value)
  end

  ImGui.SameLine(ctx)

  rv, value = ImGui.InputText(ctx, 'Y2', options.coords_y2, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_y2 = TranscriptExportFormat.strip_non_numeric(value)
  end
end

function TranscriptExportFormat.writer_srt(transcript, output_file, options)
  local writer = SRTWriter.new { file = output_file, options = options }
  writer:write(transcript)
end

function TranscriptExportFormat.exporter_csv()
  return TranscriptExportFormat.new(
    'CSV', 'csv',
    TranscriptExportFormat.options_csv,
    TranscriptExportFormat.writer_csv
  )
end

function TranscriptExportFormat.options_csv(options)
  local delimiters = CSVWriter.DELIMITERS

  local selected_delimiter = delimiters[1]

  for _, delimiter in ipairs(delimiters) do
    if delimiter.char == options.delimiter then
      selected_delimiter = delimiter
      break
    end
  end

  if ImGui.BeginCombo(ctx, 'Delimiter', selected_delimiter.name) then
    app:trap(function()
      for _, delimiter in ipairs(delimiters) do
        local is_selected = options.delimiter == delimiter.char
        if ImGui.Selectable(ctx, delimiter.name, is_selected) then
          options.delimiter = delimiter.char
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(ctx)
        end
      end
    end)
    ImGui.EndCombo(ctx)
  end

  ImGui.Spacing(ctx)

  local rv, value = ImGui.Checkbox(ctx, 'Include Header Row', options.include_header_row)
  if rv then
    options.include_header_row = value
  end
end

function TranscriptExportFormat.writer_csv(transcript, output_file, options)
  local writer = CSVWriter.new {
    file = output_file,
    delimiter = options.delimiter,
    include_header_row = options.include_header_row
  }
  writer:write(transcript)
end
