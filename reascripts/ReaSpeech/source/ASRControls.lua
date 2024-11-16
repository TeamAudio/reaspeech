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

  self:init_asr_info()

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
    label = 'Preserved Words'
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
    items = WhisperModels.get_model_names(self.asr_engine),
    item_labels = self:get_model_labels(),
  }

  self:init_layouts()
end

function ASRControls:init_asr_info()
  local asr_info = ReaSpeechAPI:fetch_json('asr_info', 'GET', function(error_message)
    self:debug("Error getting ASR info: " .. error_message)
  end)
  self.asr_engine = asr_info and asr_info.engine
  self.asr_options = {}
  if asr_info and asr_info.options then
    for _, option in pairs(asr_info.options) do
      self.asr_options[option] = true
    end
  end
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
    label_long = 'Logging',
    label_short = 'Log',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.log_debug = ReaSpeechCheckbox.new {
    state = Logging.show_debug_logs,
    label_long = 'Debug',
    label_short = 'Debug',
  }
end

function ASRControls:init_layouts()
  self:init_simple_layout()
  self:init_advanced_layout()
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

function ASRControls:init_advanced_layout()
  local renderers = {
    {self.render_model, self.render_options},
    {self.asr_options.hotwords and self.render_hotwords or self.render_initial_prompt},
    {self.render_language},
  }

  self.advanced_layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = #renderers,

    render_column = function (column)
      ImGui.PushItemWidth(ctx, column.width)
      for row, renderer in ipairs(renderers[column.num]) do
        if row > 1 then ImGui.Spacing(ctx) end
        app:trap(function () renderer(self, column) end)
      end
      ImGui.PopItemWidth(ctx)
    end
  }
end

function ASRControls:render_simple()
  self.simple_layout:render()
end

function ASRControls:render_advanced()
  self.advanced_layout:render()
end

function ASRControls:render_language(column)
  if self.asr_options.language then
    self.language:render()
    self.translate:render(column)
  end
end

function ASRControls:render_model()
  self.model_combo:render()
end

function ASRControls:render_hotwords()
  if self.asr_options.hotwords then
    self.hotwords:render()
  end
end

function ASRControls:render_options(column)
  ReaSpeechControlsUI:render_input_label('Options')

  self.log_enable:render(column)

  if self.log_enable:value() then
    ImGui.SameLine(ctx)
    self.log_debug:render()
  end

  if self.asr_options.vad_filter then
    self.vad_filter:render(column)
  end
end

function ASRControls:render_initial_prompt()
  if self.asr_options.initial_prompt then
    self.initial_prompt:render()
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
