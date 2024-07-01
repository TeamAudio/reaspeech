--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  DEFAULT_TAB = 'simple',

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  SIMPLE_MODEL_SIZES = {
    {'Small', 'small'},
    {'Medium', 'medium'},
    {'Large', 'distil-large-v3'},
  },

  COLUMN_PADDING = 15,
  MARGIN_BOTTOM = 5,
  MARGIN_LEFT = 115,
  MARGIN_RIGHT = 0,
  NARROW_COLUMN_WIDTH = 150,
}

function ReaSpeechControlsUI:init()
  self.tabs = ReaSpeechTabBar.new {
    default = self.DEFAULT_TAB,
    tabs = {
      ReaSpeechTabBar.tab('simple', 'Simple'),
      ReaSpeechTabBar.tab('advanced', 'Advanced'),
    }
  }

  self.log_enable = ReaSpeechCheckbox.simple(false, 'Enable')
  self.log_debug = ReaSpeechCheckbox.simple(false, 'Debug')

  self.language = ReaSpeechCombo.new(self.DEFAULT_LANGUAGE, 'Language', WhisperLanguages.LANGUAGE_CODES, WhisperLanguages.LANGUAGES)

  self.translate = ReaSpeechCheckbox.new {
    default = false,
    label_long = 'Translate to English',
    label_short = 'Translate',
    width_threshold = self.NARROW_COLUMN_WIDTH
  }

  self.hotwords = ReaSpeechTextInput.simple('', 'Hot Words')
  self.initial_prompt = ReaSpeechTextInput.simple('', 'Initial Prompt')
  self.model_name = ReaSpeechTextInput.simple(self.DEFAULT_MODEL_NAME, 'Model Name')

  self.vad_filter = ReaSpeechCheckbox.new {
    default = true,
    label_long = 'Voice Activity Detection',
    label_short = 'VAD',
    width_threshold = self.NARROW_COLUMN_WIDTH
  }

  self.model_name_buttons = ReaSpeechButtonBar.new {
    default = self.DEFAULT_MODEL_NAME,
    label = 'Model Name',
    buttons = self.SIMPLE_MODEL_SIZES,
    column_padding = self.COLUMN_PADDING,
    margin_bottom = self.MARGIN_BOTTOM,
    margin_left = self.MARGIN_LEFT,
    margin_right = self.MARGIN_RIGHT,
  }
  self.model_name_buttons.on_set = function()
    self.model_name:set(self.model_name_buttons:value())
  end

  self:init_layouts()
end

function ReaSpeechControlsUI:get_request_data()
  return {
    language = self.language:value(),
    translate = self.translate:value(),
    hotwords = self.hotwords:value(),
    initial_prompt = self.initial_prompt:value(),
    model_name = self.model_name:value(),
    vad_filter = self.vad_filter:value(),
  }
end

function ReaSpeechControlsUI:init_layouts()
  self:init_advanced_layouts()
end

function ReaSpeechControlsUI:init_advanced_layouts()
  local renderers = {
    {self.render_model_name, self.render_hotwords, self.render_language},
    {self.render_options, self.render_initial_prompt, self.render_logging},
  }

  self.advanced_layouts = {}

  for row = 1, #renderers do
    self.advanced_layouts[row] = ColumnLayout.new {
      column_padding = self.COLUMN_PADDING,
      margin_bottom = self.MARGIN_BOTTOM,
      margin_left = self.MARGIN_LEFT,
      margin_right = self.MARGIN_RIGHT,
      num_columns = #renderers[row],

      render_column = function (column)
        ImGui.PushItemWidth(ctx, column.width)
        app:trap(function () renderers[row][column.num](self, column) end)
        ImGui.PopItemWidth(ctx)
      end
    }
  end
end

function ReaSpeechControlsUI:render()
  self:render_heading()
  if self.tabs:value() == 'advanced' then
    self:render_advanced()
  else
    self:render_simple()
  end
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 5)
end

function ReaSpeechControlsUI:render_heading()
  local init_x, init_y = ImGui.GetCursorPos(ctx)

  ImGui.SetCursorPosX(ctx, init_x - 20)
  app.png_from_bytes('reaspeech-logo-small')

  ImGui.SetCursorPos(ctx, init_x + self.MARGIN_LEFT + 2, init_y)
  self.tabs:render()

  ImGui.SetCursorPos(ctx, ImGui.GetWindowWidth(ctx) - 55, init_y)
  app.png_from_bytes('heading-logo-tech-audio')

  ImGui.SetCursorPos(ctx, init_x, init_y + 40)
end

function ReaSpeechControlsUI:render_simple()
  self.model_name_buttons:render()
end

function ReaSpeechControlsUI:render_advanced()
  for row = 1, #self.advanced_layouts do
    self.advanced_layouts[row]:render()
  end
end

function ReaSpeechControlsUI:render_input_label(text)
  ImGui.Text(ctx, text)
  ImGui.Dummy(ctx, 0, 0)
end

function ReaSpeechControlsUI:render_language(column)
  self.language:render()

  self.translate:render(column)
end

function ReaSpeechControlsUI:render_model_name()
  self.model_name:render()
end

function ReaSpeechControlsUI:render_model_sizes()
  self.model_sizes_layout:render()
end

function ReaSpeechControlsUI:render_hotwords()
  self.hotwords:render()
end

function ReaSpeechControlsUI:render_options(column)
  self:render_input_label('Options')

  self.vad_filter:render(column)
end

function ReaSpeechControlsUI:render_logging()
  self:render_input_label('Logging')

  self.log_enable:render()

  if self.log_enable:value() then
    ImGui.SameLine(ctx)
    self.log_debug:render()
  end
end

function ReaSpeechControlsUI:render_initial_prompt()
  self.initial_prompt:render()
end
