--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  DEFAULT_TAB = 'simple',

  TABS = {
    ReaSpeechTabBar.tab('simple', 'Simple'),
    ReaSpeechTabBar.tab('advanced', 'Advanced'),
  },

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
    uz = 'Uzbek', fo = 'Faroese', ht = 'Haitian Creole',
    ps = 'Pashto', tk = 'Turkmen', nn = 'Nynorsk',
    mt = 'Maltese', sa = 'Sanskrit', lb = 'Luxembourgish',
    my = 'Myanmar', bo = 'Tibetan', tl = 'Tagalog',
    mg = 'Malagasy', as = 'Assamese', tt = 'Tatar',
    haw = 'Hawaiian', ln = 'Lingala', ha = 'Hausa',
    ba = 'Bashkir', jw = 'Javanese', su = 'Sundanese'
  },

  DEFAULT_LANGUAGE = '',
  DEFAULT_MODEL_NAME = 'small',
  DEFAULT_BLANK_STRING = '',

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

ReaSpeechControlsUI._init_languages = function ()
  local code_list = {}
  for code, _ in pairs(ReaSpeechControlsUI.LANGUAGES) do
    table.insert(code_list, code)
  end

  table.sort(code_list, function (a, b)
    return ReaSpeechControlsUI.LANGUAGES[a] < ReaSpeechControlsUI.LANGUAGES[b]
  end)

  table.insert(code_list, 1, '')
  ReaSpeechControlsUI.LANGUAGES[''] = 'Detect'

  return code_list, ReaSpeechControlsUI.LANGUAGES
end

function ReaSpeechControlsUI:init()
  self.tabs = ReaSpeechTabBar.new(self.DEFAULT_TAB, self.TABS)
  self.log_enable = ReaSpeechCheckbox.new(false, 'Enable')
  self.log_debug = ReaSpeechCheckbox.new(false, 'Debug')

  self.language = ReaSpeechCombo.new(self.DEFAULT_LANGUAGE, 'Language', self._init_languages())
  self.translate = ReaSpeechCheckbox.new(false, 'Translate to English', 'Translate', self.NARROW_COLUMN_WIDTH)

  self.hotwords = ReaSpeechTextInput.new(self.DEFAULT_BLANK_STRING, 'Hot Words')
  self.initial_prompt = ReaSpeechTextInput.new(self.DEFAULT_BLANK_STRING, 'Initial Prompt')
  self.model_name = ReaSpeechTextInput.new(self.DEFAULT_MODEL_NAME, 'Model Name', self.DEFAULT_MODEL_NAME)
  self.vad_filter = ReaSpeechCheckbox.new(true, 'Voice Activity Detection', 'VAD', self.NARROW_COLUMN_WIDTH)

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
  self:init_simple_layouts()
  self:init_advanced_layouts()
end

function ReaSpeechControlsUI:init_simple_layouts()
  local with_button_color = function (selected, f)
    if selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button(), Theme.colors.dark_gray_translucent)
      app:trap(f)
      ImGui.PopStyleColor(ctx)
    else
      f()
    end
  end

  self.model_sizes_layout = ColumnLayout.new {
    column_padding = self.COLUMN_PADDING,
    margin_bottom = self.MARGIN_BOTTOM,
    margin_left = self.MARGIN_LEFT,
    margin_right = self.MARGIN_RIGHT,
    num_columns = #self.SIMPLE_MODEL_SIZES,

    render_column = function (column)
      self:render_input_label(column.num == 1 and 'Model Size' or '')
      local label, model_name = table.unpack(self.SIMPLE_MODEL_SIZES[column.num])
      with_button_color(self.model_name:value() == model_name, function ()
        if ImGui.Button(ctx, label, column.width) then
          self.model_name._value = model_name
        end
      end)
    end
  }
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
  self:render_tabs()

  ImGui.SetCursorPos(ctx, ImGui.GetWindowWidth(ctx) - 55, init_y)
  app.png_from_bytes('heading-logo-tech-audio')

  ImGui.SetCursorPos(ctx, init_x, init_y + 40)
end

function ReaSpeechControlsUI:render_tabs()
  self.tabs:render()
end

function ReaSpeechControlsUI:render_simple()
  self:render_model_sizes()
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
