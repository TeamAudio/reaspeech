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

  Logging().init(self, 'TranscriptExporter')

  ToolWindow.init(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    theme = Theme.popup,
    window_flags = 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
  })

  self.on_export = self.on_export or function() end

  self.export_formats = TranscriptExporterFormats.new {
    TranscriptExportFormat.exporter_json(),
    TranscriptExportFormat.exporter_srt(),
    TranscriptExportFormat.exporter_csv(),
  }
  function self.export_formats.on_change()
    self:update_target_filename_ui()
  end

  self.export_options = {}

  self.file_selector = Widgets.FileSelector.new({
    label = 'File',
    save = true,
    button_width = self.BUTTON_WIDTH,
    input_width = self.FILE_WIDTH,
    on_set = function() self:update_target_filename_ui() end,
  })

  -- invisible state to manage the UX around the target filename
  self.target_filename_exists = Storage.memory(false)
  self.has_extension = Storage.memory(false)

  -- this is the value that will actually be used after the
  -- file_selector contents are processed (relative vs full path,
  -- auto extension, etc.)
  self.target_filename = Storage.memory('')
  self.target_filename_display = Storage.memory('')

  self.apply_extension = Widgets.Checkbox.new {
    default = true,
    label_long = 'Apply Extension',
    disabled_if = function() return self.has_extension:get() end,
    changed_handler = function()
      if not self.apply_extension then return end
      self:update_target_filename_ui()
    end
  }

  self.alert_popup = AlertPopup.new {}
end

function TranscriptExporter:open()
  self:reset_form()
end

function TranscriptExporter:reset_form()
  self.file_selector:set(self.transcript.name or '')
  self.apply_extension:set(true)
  self:update_target_filename_ui()
end

function TranscriptExporter:clear_target_filename()
  self.target_filename:set('')
  self.target_filename_display:set('')
  self.target_filename_exists:set(false)
  self.has_extension:set(false)
end

function TranscriptExporter:update_target_filename_ui()
  local specified_path = self.file_selector:value()

  if specified_path == '' then
    self:clear_target_filename()
    return
  end

  local is_full_path = PathUtil.is_full_path(specified_path)

  local full_path = PathUtil.get_real_path(specified_path)

  self.has_extension:set(PathUtil.has_extension(full_path))

  -- automatically turn off the auto-extension if user enters
  -- in a filename with an extension
  if self.has_extension:get() and self.apply_extension:value() then
    self.apply_extension:set(false)
  end

  -- automatically apply default extension for format, if desired
  if self.apply_extension:value() then
    local extension = self.export_formats:selected_format().extension
    full_path = PathUtil.apply_extension(full_path, extension)
  end

  self.target_filename:set(full_path)

  if is_full_path then
    self.target_filename_display:set(full_path)
  else
    local display = PathUtil.join('<Project Resources>', full_path:sub(#reaper.GetProjectPath() + 2))
    self.target_filename_display:set(display)
  end

  self.target_filename_exists:set(reaper.file_exists(self.target_filename:get()))
end

function TranscriptExporter:show_success()
  self.alert_popup.onclose = function ()
    self.alert_popup.onclose = nil
    self.on_export()
    self:close()
  end

  self.alert_popup:show('Export Successful', function()
    local file_path = self.target_filename:get()
    local filename = PathUtil.get_filename(self.target_filename:get())

    ImGui.Text(Ctx(), 'Exported ' .. self.export_formats:selected_key() .. ' to: ')
    ImGui.SameLine(Ctx())

    Widgets.link(filename, function()
      ExecProcess.new(PathUtil.get_reveal_command(file_path)):no_wait()
      self.alert_popup:close()
    end)
  end)
end

function TranscriptExporter:show_error(msg)
  self.alert_popup:show('Export Failed', msg)
end

function TranscriptExporter:render_content()
  self.alert_popup:render()

  self.export_formats:render_combo(self.INPUT_WIDTH)

  ImGui.Spacing(Ctx())

  self.export_formats:render_format_options(self.export_options)

  ImGui.Spacing(Ctx())

  self:render_file_selector()

  self:render_separator()

  self:render_buttons()
end

function TranscriptExporter:render_file_selector()
  self.file_selector:render()

  ImGui.Spacing(Ctx())

  self.apply_extension:render()

  ImGui.Spacing(Ctx())

  local show_target_filename = self.file_selector:value() == ''
    or self.target_filename:get() ~= self.file_selector:value()

  if show_target_filename then
    ImGui.Text(Ctx(), 'Target File: ' .. self.target_filename_display:get())
  end

  if self.target_filename_exists:get() then
    Widgets.warning('File exists and will be overwritten.')
  end
end

function TranscriptExporter:render_buttons()
  Widgets.disable_if(self.file_selector:value() == '', function()
    if ImGui.Button(Ctx(), 'Export', self.BUTTON_WIDTH, 0) then
      if self:handle_export() then
        self:show_success()
      end
    end
  end)

  ImGui.SameLine(Ctx())
  if ImGui.Button(Ctx(), 'Cancel', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptExporter:handle_export()
  local target_filename = self.target_filename:get()
  if target_filename == '' then
    self:show_error('Please specify a file name.')
    return false
  end
  local file = io.open(target_filename, 'w')
  if not file then
    self:show_error('Could not open file: ' .. target_filename)
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
  ImGui.Text(Ctx(), 'Format')
  ImGui.SetNextItemWidth(Ctx(), width)
  if ImGui.BeginCombo(Ctx(), "##format", self.selected_format_key) then
    Trap(function()
      for _, format in pairs(self.formatters) do
        local is_selected = self.selected_format_key == format.key
        if ImGui.Selectable(Ctx(), format.key, is_selected) then
          self.selected_format_key = format.key

          if self.on_change then
            self.on_change()
          end
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(Ctx())
        end
      end
    end)
    ImGui.EndCombo(Ctx())
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
  Trap(function()
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
  local rv, value = ImGui.Checkbox(Ctx(), 'One Object per Transcript Segment', options.object_per_segment)
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

  rv, value = ImGui.InputText(Ctx(), 'X1', options.coords_x1, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_x1 = TranscriptExportFormat.strip_non_numeric(value)
  end

  ImGui.SameLine(Ctx())

  rv, value = ImGui.InputText(Ctx(), 'Y1', options.coords_y1, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_y1 = TranscriptExportFormat.strip_non_numeric(value)
  end

  rv, value = ImGui.InputText(Ctx(), 'X2', options.coords_x2, ImGui.InputTextFlags_CharsDecimal())
  if rv then
    options.coords_x2 = TranscriptExportFormat.strip_non_numeric(value)
  end

  ImGui.SameLine(Ctx())

  rv, value = ImGui.InputText(Ctx(), 'Y2', options.coords_y2, ImGui.InputTextFlags_CharsDecimal())
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

  if ImGui.BeginCombo(Ctx(), 'Delimiter', selected_delimiter.name) then
    Trap(function()
      for _, delimiter in ipairs(delimiters) do
        local is_selected = options.delimiter == delimiter.char
        if ImGui.Selectable(Ctx(), delimiter.name, is_selected) then
          options.delimiter = delimiter.char
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(Ctx())
        end
      end
    end)
    ImGui.EndCombo(Ctx())
  end

  ImGui.Spacing(Ctx())

  local rv, value = ImGui.Checkbox(Ctx(), 'Include Header Row', options.include_header_row)
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
