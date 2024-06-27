--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  -- Copied from whisper.tokenizer.LANGUAGES
  LANGUAGES = {
    en = 'English', zh = 'Chinese', de = 'German',
    es = 'Spanish', ru = 'Russian', ko = 'Korean',
    fr = 'French', ja = 'Japanese', pt = 'Portuguese',
    tr = 'Turkish', pl = 'Polish', ca = 'Catalan',
    nl = 'Dutch', ar = 'Arabic', sv = 'Swedish',
    it = 'Italian', id = 'Indonesian', hi = 'Hindi',
    fi = 'Finnish', vi = 'Vietnamese', he = 'Hebrew',
    uk = 'Ukrainian', el = 'Greek', ms = 'Malay',
    cs = 'Czech', ro = 'Romanian', da = 'Danish',
    hu = 'Hungarian', ta = 'Tamil', no = 'Norwegian',
    th = 'Thai', ur = 'Urdu', hr = 'Croatian',
    bg = 'Bulgarian', lt = 'Lithuanian', la = 'Latin',
    mi = 'Maori', ml = 'Malayalam', cy = 'Welsh',
    sk = 'Slovak', te = 'Telugu', fa = 'Persian',
    lv = 'Latvian', bn = 'Bengali', sr = 'Serbian',
    az = 'Azerbaijani', sl = 'Slovenian', kn = 'Kannada',
    et = 'Estonian', mk = 'Macedonian', br = 'Breton',
    eu = 'Basque', is = 'Icelandic', hy = 'Armenian',
    ne = 'Nepali', mn = 'Mongolian', bs = 'Bosnian',
    kk = 'Kazakh', sq = 'Albanian', sw = 'Swahili',
    gl = 'Galician', mr = 'Marathi', pa = 'Punjabi',
    si = 'Sinhala', km = 'Khmer', sn = 'Shona',
    yo = 'Yoruba', so = 'Somali', af = 'Afrikaans',
    oc = 'Occitan', ka = 'Georgian', be = 'Belarusian',
    tg = 'Tajik', sd = 'Sindhi', gu = 'Gujarati',
    am = 'Amharic', yi = 'Yiddish', lo = 'Lao',
    uz = 'Uzbek', fo = 'Faroese', ht = 'Haitian creole',
    ps = 'Pashto', tk = 'Turkmen', nn = 'Nynorsk',
    mt = 'Maltese', sa = 'Sanskrit', lb = 'Luxembourgish',
    my = 'Myanmar', bo = 'Tibetan', tl = 'Tagalog',
    mg = 'Malagasy', as = 'Assamese', tt = 'Tatar',
    haw = 'Hawaiian', ln = 'Lingala', ha = 'Hausa',
    ba = 'Bashkir', jw = 'Javanese', su = 'Sundanese'
  },

  LANGUAGE_CODES = {},

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',

  SIMPLE_MODEL_SIZES = {
    {'Small', 'small'},
    {'Medium', 'medium'},
    {'Large', 'distil-large-v3'},
  },

  MARGIN_LEFT = 110,
  MARGIN_RIGHT = 10,

  NARROW_COLUMN_WIDTH = 150,
}

function ReaSpeechControlsUI:init()
  self.tab = 'simple'

  self.log_enable = false
  self.log_debug = false

  self.language = self.DEFAULT_LANGUAGE
  self.translate = false
  self.hotwords = ''
  self.initial_prompt = ''
  self.model_name = self.DEFAULT_MODEL_NAME
  self.vad_filter = true
end

function ReaSpeechControlsUI:get_request_data()
  return {
    language = self.language,
    translate = self.translate,
    hotwords = self.hotwords,
    initial_prompt = self.initial_prompt,
    model_name = self.model_name,
    vad_filter = self.vad_filter,
  }
end

ReaSpeechControlsUI._init_languages = function ()
  for code, _ in pairs(ReaSpeechControlsUI.LANGUAGES) do
    table.insert(ReaSpeechControlsUI.LANGUAGE_CODES, code)
  end

  table.sort(ReaSpeechControlsUI.LANGUAGE_CODES, function (a, b)
    return ReaSpeechControlsUI.LANGUAGES[a] < ReaSpeechControlsUI.LANGUAGES[b]
  end)

  table.insert(ReaSpeechControlsUI.LANGUAGE_CODES, 1, '')
  ReaSpeechControlsUI.LANGUAGES[''] = 'Detect'
end

ReaSpeechControlsUI._init_languages()

function ReaSpeechControlsUI:render()
  self:render_heading()
  if self.tab == 'advanced' then
    self:render_advanced()
  else
    self:render_simple()
  end
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 5)
end

function ReaSpeechControlsUI:render_heading()
  local init_x, init_y = ImGui.GetCursorPos(ctx)

  ImGui.SetCursorPos(ctx, init_x - 20, init_y)
  app.png_from_bytes('reaspeech-logo-small')

  ImGui.SetCursorPos(ctx, self.MARGIN_LEFT + 15, init_y)
  self:render_tabs()

  ImGui.SetCursorPos(ctx, ImGui.GetWindowWidth(ctx) - 55, init_y)
  app.png_from_bytes('heading-logo-tech-audio')

  ImGui.SetCursorPos(ctx, init_x, init_y + 40)
