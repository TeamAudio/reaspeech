--[[

  EmojiText.lua - Inline :tag: emoji rendering for ImGui text

  ReaImGui cannot render emoji glyphs, so UI strings carry Slack-style
  :tag: markup (ASCII-safe through every storage layer) rendered as
  inline images from the curated openmoji set in resources/images.
  Unknown tags render as their literal text, so degradation is always
  legible.

  This layer only handles single-line text: label-slot primitives
  (Button/Selectable/Combo labels) take opaque strings and cannot host
  images, and wrapped text needs manual layout. Strip or avoid tags in
  those contexts.

  Usage:

    EmojiText.render(':check: 5 suggestions')
    EmojiText.render(':warning: setup changed', 0xffcc66ff)
    EmojiText.icon('check')          -- bare icon at text line height
    EmojiText.calc_width(text)       -- layout width, icons included

]]--

EmojiText = {
  TAGS = {
    check = 'emoji-check',
    progress = 'emoji-progress',
    warning = 'emoji-warning',
    hourglass = 'emoji-hourglass',
    error = 'emoji-error',
    stopped = 'emoji-stopped',
    search = 'emoji-search',
    accepted = 'emoji-accepted',
    rejected = 'emoji-rejected',
    pin = 'emoji-pin',
    gear = 'emoji-gear',
    headphone = 'emoji-headphone',
    package = 'emoji-package',
    folder = 'emoji-folder',
    spreadsheet = 'emoji-spreadsheet',
    csv = 'emoji-csv',
    wav = 'emoji-wav',
    dice = 'emoji-dice',
    comb = 'emoji-comb',
  },

  _parse_cache = {},
}

-- Split text into { {text=...} | {icon=<IMAGES key>} } runs. Unknown
-- tags stay literal. Memoized per string (UI strings are stable and
-- this runs every frame).
function EmojiText.parse(text)
  local cached = EmojiText._parse_cache[text]
  if cached then
    return cached
  end

  local runs = {}
  local flush_from = 1
  local search_from = 1

  while true do
    local start_pos, end_pos, tag = text:find('%:([%w_+-]+)%:', search_from)
    if not start_pos then
      break
    end

    local image_key = EmojiText.TAGS[tag]
    if image_key then
      if start_pos > flush_from then
        table.insert(runs, { text = text:sub(flush_from, start_pos - 1) })
      end
      table.insert(runs, { icon = image_key })
      flush_from = end_pos + 1
      search_from = end_pos + 1
    else
      -- Unknown tag: leave it literal, but keep searching after the
      -- opening colon so an overlapping valid tag still matches
      search_from = start_pos + 1
    end
  end

  if flush_from <= #text then
    table.insert(runs, { text = text:sub(flush_from) })
  end

  EmojiText._parse_cache[text] = runs
  return runs
end

-- slot_size overrides the icon layout size (defaults to the ACTIVE
-- font's text line height, so icons follow Fonts.wrap contexts; pass
-- an explicit size to keep icons legible next to deliberately small
-- text)
function EmojiText.render(text, color, slot_size)
  local runs = EmojiText.parse(text)

  if #runs == 0 then
    ImGui.Text(Ctx(), text)
    return
  end

  for i, run in ipairs(runs) do
    if i > 1 then
      ImGui.SameLine(Ctx(), 0, 0)
    end

    if run.icon then
      EmojiText.draw_icon(run.icon, slot_size)
    elseif color then
      ImGui.TextColored(Ctx(), color, run.text)
    else
      ImGui.Text(Ctx(), run.text)
    end
  end
end

-- Openmoji art carries internal padding in its canvas, so an icon
-- drawn at exactly text height reads noticeably smaller than the text.
-- Icons reserve a text-height layout slot but overdraw scaled up and
-- centered (DrawList is not clipped to the item rect), nudged down
-- toward the text baseline. Tune these against REAPER.
EmojiText.ICON_SCALE = 1.35
EmojiText.BASELINE_NUDGE = 0.04

-- Per-icon overrides for art that fills its canvas (no padding to
-- compensate): the global scale renders those oversized
EmojiText.ICON_SCALES = {
  ['emoji-progress'] = 1.0,
}

-- Bare icon by tag name; slot_size defaults to the text line height
-- (pass e.g. GetFrameHeight for button-row contexts)
function EmojiText.icon(tag, slot_size)
  local image_key = EmojiText.TAGS[tag]
  if image_key then
    EmojiText.draw_icon(image_key, slot_size)
  end
end

function EmojiText.draw_icon(image_key, slot_size)
  slot_size = slot_size or ImGui.GetTextLineHeight(Ctx())
  local image = IMAGES[image_key]

  if not image or not image.bytes then
    ImGui.Dummy(Ctx(), slot_size, slot_size)
    return
  end

  if not ImGui.ValidatePtr(image.imgui_image, 'ImGui_Image*') then
    image.imgui_image = ImGui.CreateImageFromMem(image.bytes)
  end

  local x, y = ImGui.GetCursorScreenPos(Ctx())
  ImGui.Dummy(Ctx(), slot_size, slot_size)

  local scale = EmojiText.ICON_SCALES[image_key] or EmojiText.ICON_SCALE
  local pad = (slot_size * scale - slot_size) / 2
  local nudge = slot_size * EmojiText.BASELINE_NUDGE

  ImGui.DrawList_AddImage(
    ImGui.GetWindowDrawList(Ctx()),
    image.imgui_image,
    x - pad, y - pad + nudge,
    x + slot_size + pad, y + slot_size + pad + nudge)
end

-- Layout width of the rendered line (text runs measured, icons at
-- slot_size or line height), for right-alignment and similar math
function EmojiText.calc_width(text, slot_size)
  local runs = EmojiText.parse(text)

  if #runs == 0 then
    return (ImGui.CalcTextSize(Ctx(), text))
  end

  local width = 0
  for _, run in ipairs(runs) do
    if run.icon then
      width = width + (slot_size or ImGui.GetTextLineHeight(Ctx()))
    else
      width = width + (ImGui.CalcTextSize(Ctx(), run.text))
    end
  end

  return width
end
