--[[

ASRControls.lua - Controls/configuration for ASR plugin

]]--

ASRControls = Polo {
  DEFAULT_TAB = 'asr-simple',

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  SIMPLE_MODEL_SIZES = {
    {'Small', 'small'},
    {'Medium', 'medium'},
    {'Large', 'distil-large-v3'},
  },

  new = function(plugin)
    return {
      plugin = plugin
    }
  end,
}

function ASRControls:init()
  assert(self.plugin, 'ASRControls: plugin is required')

  Logging.init(self, 'ASRControls')

  self.language = ReaSpeechCombo.new {
    default = self.DEFAULT_LANGUAGE,
    label = 'Language',
    items = WhisperLanguages.LANGUAGE_CODES,
    item_labels = WhisperLanguages.LANGUAGES
  }

  self.translate = ReaSpeechCheckbox.new {
    default = false,
    label_long = 'Translate to English',
    label_short = 'Translate',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.hotwords = ReaSpeechTextInput.simple('', 'Hot Words')
  self.initial_prompt = ReaSpeechTextInput.simple('', 'Initial Prompt')
  self.model_name = ReaSpeechTextInput.simple(self.DEFAULT_MODEL_NAME, 'Model Name')

  self.vad_filter = ReaSpeechCheckbox.new {
    default = true,
    label_long = 'Voice Activity Detection',
    label_short = 'VAD',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.model_name_buttons = ReaSpeechButtonBar.new {
    default = self.DEFAULT_MODEL_NAME,
    label = 'Model Name',
    buttons = self.SIMPLE_MODEL_SIZES,
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
  }
  self.model_name_buttons.on_set = function()
    self.model_name:set(self.model_name_buttons:value())
  end

  self:init_layouts()
end

function ASRControls:tabs()
  return {
    { tab = ReaSpeechTabBar.tab('asr-simple', 'ASR - Simple'),
      render = function(_) self:render_simple() end,
      is_selected = function(_, key) return key == 'asr-simple' end },
    { tab = ReaSpeechTabBar.tab('asr-advanced', 'ASR - Advanced'),
      render = function(_) self:render_advanced() end,
      is_selected = function(_, key) return key == 'asr-advanced' end },
  }
end

function ASRControls:init_layouts()
  self:init_advanced_layouts()
end

function ASRControls:init_advanced_layouts()
  local renderers = {
    {self.render_model_name, self.render_hotwords, self.render_language},
    {self.render_options, self.render_initial_prompt, function() end },
  }

  self.advanced_layouts = {}

  for row = 1, #renderers do
    self.advanced_layouts[row] = ColumnLayout.new {
      column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
      margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
      margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
      margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
      num_columns = #renderers[row],

      render_column = function (column)
        ImGui.PushItemWidth(ctx, column.width)
        app:trap(function () renderers[row][column.num](self, column) end)
        ImGui.PopItemWidth(ctx)
      end
    }
  end
end

function ASRControls:render_simple()
  self.model_name_buttons:render()
end

function ASRControls:render_advanced()
  for row = 1, #self.advanced_layouts do
    self.advanced_layouts[row]:render()
  end
end

function ASRControls:render_language(column)
  self.language:render()

  self.translate:render(column)
end

function ASRControls:render_model_name()
  self.model_name:render()
end

function ASRControls:render_model_sizes()
  self.model_sizes_layout:render()
end

function ASRControls:render_hotwords()
  self.hotwords:render()
end

function ASRControls:render_options(column)
  ReaSpeechControlsUI:render_input_label('Options')

  self.vad_filter:render(column)
end

function ASRControls:render_initial_prompt()
  self.initial_prompt:render()
end

function ASRControls:get_request_data()
  return {
    language = self.language:value(),
    translate = self.translate:value(),
    hotwords = self.hotwords:value(),
    initial_prompt = self.initial_prompt:value(),
    model_name = self.model_name:value(),
    vad_filter = self.vad_filter:value(),
  }
end
