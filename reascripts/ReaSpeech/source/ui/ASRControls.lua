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
    width_threshold = ReaSpeechControlsUI.NARROW_COLUMN_WIDTH
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
  self.model_name = Widgets.Combo.new {
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

  local request = CurlRequest().async {
    url = ReaSpeechAPI:get_api_url('asr_info'),
    method = 'GET',
  }

  self.asr_info_request = request:execute()
end

function ASRControls:check_asr_info()
  if self.asr_engine or not self.asr_info_request then return end

  if self.asr_info_request:error() then
    self.alert_popup.onclose = function()
      self:init_asr_info()
      self.alert_popup.onclose = nil
    end

    self.alert_popup:show('Whoops!', self.asr_info_request:error())
    self.asr_info_request = nil
    return
  end

  if self.asr_info_request:ready() then
    local asr_info = self.asr_info_request:result()
    self:debug(dump(asr_info))

    self.asr_engine = asr_info and asr_info.engine

    if asr_info and asr_info.options then
      for _, option in pairs(asr_info.options) do
        self.asr_options[option] = true
      end
    end

    self:init_model_name()
    self:init_advanced_layout()
  end
end

function ASRControls:init_layouts()
  self:init_simple_layout()
  self:init_advanced_layout()
  self:init_actions_layout()
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
      ImGui.PushItemWidth(Ctx(), column.width)
      Trap(function () renderers[column.num](self, column) end)
      ImGui.PopItemWidth(Ctx())
    end
  }
end

function ASRControls:_get_renderers()
  local renderers = {}
  if self.asr_options.vad_filter then
    table.insert(renderers, {
      self.render_vad_filter
    })
  end

  if self.asr_options.hotwords then
    table.insert(renderers, {
      self.render_hotwords
    })
  else
    table.insert(renderers, {
      self.render_initial_prompt
    })
  end

  table.insert(renderers, {
    self.render_language
  })

  return renderers
end

function ASRControls:init_advanced_layout()
  local renderers = self:_get_renderers()

  self.advanced_layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = #renderers,

    render_column = function (column)
      ImGui.PushItemWidth(Ctx(), column.width)
      for row, renderer in ipairs(renderers[column.num]) do
        if row > 1 then ImGui.Spacing(Ctx()) end
        Trap(function () renderer(self, column) end)
      end
      ImGui.PopItemWidth(Ctx())
    end
  }
end

function ASRControls:render_actions()
  local worker = self.plugin.app.worker

  local progress
  Trap(function ()
    progress = worker:progress()
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

    if ImGui.Button(Ctx(), "Cancel") then
      worker:cancel()
    end

    ImGui.SameLine(Ctx())
    local overlay = string.format("%.0f%%", progress * 100)
    local status = worker:status()
    if status then
      overlay = overlay .. ' - ' .. status
    end
    ImGui.ProgressBar(Ctx(), progress, nil, nil, overlay)
  end
end

function ASRControls:init_actions_layout()
  self.actions_layout = ColumnLayout.new {
    column_padding = 10,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
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
  self:check_asr_info()
  self.simple_layout:render()
  ImGui.Unindent(Ctx())
  ImGui.Dummy(Ctx(), ReaSpeechControlsUI.MARGIN_LEFT, 0)
  ImGui.SameLine(Ctx())
  if ImGui.TreeNode(Ctx(), "Advanced Options") then
    self.advanced_layout:render()
    ImGui.TreePop(Ctx())
  end
  ImGui.Indent(Ctx())
  ImGui.Spacing(Ctx())
  self.actions_layout:render()
self.alert_popup:render()
end

function ASRControls:render_language(column)
  if self.asr_options.language then
    self.language:render()
    ImGui.Spacing(Ctx())
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

function ASRControls:render_vad_filter(column)
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
