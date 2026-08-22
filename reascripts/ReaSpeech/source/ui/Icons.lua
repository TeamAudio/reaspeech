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

function Icons.gear(dl, x, y, w, h, color)
  local center_x = x + (w - 1) * 0.5
  local center_y = y + (h - 1) * 0.5
  local circle_radius = w * 0.15
  local inner_radius = w * 0.3
  local outer_radius = w * 0.4
  local num_teeth = 6

  local points = Icons._gear_points(center_x, center_y, inner_radius, outer_radius, num_teeth)

  ImGui.DrawList_AddCircleFilled(dl, x + w * 0.5, y + h * 0.5, circle_radius, color, 20)
  for i = 1, #points - 2, 2 do
    ImGui.DrawList_AddLine(dl, points[i], points[i + 1], points[i + 2], points[i + 3], color, 1)
  end
end

Icons._gear_points_cache = {}

function Icons._gear_points(center_x, center_y, inner_radius, outer_radius, num_teeth)
  local cache_key = table.concat({center_x, center_y, inner_radius, outer_radius, num_teeth}, ",")
  if Icons._gear_points_cache[cache_key] then
    return Icons._gear_points_cache[cache_key]
  end

  local angle_step = 2 * math.pi / num_teeth
  local angle_start = angle_step * 0.6
  local points = {}

  for i = 0, num_teeth - 1 do
    local angle = angle_start + i * angle_step
    table.insert(points, center_x + inner_radius * math.cos(angle))
    table.insert(points, center_y + inner_radius * math.sin(angle))
    table.insert(points, center_x + outer_radius * math.cos(angle + angle_step * 0.25))
    table.insert(points, center_y + outer_radius * math.sin(angle + angle_step * 0.25))
    table.insert(points, center_x + outer_radius * math.cos(angle + angle_step * 0.5))
    table.insert(points, center_y + outer_radius * math.sin(angle + angle_step * 0.5))
    table.insert(points, center_x + inner_radius * math.cos(angle + angle_step * 0.75))
    table.insert(points, center_y + inner_radius * math.sin(angle + angle_step * 0.75))
  end

  table.insert(points, points[1])
  table.insert(points, points[2])

  Icons._gear_points_cache[cache_key] = points
  return points
end

-- Arrow into a landing bar: the jump-to glyph
function Icons.jump(dl, x, y, w, h, color)
  local mid_y = y + h / 2
  local shaft_end = x + w * 0.55

  ImGui.DrawList_AddLine(dl, x, mid_y, shaft_end, mid_y, color, 1)
  ImGui.DrawList_AddTriangleFilled(dl,
    shaft_end, y + h * 0.22,
    shaft_end, y + h * 0.78,
    x + w * 0.8, mid_y,
    color)
  ImGui.DrawList_AddLine(dl, x + w * 0.94, y + h * 0.15, x + w * 0.94, y + h * 0.85, color, 1)
end

-- Two offset sheets: the classic copy glyph
function Icons.copy(dl, x, y, w, h, color)
  local offset_x, offset_y = w * 0.3, h * 0.3
  local rounding = math.max(1, w * 0.12)

  ImGui.DrawList_AddRect(dl,
    x, y, x + w - offset_x, y + h - offset_y, color, rounding)
  ImGui.DrawList_AddRect(dl,
    x + offset_x, y + offset_y, x + w, y + h, color, rounding)
end

function Icons.info(dl, x, y, w, h, color)
  ImGui.DrawList_AddCircle(
    dl,
    x + w * 0.5,
    y + h * 0.5,
    w * 0.5,
    color,
    20)
  -- Dot of the i
  ImGui.DrawList_AddRectFilled(
    dl,
    x + w * 0.46,
    y + h * 0.3,
    x + w * 0.54,
    y + h * 0.35,
    color)
  -- Body of the i
  ImGui.DrawList_AddRectFilled(
    dl,
    x + w * 0.46,
    y + h * 0.45,
    x + w * 0.54,
    y + h * 0.7,
    color)
end

-- Plus: add/link/import
function Icons.plus(dl, x, y, w, h, color)
  local mid_x, mid_y = x + w / 2, y + h / 2
  local inset_x, inset_y = w * 0.12, h * 0.12
  local thickness = math.max(1.5, w * 0.14)

  ImGui.DrawList_AddLine(dl, x + inset_x, mid_y, x + w - inset_x, mid_y, color, thickness)
  ImGui.DrawList_AddLine(dl, mid_x, y + inset_y, mid_x, y + h - inset_y, color, thickness)
end

-- X: remove/unlink
function Icons.x_mark(dl, x, y, w, h, color)
  local inset_x, inset_y = w * 0.18, h * 0.18
  local thickness = math.max(1.5, w * 0.14)

  ImGui.DrawList_AddLine(dl,
    x + inset_x, y + inset_y, x + w - inset_x, y + h - inset_y, color, thickness)
  ImGui.DrawList_AddLine(dl,
    x + w - inset_x, y + inset_y, x + inset_x, y + h - inset_y, color, thickness)
end

-- Circular arrow: refresh/rescan
function Icons.refresh(dl, x, y, w, h, color)
  local cx, cy = x + w / 2, y + h / 2
  local radius = math.min(w, h) * 0.36
  local thickness = math.max(1.5, w * 0.12)

  local arc_start, arc_end = -math.pi * 0.35, math.pi * 1.05
  ImGui.DrawList_PathArcTo(dl, cx, cy, radius, arc_start, arc_end)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_None(), thickness)

  -- Arrowhead continuing the arc's direction of travel
  local head_x = cx + math.cos(arc_end) * radius
  local head_y = cy + math.sin(arc_end) * radius
  local tangent_x, tangent_y = -math.sin(arc_end), math.cos(arc_end)
  local normal_x, normal_y = math.cos(arc_end), math.sin(arc_end)
  local size = math.min(w, h) * 0.24

  ImGui.DrawList_AddTriangleFilled(dl,
    head_x + normal_x * size * 0.7, head_y + normal_y * size * 0.7,
    head_x - normal_x * size * 0.7, head_y - normal_y * size * 0.7,
    head_x + tangent_x * size, head_y + tangent_y * size,
    color)
end
