--[[

ASRControls.lua - Controls/configuration for ASR plugin

]]--

ASRControls = PluginControls {
  DEFAULT_TAB = 'asr-simple',

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  HELP_MODEL = 'Model to use for transcription. Larger models provide better accuracy but use more resources like disk space and memory.',
  HELP_LANGUAGE = 'Language spoken in source audio.\nSet this to "Detect" to auto-detect the language.',
  HELP_PRESERVED_WORDS = 'Comma-separated list of words to preserve in transcript.\nExample: Jane Doe, CyberCorp',
  HELP_VAD = 'Enable Voice Activity Detection (VAD) to filter out silence.',

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

  self:init_model_name()

  self.language = ReaSpeechCombo.new {
    state = self.settings.language,
    label = 'Language',
    help_text = self.HELP_LANGUAGE,
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
    label = 'Preserved Words',
    help_text = self.HELP_PRESERVED_WORDS
  }

  self.initial_prompt = ReaSpeechTextInput.new {
    state = self.settings.initial_prompt,
    label = 'Preserved Words',
    help_text = self.HELP_PRESERVED_WORDS
  }

  self.vad_filter = ReaSpeechCheckbox.new {
    state = self.settings.vad_filter,
    label_long = 'Voice Activity Detection',
    label_short = 'VAD',
    help_text = self.HELP_VAD,
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self:init_layouts()
end

function ASRControls:init_model_name()
  self.model_name = ReaSpeechCombo.new {
    state = self.settings.model_name,
    label = 'Model',
    help_text = self.HELP_MODEL,
    items = WhisperModels.get_model_names(self.asr_engine),
    item_labels = self:get_model_labels(),
  }
end

function ASRControls:init_asr_info()
  self.asr_engine = nil
  self.asr_options = {}

  local request = CurlRequest.async {
    url = ReaSpeechAPI:get_api_url('asr_info'),
    method = 'GET',
  }

  self.asr_info_request = request:execute()
end

function ASRControls:check_asr_info()
  if self.asr_engine then return end

  if self.asr_info_request and self.asr_info_request:ready() then
    local asr_info = self.asr_info_request:result()
    self:debug(dump(asr_info))

    self.asr_engine = asr_info and asr_info.engine

    if asr_info and asr_info.options then
      for _, option in pairs(asr_info.options) do
        self.asr_options[option] = true
      end
    end

    self:init_model_name()
  end
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
      Trap(function () renderers[column.num](self, column) end)
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
        Trap(function () renderer(self, column) end)
      end
      ImGui.PopItemWidth(ctx)
    end
  }
end

function ASRControls:render_simple()
  self:check_asr_info()
  self.simple_layout:render()
end

function ASRControls:render_advanced()
  self:check_asr_info()
  self.advanced_layout:render()
end

function ASRControls:render_language(column)
  if self.asr_options.language then
    self.language:render()
    ImGui.Spacing(ctx)
    self.translate:render(column)
  end
end

function ASRControls:render_model()
  self.model_name:render()
end

function ASRControls:render_hotwords()
  if self.asr_options.hotwords then
    self.hotwords:render()
  end
end

function ASRControls:render_options(column)
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
  local request_data = {
    language = self.language:value(),
    translate = self.translate:value(),
    model_name = self.model_name:value(),
    vad_filter = self.vad_filter:value(),
  }
  if self.asr_options.hotwords then
    request_data.hotwords = self.hotwords:value()
  else
    request_data.initial_prompt = self.initial_prompt:value()
  end
  return request_data
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
