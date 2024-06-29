--[[

  WhisperLanguages.lua - A list of languages supported by the Whisper API

]]--

WhisperLanguages = {
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
  }
}

WhisperLanguages.init = function()
  local code_list = {}
  for code, _ in pairs(WhisperLanguages.LANGUAGES) do
    table.insert(code_list, code)
  end

  table.sort(code_list, function (a, b)
    return WhisperLanguages.LANGUAGES[a] < WhisperLanguages.LANGUAGES[b]
  end)

  table.insert(code_list, 1, '')
  WhisperLanguages.LANGUAGES[''] = 'Detect'

  return code_list, WhisperLanguages.LANGUAGES
end