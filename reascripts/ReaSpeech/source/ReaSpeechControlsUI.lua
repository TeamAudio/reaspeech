--[[

ReaSpeechControlsUI.lua - UI elements for configuring ASR services

]]--

ReaSpeechControlsUI = Polo {
  -- Copied from whisper.tokenizer.LANGUAGES
  LANGUAGES = {
    en = 'english', zh = 'chinese', de = 'german',
    es = 'spanish', ru = 'russian', ko = 'korean',
    fr = 'french', ja = 'japanese', pt = 'portuguese',
    tr = 'turkish', pl = 'polish', ca = 'catalan',
    nl = 'dutch', ar = 'arabic', sv = 'swedish',
    it = 'italian', id = 'indonesian', hi = 'hindi',
    fi = 'finnish', vi = 'vietnamese', he = 'hebrew',
    uk = 'ukrainian', el = 'greek', ms = 'malay',
    cs = 'czech', ro = 'romanian', da = 'danish',
    hu = 'hungarian', ta = 'tamil', no = 'norwegian',
    th = 'thai', ur = 'urdu', hr = 'croatian',
    bg = 'bulgarian', lt = 'lithuanian', la = 'latin',
    mi = 'maori', ml = 'malayalam', cy = 'welsh',
    sk = 'slovak', te = 'telugu', fa = 'persian',
    lv = 'latvian', bn = 'bengali', sr = 'serbian',
    az = 'azerbaijani', sl = 'slovenian', kn = 'kannada',
    et = 'estonian', mk = 'macedonian', br = 'breton',
    eu = 'basque', is = 'icelandic', hy = 'armenian',
    ne = 'nepali', mn = 'mongolian', bs = 'bosnian',
    kk = 'kazakh', sq = 'albanian', sw = 'swahili',
    gl = 'galician', mr = 'marathi', pa = 'punjabi',
    si = 'sinhala', km = 'khmer', sn = 'shona',
    yo = 'yoruba', so = 'somali', af = 'afrikaans',
    oc = 'occitan', ka = 'georgian', be = 'belarusian',
    tg = 'tajik', sd = 'sindhi', gu = 'gujarati',
    am = 'amharic', yi = 'yiddish', lo = 'lao',
    uz = 'uzbek', fo = 'faroese', ht = 'haitian creole',
    ps = 'pashto', tk = 'turkmen', nn = 'nynorsk',
    mt = 'maltese', sa = 'sanskrit', lb = 'luxembourgish',
    my = 'myanmar', bo = 'tibetan', tl = 'tagalog',
    mg = 'malagasy', as = 'assamese', tt = 'tatar',
    haw = 'hawaiian', ln = 'lingala', ha = 'hausa',
    ba = 'bashkir', jw = 'javanese', su = 'sundanese'
  },
  LANGUAGE_CODES = {},
  DEFAULT_LANGUAGE = 'en',

  ITEM_WIDTH = 125,
  LARGE_ITEM_WIDTH = 375,
}

function ReaSpeechControlsUI:init()
  self.log_enable = false
  self.log_debug = false

  self.language = self.DEFAULT_LANGUAGE
  self.translate = false
  self.initial_prompt = ''
  self.model_name = nil
end

function ReaSpeechControlsUI:get_request_data()
  return {
    language = self.language,
    translate = self.translate,
    initial_prompt = self.initial_prompt,
    model_name = self.model_name,
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
  ReaSpeechControlsUI.LANGUAGES[''] = 'detect'
end

ReaSpeechControlsUI._init_languages()

function ReaSpeechControlsUI:render()
  --start input table so logo and inputs sit side-by-side
  if ImGui.BeginTable(ctx, 'InputTable', 2) then
    app:trap(function()
      --column settings
      ImGui.TableSetupColumn(ctx, 'Logo', ImGui.TableColumnFlags_WidthFixed())
      ImGui.TableSetupColumn(ctx, 'Inputs', ImGui.TableColumnFlags_WidthFixed())
      -- first column
      ImGui.TableNextColumn(ctx)
      ImGui.SameLine(ctx, -10)
      app.png_from_bytes('reaspeech-logo-small')
      -- second column
      ImGui.TableNextColumn(ctx)
      -- start language selection
      self:render_language_controls()
      ImGui.Dummy(ctx,0, 10)
      self:render_advanced_controls()
    end)
    ImGui.EndTable(ctx)
  end
  -- end input table
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH + 65)
  app.png_from_bytes('heading-logo-tech-audio')
end

function ReaSpeechControlsUI:render_language_controls()
  if ImGui.TreeNode(ctx, 'Language Options', ImGui.TreeNodeFlags_DefaultOpen()) then
    app:trap(function()
      ImGui.Dummy(ctx, 0, 25)
      ImGui.SameLine(ctx)
      if ImGui.BeginCombo(ctx, "language", self.LANGUAGES[self.language]) then
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
      local rv, value
      ImGui.SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, "translate", self.translate)
      if rv then
        self.translate = value
      end
    end)

    ImGui.TreePop(ctx)
  end
end

function ReaSpeechControlsUI:render_advanced_controls()
  local rv, value

  if ImGui.TreeNode(ctx, 'Advanced Options') then
    app:trap(function()
      ImGui.Dummy(ctx, 0, 25)

      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
      app:trap(function ()
        rv, value = ImGui.InputText(ctx, 'initial prompt', self.initial_prompt)
        if rv then
          self.initial_prompt = value
        end
      end)
      ImGui.PopItemWidth(ctx)

      ImGui.SameLine(ctx)
      ImGui.PushItemWidth(ctx, 100)
      app:trap(function ()
        rv, value = ImGui.InputTextWithHint(ctx, 'model name', self.model_name or "<default>")
        if rv then
          self.model_name = value
        end
      end)
      ImGui.PopItemWidth(ctx)

      ImGui.SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, "log", self.log_enable)
      if rv then
        self.log_enable = value
      end

      if self.log_enable then
        ImGui.SameLine(ctx)
        rv, value = ImGui.Checkbox(ctx, "debug", self.log_debug)
        if rv then
          self.log_debug = value
        end
      end
    end)

    ImGui.TreePop(ctx)
    ImGui.Spacing(ctx)
  end
end
