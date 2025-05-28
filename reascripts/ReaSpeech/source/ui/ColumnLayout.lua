--[[

ColumnLayout.lua - Fixed-width column layout helper

]]--

ColumnLayout = Polo {
  DEFAULT_COLUMN_PADDING = 15,
  DEFAULT_NUM_COLUMNS = 3,
}

function ColumnLayout:init()
  assert(self.render_column, 'render_column function must be provided')
  self.column_padding = self.column_padding or self.DEFAULT_COLUMN_PADDING
  self.margin_bottom = self.margin_bottom or 0
  self.margin_left = self.margin_left or 0
  self.margin_right = self.margin_right or 0
  self.margin_top = self.margin_top or 0
  self.num_columns = self.num_columns or self.DEFAULT_NUM_COLUMNS
  self.width = self.width or 0
end

function ColumnLayout:render()
  local total_padding = (self.num_columns - 1) * self.column_padding
  local total_width = self.width
  if total_width == 0 then
    total_width = self:_get_avail_width()
  end
  local content_width = total_width - self.margin_left - self.margin_right
  local column_width = (content_width - total_padding) / self.num_columns

  self:_horiz_margin(self.margin_left)

  for i = 1, self.num_columns do
    local column = {num = i, width = column_width}

    self:_with_group(function ()
      self:_vert_margin(self.margin_top, column_width)
      self.render_column(column)
      self:_vert_margin(self.margin_bottom, column_width)
    end)

    if i < self.num_columns then
      self:_column_gap(self.column_padding)
    end
  end
end

function ColumnLayout:_column_gap(padding)
  ImGui.SameLine(Ctx(), 0, padding)
end

function ColumnLayout:_get_avail_width()
  local avail_width, _ = ImGui.GetContentRegionAvail(Ctx())
  return avail_width
end

function ColumnLayout:_horiz_margin(margin)
  ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + margin)
end

function ColumnLayout:_vert_margin(margin, width)
  ImGui.Dummy(Ctx(), width, margin)
end

function ColumnLayout:_with_group(f)
  ImGui.BeginGroup(Ctx())
  Trap(f)
  ImGui.EndGroup(Ctx())
end
