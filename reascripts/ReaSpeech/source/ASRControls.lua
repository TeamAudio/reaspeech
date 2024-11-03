--[[

ASRControls.lua - Controls/configuration for ASR plugin

]]--

ASRControls = PluginControls {
  DEFAULT_TAB = 'asr-simple',

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  tabs = function(self)
    return {
      ReaSpeechPlugins.tab('asr-simple', 'Simple',
        function() self:render_simple() end),
      ReaSpeechPlugins.tab('asr-advanced', 'Advanced',
        function() self:render_advanced() end),
    }
  end
}

function ASRControls:init()
  assert(self.plugin, 'ASRControls: plugin is required')

  Logging.init(self, 'ASRControls')
  self:init_logging()

  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.ASR',
    persist = true,
  }

  self.settings = {
    language = storage:string('language', self.DEFAULT_LANGUAGE),
    translate = storage:boolean('translate', false),
    hotwords = storage:string('hotwords', ''),
    initial_prompt = storage:string('initial_prompt', ''),
    model_name = storage:string('model_name', self.DEFAULT_MODEL_NAME),
    vad_filter = storage:boolean('vad_filter', true),
  }

  self.language = ReaSpeechCombo.new {
    state = self.settings.language,
    label = 'Language',
    items = WhisperLanguages.LANGUAGE_CODES,
    item_labels = WhisperLanguages.LANGUAGES
  }

  self.translate = ReaSpeechCheckbox.new {
    state = self.settings.translate,
    label_long = 'Translate to English',
    label_short = 'Translate',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.hotwords = ReaSpeechTextInput.new {
    state = self.settings.hotwords,
    label = 'Hot Words'
  }

  self.initial_prompt = ReaSpeechTextInput.new {
    state = self.settings.initial_prompt,
    label = 'Initial Prompt'
  }

  self.model_name = ReaSpeechTextInput.new {
    state = self.settings.model_name,
    label = 'Model Name'
  }

  self.vad_filter = ReaSpeechCheckbox.new {
    state = self.settings.vad_filter,
    label_long = 'Voice Activity Detection',
    label_short = 'VAD',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.model_combo = ReaSpeechCombo.new {
    state = self.settings.model_name,
    label = 'Model',
    items = WhisperModels.get_model_names(),
    item_labels = self:get_model_labels(),
  }

  self:init_layouts()
end

function ASRControls:init_logging()
  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.Logging',
    persist = true,
  }

  Logging.show_logs = storage:boolean('show_logs', false)
  Logging.show_debug_logs = storage:boolean('show_debug_logs', false)

  self.log_enable = ReaSpeechCheckbox.new {
    state = Logging.show_logs,
    label_long = 'Log',
    label_short = 'Log',
  }

  self.log_debug = ReaSpeechCheckbox.new {
    state = Logging.show_debug_logs,
    label_long = 'Debug',
    label_short = 'Debug',
  }
end

function ASRControls:init_layouts()
  self:init_simple_layout()
  self:init_advanced_layouts()
end

function ASRControls:init_simple_layout()
  local renderers = {self.render_model}

  self.simple_layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = #renderers,

    render_column = function (column)
      ImGui.PushItemWidth(ctx, column.width)
      app:trap(function () renderers[column.num](self, column) end)
      ImGui.PopItemWidth(ctx)
    end
  }
end

function ASRControls:init_advanced_layouts()
  local renderers = {
    {self.render_model, self.render_hotwords, self.render_language},
    {self.render_options, self.render_initial_prompt, self.render_logging},
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
  self.simple_layout:render()
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

function ASRControls:render_model()
  self.model_combo:render()
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

function ASRControls:render_logging()
  ReaSpeechControlsUI:render_input_label('Logging')

  self.log_enable:render()

  if self.log_enable:value() then
    ImGui.SameLine(ctx)
    self.log_debug:render()
  end
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

function ASRControls:get_model_labels()
  local model_labels = {}

  for _, model in pairs(WhisperModels.MODELS) do
    model_labels[model.name] = model.label
    if model.lang then
      model_labels[model.name] = model.label .. ' (' .. WhisperLanguages.LANGUAGES[model.lang] .. ')'
    end
  end

  return model_labels
end
