--[[

  Icons.lua - Drawable icons

]]--

Icons = {}

function Icons.pencil(dl, x, y, w, h, color)
  -- Tip of pencil
  ImGui.DrawList_AddTriangleFilled(
    dl,
    x,
    y + h,
    x + w * 0.1,
    y + h * 0.7,
    x + w * 0.3,
    y + h * 0.9,
    color)

  -- Body of pencil
  ImGui.DrawList_AddQuadFilled(
    dl,
    x + w * 0.15,
    y + h * 0.65,
    x + w * 0.65,
    y + h * 0.15,
    x + w * 0.85,
    y + h * 0.35,
    x + w * 0.35,
    y + h * 0.85,
    color)

  -- Eraser
  ImGui.DrawList_AddQuadFilled(
    dl,
    x + w * 0.7,
    y + h * 0.1,
    x + w * 0.8,
    y,
    x + w,
    y + h * 0.2,
    x + w * 0.9,
    y + h * 0.3,
    color)
end

function Icons.play(dl, x, y, w, h, color)
  ImGui.DrawList_AddCircle(
    dl,
    x + w * 0.5,
    y + h * 0.5,
    w * 0.5,
    color,
    20)
  ImGui.DrawList_AddTriangleFilled(
    dl,
    x + w * 0.35,
    y + h * 0.25,
    x + w * 0.75,
    y + h * 0.5,
    x + w * 0.35,
    y + h * 0.75,
    color)
end

function Icons.stop(dl, x, y, w, h, color)
  ImGui.DrawList_AddCircle(
    dl,
    x + w * 0.5,
    y + h * 0.5,
    w * 0.5,
    color,
    20)
  ImGui.DrawList_AddRectFilled(
    dl,
    x + w * 0.3,
    y + h * 0.3,
    x + w * 0.7,
    y + h * 0.7,
    color)
end