end

function ReaSpeechControlsUI:render_tabs()
  if ImGui.BeginTabBar(ctx, '##tabs', ImGui.TabBarFlags_None()) then
    app:trap(function ()
      if ImGui.BeginTabItem(ctx, 'Simple') then
        app:trap(function ()
          self.tab = 'simple'
          ImGui.EndTabItem(ctx)
        end)
      end
      if ImGui.BeginTabItem(ctx, 'Advanced') then
        app:trap(function ()
          self.tab = 'advanced'
          ImGui.EndTabItem(ctx)
        end)
      end
      ImGui.EndTabBar(ctx)
    end)
  end
end

function ReaSpeechControlsUI:render_simple()
  ImGui.Dummy(ctx, self.MARGIN_LEFT, 0)
  ImGui.SameLine(ctx)
  self:render_model_sizes()
end

function ReaSpeechControlsUI:render_advanced()
  local renderers = {
    {self.render_model_name, self.render_hotwords, self.render_language},
    {self.render_options, self.render_initial_prompt, self.render_logging},
  }

  for row = 1, #renderers do
    local layout = ColumnLayout.new {
      column_padding = 20,
      margin_bottom = 5,
      margin_left = self.MARGIN_LEFT,
      margin_right = self.MARGIN_RIGHT,
      num_columns = #renderers[row],
      render_column = function (column)
        ImGui.PushItemWidth(ctx, column.width)
        app:trap(function () renderers[row][column.num](self, column) end)
        ImGui.PopItemWidth(ctx)
      end
    }
    layout:render()
  end
end

function ReaSpeechControlsUI:render_language(column)
  ImGui.Text(ctx, 'Language')
  if ImGui.BeginCombo(ctx, "##language", self.LANGUAGES[self.language]) then
    app:trap(function()
      local combo_items = self.LANGUAGE_CODES
      for _, combo_item in pairs(combo_items) do
        local is_selected = (combo_item == self.language)
        if ImGui.Selectable(ctx, self.LANGUAGES[combo_item], is_selected) then
          self.language = combo_item
        end
      end
    end)
    ImGui.EndCombo(ctx)
  end
  local translate_label = "Translate to English"
  if column.width < self.NARROW_COLUMN_WIDTH then
    translate_label = "Translate"
  end
  local rv, value = ImGui.Checkbox(ctx, translate_label, self.translate)
  if rv then
    self.translate = value
  end
end

function ReaSpeechControlsUI:render_model_name()
  ImGui.Text(ctx, 'Model Name')
  local rv, value = ImGui.InputTextWithHint(ctx, '##model_name', self.model_name or "<default>")
  if rv then
    self.model_name = value
  end
end

function ReaSpeechControlsUI:render_model_sizes()
  ImGui.Text(ctx, 'Model Size')

  function with_button_color(selected, f)
    if selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button(), Theme.colors.dark_gray_translucent)
      app:trap(f)
      ImGui.PopStyleColor(ctx)
    else
      f()
    end
  end

  local layout = ColumnLayout.new {
    column_padding = 10,
    margin_bottom = 5,
    margin_left = self.MARGIN_LEFT,
    margin_right = self.MARGIN_RIGHT,
    num_columns = #self.SIMPLE_MODEL_SIZES,
    render_column = function (column)
      local label, model_name = table.unpack(self.SIMPLE_MODEL_SIZES[column.num])
      with_button_color(self.model_name == model_name, function ()
        if ImGui.Button(ctx, label, column.width) then
          self.model_name = model_name
        end
      end)
    end
  }
  layout:render()
end

function ReaSpeechControlsUI:render_hotwords()
  ImGui.Text(ctx, 'Hot Words')
  local rv, value = ImGui.InputText(ctx, '##hotwords', self.hotwords)
  if rv then
    self.hotwords = value
  end
end

function ReaSpeechControlsUI:render_options(column)
  ImGui.Text(ctx, 'Options')
  local vad_label = "Voice Activity Detection"
  if column.width < self.NARROW_COLUMN_WIDTH then
    vad_label = "VAD"
  end
  local rv, value = ImGui.Checkbox(ctx, vad_label, self.vad_filter)
  if rv then
    self.vad_filter = value
  end
end

function ReaSpeechControlsUI:render_logging()
  ImGui.Text(ctx, 'Logging')
  local rv, value = ImGui.Checkbox(ctx, "Enable", self.log_enable)
  if rv then
    self.log_enable = value
  end

  if self.log_enable then
    ImGui.SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, "Debug", self.log_debug)
    if rv then
      self.log_debug = value
    end
  end
end

function ReaSpeechControlsUI:render_initial_prompt()
  ImGui.Text(ctx, 'Initial Prompt')
  rv, value = ImGui.InputText(ctx, '##initial_prompt', self.initial_prompt)
  if rv then
    self.initial_prompt = value
  end
end
