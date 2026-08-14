--[[

ExportSettingsUI.lua - Audio format and timing controls for export phase

Provides UI components for:
- Audio format settings (format, sample rate, bit depth, channels)
- Timing controls (pre-roll, post-roll, minimum duration)
- Export options (overwrite, error handling, post-export actions)

Uses standard Widget components and maintains settings via ProjectJSON storage.

]]--

ExportSettingsUI = Polo {}

function ExportSettingsUI:init()
  Logging().init(self, 'ExportSettingsUI')

  assert(self.settings, 'ExportSettingsUI: settings is required')

  -- Timing controls
  self.pre_roll_input = Widgets.NumberInput.new {
    state = self.settings.pre_roll_seconds,
    label = 'Pre-roll (seconds)',
    min_value = 0.0,
    max_value = 10.0,
    step = 0.1,
    help_text = 'Time to include before each audio clip'
  }

  self.post_roll_input = Widgets.NumberInput.new {
    state = self.settings.post_roll_seconds,
    label = 'Post-roll (seconds)',
    min_value = 0.0,
    max_value = 10.0,
    step = 0.1,
    help_text = 'Time to include after each audio clip'
  }

  self.min_duration_input = Widgets.NumberInput.new {
    state = self.settings.min_duration_seconds,
    label = 'Minimum Duration (seconds)',
    min_value = 0.1,
    max_value = 60.0,
    step = 0.1,
    help_text = 'Minimum duration for exported audio clips'
  }

  -- Export options
  self.overwrite_checkbox = Widgets.Checkbox.new {
    state = self.settings.overwrite_existing,
    label_long = 'Overwrite existing files',
    label_short = 'Overwrite',
    help_text = 'Replace files that already exist in the output directory'
  }

  self.skip_errors_checkbox = Widgets.Checkbox.new {
    state = self.settings.skip_on_error,
    label_long = 'Skip errors and continue',
    label_short = 'Skip Errors',
    help_text = 'Continue processing other files when an error occurs'
  }

  self.open_folder_checkbox = Widgets.Checkbox.new {
    state = self.settings.open_folder_when_done,
    label_long = 'Open output folder when complete',
    label_short = 'Open Folder',
    help_text = 'Automatically open the output directory after export finishes'
  }

  self:log("Initialized ExportSettingsUI")
end

function ExportSettingsUI:render_section_header(title)
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), title)
  end, Trap)
  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)
end

-- Honest UI: export slices source WAVs directly (no render engine,
-- no transcoding), so the output always matches the source - format
-- controls would be fiction until a transcode pipeline exists
-- (backlog: W64/RF64)
function ExportSettingsUI:render_audio_format_section(_width)
  self:render_section_header("Audio Format")

  ImGui.TextDisabled(Ctx(), "WAV, matching each source file's format")

  ImGui.Dummy(Ctx(), 0, 8)
end

function ExportSettingsUI:render_timing_section(width)
  self:render_section_header("Timing")

  local third_width = (width - 40) * 0.33

  ImGui.PushItemWidth(Ctx(), third_width)
  self.pre_roll_input:render()
  self.post_roll_input:render()
  self.min_duration_input:render()
  ImGui.PopItemWidth(Ctx())

  ImGui.Dummy(Ctx(), 0, 8)
end

function ExportSettingsUI:render_options_section(_width)
  self:render_section_header("Options")

  self.overwrite_checkbox:render()
  self.skip_errors_checkbox:render()
  self.open_folder_checkbox:render()

  ImGui.Dummy(Ctx(), 0, 4)
end

function ExportSettingsUI:render(width)
  Trap(function()
    self:render_audio_format_section(width)
    self:render_timing_section(width)
    self:render_options_section(width)
  end)
end
