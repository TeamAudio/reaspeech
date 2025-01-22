--[[

  Widgets.lua - UI widgets

]]--

Widgets = {
  TOOLTIP_WRAP_CHARS = 30,
}

function Widgets.disable_if(predicate, f, tooltip)
  if not predicate then
    Trap(f)
    return
  end

  local imgui_id = 'disabled##' .. (tooltip or '')

  ImGui.BeginDisabled(ctx, true)
  Trap(function ()
    if tooltip then
      local flags = ImGui.ChildFlags_None()
                  | ImGui.ChildFlags_AutoResizeX()
                  | ImGui.ChildFlags_AutoResizeY()
      ImGui.BeginChild(ctx, imgui_id, 0, 0, flags)
    end

    Trap(f)

    if tooltip then
      ImGui.EndChild(ctx)
    end
  end)
  ImGui.EndDisabled(ctx)

  if tooltip then
    ImGui.SetItemTooltip(ctx, tooltip)
  end
end

function Widgets.icon(icon, id, w, h, tooltip, color, hover_color)
  assert(tooltip, 'missing tooltip for icon')
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local rv = ImGui.InvisibleButton(ctx, id, w, h)
  if ImGui.IsItemHovered(ctx) then
    color = hover_color or color
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  icon(dl, x, y, w, h, color)
  Widgets.tooltip(tooltip)
  return rv
end

function Widgets.icon_button(icon, id, w, h, tooltip, color)
  assert(tooltip, 'missing tooltip for icon')
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local rv = ImGui.Button(ctx, id, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  icon(dl, x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.6, color)
  Widgets.tooltip(tooltip)
  return rv
end

function Widgets.link(text, onclick, text_color, underline_color)
  text_color = text_color or 0xffffffff
  underline_color = underline_color or 0xffffffa0

  ImGui.TextColored(ctx, text_color, text)

  if ImGui.IsItemHovered(ctx) then
    local rect_min_x, rect_min_y = ImGui.GetItemRectMin(ctx)
    local rect_max_x, _ = ImGui.GetItemRectMax(ctx)
    local _, rect_size_y = ImGui.GetItemRectSize(ctx)
    local line_y = rect_min_y + rect_size_y - 1

    ImGui.DrawList_AddLine(
      ImGui.GetWindowDrawList(ctx),
      rect_min_x, line_y, rect_max_x, line_y,
      underline_color, 1.0)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end

  if ImGui.IsItemClicked(ctx) then
    onclick()
  end
end

function Widgets.png(image_key)
  if type(image_key) == 'table' then
    image_key = image_key.name
  end

  if not IMAGES[image_key] or not IMAGES[image_key].bytes then
    return
  end

  local image = IMAGES[image_key]

  if not ImGui.ValidatePtr(image.imgui_image, 'ImGui_Image*') then
    image.imgui_image = ImGui.CreateImageFromMem(image.bytes)
  end

  ImGui.Image(ctx, image.imgui_image, image.width, image.height)
end

function Widgets.tooltip(text)
  if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal()) or
     not ImGui.BeginTooltip(ctx)
  then return end

  Trap(function()
    ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * Widgets.TOOLTIP_WRAP_CHARS)
    Trap(function()
      ImGui.Text(ctx, text)
    end)
    ImGui.PopTextWrapPos(ctx)
  end)

  ImGui.EndTooltip(ctx)
end

function Widgets.warning(text)
  ImGui.TextColored(ctx, Theme.COLORS.bold_red, text)
end
