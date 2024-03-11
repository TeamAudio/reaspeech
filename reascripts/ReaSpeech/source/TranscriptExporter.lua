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
  FORMATS = {'JSON', 'SRT'},
  EXT_JSON = 'JSON files (*.json)\0*.json\0All files (*.*)\0*.*\0\0',
  EXT_SRT = 'SRT files (*.srt)\0*.srt\0All files (*.*)\0*.*\0\0',
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
  self.format = self.FORMATS[1]
  self.file = ''
  self.success = AlertPopup.new { title = 'Export Successful' }
  self.failure = AlertPopup.new { title = 'Export Failed' }
end

function TranscriptExporter:show_success()
  self.success.onclose = function ()
    self.success.onclose = nil
    self:close()
  end
  self.success:show('Exported ' .. self.format .. ' to: ' .. self.file)
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
  ImGui.Text(ctx, 'Format')
  ImGui.SetNextItemWidth(ctx, self.INPUT_WIDTH)
  if ImGui.BeginCombo(ctx, "##format", self.format) then
    for _, format in pairs(self.FORMATS) do
      local is_selected = self.format == format
      if ImGui.Selectable(ctx, format, is_selected) then
        self.format = format
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.Spacing(ctx)

  -- Display a text input for the output filename, with a Browse button if
  -- the js_ReaScriptAPI extension is available.
  ImGui.Text(ctx, 'File')
  if app:has_js_ReaScriptAPI() then
    if ImGui.Button(ctx, 'Choose File', self.BUTTON_WIDTH, 0) then
      local rv, file = app:show_file_dialog {
        title = 'Save transcript',
        file = self.file,
        save = true,
        ext = self['EXT_' .. self.format],
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

  self:render_separator()

  local valid = (self.file ~= '')
  if not valid then
    ImGui.BeginDisabled(ctx)
  end
  if ImGui.Button(ctx, 'Export', self.BUTTON_WIDTH, 0) then
    if self:handle_export() then
      self:show_success()
    end
  end
  if not valid then
    ImGui.EndDisabled(ctx)
  end

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
  if self.format == 'JSON' then
    return self:export_json()
  elseif self.format == 'SRT' then
    return self:export_srt()
  else
    error('unknown format: ' .. self.format)
  end
end

function TranscriptExporter:export_json()
  if self.file == '' then
    self:show_error('Please specify a file name.')
    return false
  end
  local file = io.open(self.file, 'w')
  if not file then
    self:show_error('Could not open file: ' .. self.file)
    return false
  end
  file:write(self.transcript:to_json())
  file:close()
  return true
end

function TranscriptExporter:export_srt()
  if self.file == '' then
    self:show_error('Please specify a file name.')
    return false
  end
  local file = io.open(self.file, 'w')
  if not file then
    self:show_error('Could not open file: ' .. self.file)
    return false
  end
  local writer = SRTWriter.new { file = file }
  writer:write(self.transcript)
  file:close()
  return true
end

function TranscriptExporter:open()
  self.is_open = true
end

function TranscriptExporter:close()
  self.is_open = false
end
