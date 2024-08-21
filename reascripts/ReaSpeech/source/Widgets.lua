--[[

  Widgets.lua - UI widgets

]]--

Widgets = {}

function Widgets.icon(icon, id, w, h, color)
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local rv = ImGui.InvisibleButton(ctx, id, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  icon(dl, x, y, w, h, color)
  return rv
end

function Widgets.icon_button(icon, id, w, h, color)
  color = color or 0xffffffff
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local rv = ImGui.Button(ctx, id, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  icon(dl, x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.6, color)
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

  app:trap(function()
    ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 42)
    app:trap(function()
      ImGui.Text(ctx, text)
    end)
    ImGui.PopTextWrapPos(ctx)
  end)

  ImGui.EndTooltip(ctx)
end
