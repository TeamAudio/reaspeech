--[[

  TranscriptImporter.lua - Import previously exported Transcript JSON

]]--

TranscriptImporter = Polo {
  TITLE = 'Import',
  WIDTH = 650,
  HEIGHT = 200,
  BUTTON_WIDTH = 120,
  INPUT_WIDTH = 120,
  FILE_WIDTH = 500,
}

function TranscriptImporter:init()
  ToolWindow.init(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    theme = ImGuiTheme.new({
      colors = {
        { ImGui.Col_WindowBg, Theme.colors.very_dark_gray_semi_opaque },
      }
    }),
    window_flags = 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
  })

  self.file_selector = ReaSpeechFileSelector.new({
    label = 'File - must be JSON previously exported from ReaSpeech.',
    save = false,
    button_width = self.BUTTON_WIDTH,
    input_width = self.FILE_WIDTH
  })

  self.alert_popup = AlertPopup.new {}
end

function TranscriptImporter:show_success()
  self.alert_popup.onclose = function ()
    self.alert_popup.onclose = nil
    self:close()
  end
  self.alert_popup:show('Import Successful', 'Imported ' .. self.file_selector:value())
end

function TranscriptImporter:show_error(msg)
  self.alert_popup:show('Import Failed', msg)
end

function TranscriptImporter:render_content()
  self.alert_popup:render()

  self.file_selector:render()

  self:render_separator()

  self:render_buttons()
end

function TranscriptImporter:render_buttons()
  -- alternatively we could do a disable-button-if-no-file thing
  if ImGui.Button(ctx, 'Import', self.BUTTON_WIDTH, 0) then
    local filepath = self.file_selector:value()
    if filepath == '' then
      self:show_error('No file selected')
      return
    end

    local success, msg = self:import(filepath)
    if success then
      self:show_success()
    else
      self:show_error(msg)
    end
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Close', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptImporter:import(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    return false, 'File not found'
  end

  local content = file:read('*a')
  file:close()

  app:load_transcript(Transcript.from_json(content))

  return true
end
