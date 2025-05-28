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
    theme = Theme.popup,
    window_flags = 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
  })

  self.file_selector = Widgets.FileSelector.new({
    label = 'File - must be JSON previously exported from ReaSpeech.',
    save = false,
    button_width = self.BUTTON_WIDTH,
    input_width = self.FILE_WIDTH
  })

  self.alert_popup = AlertPopup.new {}
end

function TranscriptImporter:show_success(on_close)
  on_close = on_close or function() end
  self.alert_popup.onclose = function ()
    self.alert_popup.onclose = nil
    on_close()
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
  if ImGui.Button(Ctx(), 'Import', self.BUTTON_WIDTH, 0) then
    local filepath = self.file_selector:value()
    if filepath == '' then
      self:show_error('No file selected')
      return
    end

    local transcript, msg = self:import(filepath)
    if transcript then
      self:show_success(function()
        app:load_transcript(transcript)
      end)
    else
      self:show_error(msg)
    end
  end

  ImGui.SameLine(Ctx())

  if ImGui.Button(Ctx(), 'Close', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptImporter:can_import(filepath)
  if not PathUtil.has_extension(filepath, 'json') then
    return false, 'File must be a JSON file'
  end

  local file = io.open(filepath, 'r')
  if not file then
    return false, "Can't open file"
  end

  -- check json
  local content = file:read('*a')
  file:close()
  if not content or not Trap(function()
    if #content < 1 then
      return false
    end

    content = json.decode(content)
    return true
  end) then
    return false, 'Invalid JSON'
  end

  -- very basic json content check
  if not content.segments then
    return false, 'No segments field'
  end

  return true
end

function TranscriptImporter:import(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    return nil, 'File not found'
  end

  local content = file:read('*a')
  file:close()

  local transcript = Transcript.from_json(content)

  return transcript
end

function TranscriptImporter:quick_import()
  return function()
    local filenames = Widgets.FileSelector.simple_open(
      'Import Transcript',
      { json = 'JSON Files' },
      { allow_multiple = true }
    )

    if #filenames < 1 then
      local importer = app.plugins(ASRPlugin:key()):importer()
      importer:present()
      return
    end

    local valid_filenames = {}
    for _, filename in ipairs(filenames) do
      if filename and filename ~= '' then
        table.insert(valid_filenames, filename)
      end
    end

    local load_errors = {}

    for _, filename in ipairs(valid_filenames) do
      local can_import, msg = self:can_import(filename)

      if not can_import then
        table.insert(load_errors, {filename, msg})
      else
        local transcript, err = self:import(filename)

        if not transcript or err then
          table.insert(load_errors, {filename, err})
        else
          local plugin = TranscriptUI.new {
            app = app,
            transcript = transcript,
            _transcript_saved = true
          }
          app.plugins:add_plugin(plugin)
        end
      end
    end

    if #load_errors > 0 then
      local title = 'Import complete, but...'
      local msg = 'Some selected files were not loaded:\n\n%s'

      local messages = {}

      for _, err in ipairs(load_errors) do
        table.insert(messages, PathUtil.get_filename(err[1]) .. ': ' .. err[2])
      end

      local file_messages = table.concat(messages, '\n')

      app.alert_popup:show(title, msg:format(file_messages))
    end
  end
end
