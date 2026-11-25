--[[

ASRControls.lua - Controls/configuration for ASR plugin

]]--

ASRControls = PluginControls {
  DEFAULT_TAB = 'asr',

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  HELP_MODEL = 'Model to use for transcription. Larger models provide better accuracy but use more resources like disk space and memory.',
  HELP_LANGUAGE = 'Language spoken in source audio.\nSet this to "Detect" to auto-detect the language.',
  HELP_PRESERVED_WORDS = 'Comma-separated list of words to preserve in transcript.\nExample: Jane Doe, CyberCorp',
  HELP_VAD = 'Enable Voice Activity Detection (VAD) to filter out non-speech portions.',

  tabs = function(self)
    return {
      ReaSpeechPlugins.tab('asr', 'Speech Recognition',
        { render_bg = function() self:render_bg() end,
          render = function() self:render() end
        }),
    }
  end
}

function ASRControls:init()
  assert(self.plugin, 'ASRControls: plugin is required')

  Logging().init(self, 'ASRControls')

  self:init_asr_info()

  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.ASR',
    persist = true,
  }

  self.importer = TranscriptImporter.new()

  self.settings = {
    language = storage:string('language', self.DEFAULT_LANGUAGE),
    translate = storage:boolean('translate', false),
    hotwords = storage:string('hotwords', ''),
    initial_prompt = storage:string('initial_prompt', ''),
    model_name = storage:string('model_name', self.DEFAULT_MODEL_NAME),
    vad_filter = storage:boolean('vad_filter', true),
  }

  self:init_model_name()

  self.language = Widgets.Combo.new {
    state = self.settings.language,
    label = 'Language',
    help_text = self.HELP_LANGUAGE,
    items = WhisperLanguages.LANGUAGE_CODES,
    item_labels = WhisperLanguages.LANGUAGES
  }

  self.translate = Widgets.Checkbox.new {
    state = self.settings.translate,
    label_long = 'Translate to English',
    label_short = 'Translate',
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH,
    disabled_if = function() return self.model_name:value() == 'large-v3-turbo' end,
  }

  self.hotwords = Widgets.TextInput.new {
    state = self.settings.hotwords,
    label = 'Preserved Words',
    help_text = self.HELP_PRESERVED_WORDS
  }

  self.initial_prompt = Widgets.TextInput.new {
    state = self.settings.initial_prompt,
    label = 'Preserved Words',
    help_text = self.HELP_PRESERVED_WORDS
  }

  self.vad_filter = Widgets.Checkbox.new {
    state = self.settings.vad_filter,
    label_long = 'Voice Activity Detection',
    label_short = 'VAD',
    help_text = self.HELP_VAD,
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
  }

  self.actions = ASRActions.new(self.plugin)
  self.alert_popup = AlertPopup.new {}

  self:init_layouts()
end

function ASRControls:init_model_name()
  if not WhisperModels.get_model_by_name(self.settings.model_name:get()) then
    self.settings.model_name:set(self.DEFAULT_MODEL_NAME)
  end
  self:normalize_translation()
  self.model_name = Widgets.Combo.new {
    state = self.settings.model_name,
    label = 'Model',
    help_text = self.HELP_MODEL,
    items = WhisperModels.get_model_names(self.asr_engine),
    item_labels = self:get_model_labels(),
    on_change = function() self:normalize_translation() end,
  }
end

function ASRControls:normalize_translation()
  if self.settings.model_name:get() == 'large-v3-turbo' then
    self.settings.translate:set(false)
  end
end

function ASRControls:init_asr_info()
  self.asr_engine = 'reaspeech_lib'
  self.asr_options = {
    hotwords = true,
    language = true,
    vad_filter = true,
  }
end

function ASRControls:init_layouts()
  self:init_form_layout()
  self:init_actions_layout()
end

function ASRControls:init_form_layout()
  local renderers = {
    self.render_model,
    self.render_language,
  }

  if self.asr_options.hotwords then
    table.insert(renderers, self.render_hotwords)
  elseif self.asr_options.initial_prompt then
    table.insert(renderers, self.render_initial_prompt)
  end

  self.form_layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    num_columns = #renderers,

    render_column = function (column)
      ImGui.PushItemWidth(Ctx(), column.width)
      Trap(function () renderers[column.num](self, column) end)
      ImGui.PopItemWidth(Ctx())
    end
  }
end

function ASRControls:render_actions()
  local worker = self.plugin.app.worker

  local progress, status
  Trap(function ()
    progress, status = worker:progress()
  end)

  Widgets.disable_if(progress, function()
    local plugin_actions = self.actions:actions()
    for i, action in ipairs(plugin_actions) do
      if i > 1 then ImGui.SameLine(Ctx()) end
      action:render()
    end
  end)

  if progress then
    ImGui.SameLine(Ctx())
    ReaSpeechWidget.render_transcription_progress(worker, progress, status)
  end
end

function ASRControls:init_actions_layout()
  self.actions_layout = ColumnLayout.new {
    column_padding = 10,
    num_columns = 1,
    render_column = function(_column)
      self:render_actions()
    end
  }
end

function ASRControls:render_bg()
  self.importer:render()
end

function ASRControls:render()
  local panel_flags = ImGui.ChildFlags_Borders() | ImGui.ChildFlags_AutoResizeY()
  if ImGui.BeginChild(Ctx(), 'asr-form', 0, 0, panel_flags) then
    Trap(function() self.form_layout:render() end)
  end
  ImGui.EndChild(Ctx())
  self.actions_layout:render()
  self.alert_popup:render()
end

function ASRControls:render_language(column)
  if self.asr_options.language then
    self.language:render()
    self.translate:render(column)
  end
end

function ASRControls:render_model(column)
  self.model_name:render()
  if self.asr_options.vad_filter then
    self.vad_filter:render(column)
  end
end

function ASRControls:render_hotwords()
  if self.asr_options.hotwords then
    self.hotwords:render()
  end
end

function ASRControls:render_initial_prompt()
  if self.asr_options.initial_prompt then
    self.initial_prompt:render()
  end
end

function ASRControls:get_request_data()
  self:normalize_translation()
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
