--[[

  TextNormalizer.lua - text normalization for script/transcript matching

  Folds case, punctuation, and unicode variants so that script text and
  Whisper transcript text can be compared on equal terms. A single source
  word may normalize to zero tokens (pure punctuation), one token, or
  several (hyphenated compounds split into their parts).

  Pure module: no dependencies, safe to use outside the REAPER runtime.

]]--

TextNormalizer = {
  -- Byte-sequence replacements applied before tokenizing. Written as
  -- \u{} escapes so this source file stays ASCII.
  REPLACEMENTS = {
    { '\u{2018}', "'" },  -- left single quote
    { '\u{2019}', "'" },  -- right single quote / curly apostrophe
    { '\u{201C}', ' ' },  -- left double quote
    { '\u{201D}', ' ' },  -- right double quote
    { '\u{2013}', '-' },  -- en dash
    { '\u{2014}', '-' },  -- em dash
    { '\u{2026}', ' ' },  -- ellipsis
    { '\u{00A0}', ' ' },  -- non-breaking space
    { '&', ' and ' },
  },

  -- Single-token equivalences applied after normalization, mapping common
  -- transcription/script variants onto one canonical form.
  ALIASES = {
    ['ok'] = 'okay',
    ['0'] = 'zero',
    ['1'] = 'one',
    ['2'] = 'two',
    ['3'] = 'three',
    ['4'] = 'four',
    ['5'] = 'five',
    ['6'] = 'six',
    ['7'] = 'seven',
    ['8'] = 'eight',
    ['9'] = 'nine',
    ['10'] = 'ten',
  },
}

-- Remove bracketed stage directions -- "[Gasps.]", "{With a sigh}",
-- "(beat)" -- which appear in script text but are never spoken.
function TextNormalizer.strip_stage_directions(text)
  local s = text:gsub('%b[]', ' ')
  s = s:gsub('%b{}', ' ')
  s = s:gsub('%b()', ' ')
  return s
end

-- Normalize a run of text into a flat list of comparable tokens.
-- Splits on whitespace and hyphens, so "well-known" and "well known"
-- produce the same token sequence.
function TextNormalizer.tokenize(text)
  local s = text:lower()

  for _, replacement in ipairs(TextNormalizer.REPLACEMENTS) do
    s = s:gsub(replacement[1], replacement[2])
  end

  local tokens = {}
  for word in s:gmatch('[^%s%-]+') do
    word = word:gsub("[^a-z0-9']", '')
    word = word:gsub("^'+", ''):gsub("'+$", '')
    word = TextNormalizer.ALIASES[word] or word
    if #word > 0 then
      table.insert(tokens, word)
    end
  end

  return tokens
end
