--[[

  RowChip.lua - pressable row treatment for setup lists

  The design language (selector cards, worksheet chips) applied at row
  scale: a full-width press target with hover states instead of small
  text links. Optional right-aligned action with its own hit zone
  (unlink, remove) and optional dim styling for rows that are present
  but not yet part of the session.

]]--

RowChip = Polo {
  HEIGHT = 34,
  ROUNDING = 5,
  PAD_X = 10,
  ICON_SIZE = 20,
  GAP = 8,
  PRESS_NUDGE = 1,

  -- Label text rides a size up from the main font
  FONT_DELTA = 2,
}

-- The chip label font registers on first use; until the font reload
-- cycle picks it up (next frame), the main font stands in
function RowChip.label_font()
  if not RowChip._font_registered then
    Fonts:register('row_chip', 'sans-serif', RowChip.FONT_DELTA)
    RowChip._font_registered = true
  end
  return Fonts.row_chip or Fonts.main
end

-- opts: icon, label, detail (dim suffix), dim (muted label), tooltip,
-- width (defaults to available), on_press, and action = { tooltip,
-- on_press, icon (an Icons.* draw function) or label (text) }.
-- Renders one row; invokes callbacks on press.
function RowChip.render(id, opts)
  Trap(function()
    RowChip.render_body(id, opts)
  end)
end

function RowChip.render_body(id, opts)
  local c = RowChip
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  x, y = math.floor(x), math.floor(y)
  local w = math.floor(opts.width or ImGui.GetContentRegionAvail(Ctx()))

  local action_w = 0
  if opts.action then
    action_w = opts.action.icon and c.HEIGHT
      or (math.floor(ImGui.CalcTextSize(Ctx(), opts.action.label)) + c.PAD_X * 2)
  end
  local main_w = w - action_w - (action_w > 0 and 4 or 0)

  local clicked = ImGui.InvisibleButton(Ctx(), id, main_w, c.HEIGHT)
  local hovered = ImGui.IsItemHovered(Ctx())
  local held = ImGui.IsItemActive(Ctx())

  if opts.tooltip then
    Widgets.tooltip(opts.tooltip)
  end
  if hovered then
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end

  local dl = ImGui.GetWindowDrawList(Ctx())

  local bg = Theme.COLORS.dark_gray_translucent
  if held then
    bg = Theme.COLORS.dark_gray_opaque
  elseif hovered then
    bg = Theme.COLORS.dark_gray_semi_transparent
  end
  ImGui.DrawList_AddRectFilled(dl, x, y, x + main_w, y + c.HEIGHT, bg, c.ROUNDING)

  local outline = hovered and Theme.COLORS.pink_opaque or 0x55555588
  ImGui.DrawList_AddRect(dl, x, y, x + main_w, y + c.HEIGHT, outline, c.ROUNDING, 0, 1)

  local press = held and c.PRESS_NUDGE or 0
  local cx = x + c.PAD_X

  if opts.icon then
    ImGui.SetCursorScreenPos(Ctx(), cx, y + (c.HEIGHT - c.ICON_SIZE) / 2 + press)
    EmojiText.icon(opts.icon, c.ICON_SIZE)
    cx = cx + c.ICON_SIZE + c.GAP
  end

  Fonts.wrap(Ctx(), RowChip.label_font(), function()
    local line_h = ImGui.GetTextLineHeight(Ctx())
    local text_y = y + (c.HEIGHT - line_h) / 2 + press
    ImGui.SetCursorScreenPos(Ctx(), cx, text_y)
    ImGui.TextColored(Ctx(), opts.dim and 0xBBBBBBFF or 0xEEEEEEFF, opts.label)

    if opts.detail then
      ImGui.SameLine(Ctx(), 0, c.GAP)
      ImGui.SetCursorScreenPos(Ctx(), select(1, ImGui.GetCursorScreenPos(Ctx())), text_y)
      ImGui.TextColored(Ctx(), 0x888888FF, opts.detail)
    end
  end, Trap)

  local action_clicked = false
  if opts.action then
    local ax = x + main_w + 4
    ImGui.SetCursorScreenPos(Ctx(), ax, y)
    action_clicked = ImGui.InvisibleButton(Ctx(), id .. '-action', action_w, c.HEIGHT)
    local action_hovered = ImGui.IsItemHovered(Ctx())
    if opts.action.tooltip then
      Widgets.tooltip(opts.action.tooltip)
    end
    if action_hovered then
      ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
      ImGui.DrawList_AddRectFilled(dl, ax, y, ax + action_w, y + c.HEIGHT,
        Theme.COLORS.dark_gray_semi_transparent, c.ROUNDING)
    end

    local glyph_color = action_hovered and 0xEEEEEEFF or 0x888888FF
    if opts.action.icon then
      local size = math.floor(c.HEIGHT * 0.45)
      opts.action.icon(dl,
        math.floor(ax + (action_w - size) / 2), math.floor(y + (c.HEIGHT - size) / 2),
        size, size, glyph_color)
    else
      local label_w = ImGui.CalcTextSize(Ctx(), opts.action.label)
      local label_h = ImGui.GetTextLineHeight(Ctx())
      ImGui.SetCursorScreenPos(Ctx(), ax + (action_w - label_w) / 2, y + (c.HEIGHT - label_h) / 2)
      ImGui.TextColored(Ctx(), glyph_color, opts.action.label)
    end
  end

  -- Land the cursor below the row and submit an item there (trailing
  -- cursor moves before EndChild assert)
  ImGui.SetCursorScreenPos(Ctx(), x, y + c.HEIGHT)
  ImGui.Dummy(Ctx(), 0, 0)

  if action_clicked and opts.action and opts.action.on_press then
    opts.action.on_press()
  elseif clicked and opts.on_press then
    opts.on_press()
  end
end
