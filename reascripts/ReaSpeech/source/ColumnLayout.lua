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
    local avail_width, _ = ImGui.GetContentRegionAvail(ctx)
    total_width = avail_width
  end
  local content_width = total_width - self.margin_left - self.margin_right
  local column_width = (content_width - total_padding) / self.num_columns

  ImGui.Dummy(ctx, self.margin_left, 0)
  ImGui.SameLine(ctx)

  for i = 1, self.num_columns do
    local column = {num = i, width = column_width}

    ImGui.BeginGroup(ctx)
    app:trap(function ()
      ImGui.Dummy(ctx, column.width, self.margin_top)
      self.render_column(column)
      ImGui.Dummy(ctx, column.width, self.margin_bottom)
    end)
    ImGui.EndGroup(ctx)

    if i < self.num_columns then
      ImGui.SameLine(ctx, 0, self.column_padding)
    end
  end
end
