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

  ImGui.BeginDisabled(Ctx(), true)
  Trap(function ()
    if tooltip then
      local flags = ImGui.ChildFlags_None()
                  | ImGui.ChildFlags_AutoResizeX()
                  | ImGui.ChildFlags_AutoResizeY()
      if ImGui.BeginChild(Ctx(), imgui_id, 0, 0, flags) then
        Trap(f)
        ImGui.EndChild(Ctx())
      end
    else
      Trap(f)
    end
  end)
  ImGui.EndDisabled(Ctx())

  if tooltip then
    ImGui.SetItemTooltip(Ctx(), tooltip)
  end
end

function Widgets.icon(icon, id, w, h, tooltip, color, hover_color)
  assert(tooltip, 'missing tooltip for icon')
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local rv = ImGui.InvisibleButton(Ctx(), id, w, h)
  if ImGui.IsItemHovered(Ctx()) then
    color = hover_color or color
  end
  local dl = ImGui.GetWindowDrawList(Ctx())
  icon(dl, x, y, w, h, color)
  Widgets.tooltip(tooltip)
  return rv
end

function Widgets.icon_button(icon, id, w, h, tooltip, color)
  assert(tooltip, 'missing tooltip for icon')
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local rv = ImGui.Button(Ctx(), id, w, h)
  local dl = ImGui.GetWindowDrawList(Ctx())
  icon(dl, x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.6, color)
  Widgets.tooltip(tooltip)
  return rv
end

function Widgets.link(text, onclick, text_color, underline_color)
  text_color = text_color or 0xffffffff
  underline_color = underline_color or 0xffffffa0

  ImGui.TextColored(Ctx(), text_color, text)

  if ImGui.IsItemHovered(Ctx()) then
    local rect_min_x, rect_min_y = ImGui.GetItemRectMin(Ctx())
    local rect_max_x, _ = ImGui.GetItemRectMax(Ctx())
    local _, rect_size_y = ImGui.GetItemRectSize(Ctx())
    local line_y = rect_min_y + rect_size_y - 1

    ImGui.DrawList_AddLine(
      ImGui.GetWindowDrawList(Ctx()),
      rect_min_x, line_y, rect_max_x, line_y,
      underline_color, 1.0)
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end

  if ImGui.IsItemClicked(Ctx()) then
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

  ImGui.Image(Ctx(), image.imgui_image, image.width, image.height)
end

function Widgets.tooltip(text)
  if not ImGui.IsItemHovered(Ctx(), ImGui.HoveredFlags_DelayNormal()) or
     not ImGui.BeginTooltip(Ctx())
  then return end

  Trap(function()
    ImGui.PushTextWrapPos(Ctx(), ImGui.GetFontSize(Ctx()) * Widgets.TOOLTIP_WRAP_CHARS)
    Trap(function()
      ImGui.Text(Ctx(), text)
    end)
    ImGui.PopTextWrapPos(Ctx())
  end)

  ImGui.EndTooltip(Ctx())
end

function Widgets.warning(text)
  ImGui.TextColored(Ctx(), Theme.COLORS.bold_red, text)
end
