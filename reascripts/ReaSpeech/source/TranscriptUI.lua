--[[

  TranscriptUI.lua - @Transcript table & actions UI

]]

TranscriptUI = Polo {
  TITLE = 'Transcript',

  FLOAT_FORMAT = '%.4f',

  COLUMN_WIDTH = 55,
  LARGE_COLUMN_WIDTH = 300,

  ACTIONS_MARGIN = 8,
  ACTIONS_PADDING = 8,

  SCORE_COLORS = {
    bright_green = 0xa3ff00a6,
    dark_green = 0x2cba00a6,
    orange = 0xffa700a6,
    red = 0xff2c2cff
  }
}

TranscriptUI.table_flags = function (sortable)
  local sort_flags = 0
  if sortable then
    sort_flags = ImGui.TableFlags_Sortable() | ImGui.TableFlags_SortTristate()
  end
  return (
    sort_flags
    | ImGui.TableFlags_Borders()
    | ImGui.TableFlags_Hideable()
    | ImGui.TableFlags_Resizable()
    | ImGui.TableFlags_Reorderable()
    | ImGui.TableFlags_RowBg()
    | ImGui.TableFlags_ScrollX()
    | ImGui.TableFlags_ScrollY()
    | ImGui.TableFlags_SizingFixedFit()
  )
end

function TranscriptUI:init()
  assert(self.transcript, 'missing transcript')

  Logging.init(self, 'TranscriptUI')

  self.words = false
  self.colorize_words = false
  self.autoplay = true

  self.transcript_editor = TranscriptEditor.new { transcript = self.transcript }
  self.transcript_exporter = TranscriptExporter.new { transcript = self.transcript }
  self.annotations = TranscriptAnnotationsUI.new { transcript = self.transcript }

  self:init_layouts()
end

function TranscriptUI:_clipper()
  if not ImGui.ValidatePtr(self.clipper, 'ImGui_ListClipper*') then
    self.clipper = ImGui.CreateListClipper(ctx)
  end

  return self.clipper
end

function TranscriptUI:init_layouts()
  local renderers = {
    self.render_annotations_button,
    self.render_word_options,
    self.render_result_actions,
    self.render_auto_play,
    self.render_search
  }

  self.actions_layout = ColumnLayout.new {
    column_padding = self.ACTIONS_PADDING,
    num_columns = #renderers,
    render_column = function (column)
      renderers[column.num](self, column)
    end
  }
end

function TranscriptUI:render_annotations_button(column)
  if ImGui.Button(ctx, "Create Markers", column.width) then
    self.annotations:present()
  end
end

function TranscriptUI:render()
  if self.transcript:has_segments() then
    ImGui.SeparatorText(ctx, "Transcript")
    self.actions_layout:render()
    self:render_table()
  end

  self.transcript_editor:render()
  self.transcript_exporter:render()
  self.annotations:render()
end

function TranscriptUI:render_word_options()
  local rv, value = ImGui.Checkbox(ctx, "Words", self.words)
  if rv then
    self.words = value
  end

  if self.words then
    ImGui.SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, "Colorize", self.colorize_words)
    if rv then
      self.colorize_words = value
    end
  end
end

function TranscriptUI:render_result_actions()
  self:render_export()
  ImGui.SameLine(ctx)
  self:render_clear()
end

function TranscriptUI:render_export()
  if ImGui.Button(ctx, "Export") then
    self:handle_export()
  end
end

function TranscriptUI:render_clear()
  if ImGui.Button(ctx, "Clear") then
    self:handle_transcript_clear()
  end
end

function TranscriptUI:render_auto_play()
  local rv, value = ImGui.Checkbox(ctx, "Auto Play", self.autoplay)
  if rv then
    self.autoplay = value
  end
end

function TranscriptUI:render_search(column)
  ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - column.width - self.ACTIONS_MARGIN)
  ImGui.PushItemWidth(ctx, column.width)
  Trap(function()
    local search_changed, search = ImGui.InputTextWithHint(ctx, '##search', 'Search', self.transcript.search)
    if search_changed then
      self:handle_search(search)
    end
  end)
  ImGui.PopItemWidth(ctx)
end

function TranscriptUI:handle_export()
  self.transcript_exporter:present()
end

function TranscriptUI:handle_transcript_clear()
  self.transcript:clear()
end

function TranscriptUI:handle_search(search)
  self.transcript.search = search
  self.transcript:update()
end

function TranscriptUI:render_table()
  local columns = self.transcript:get_columns()
  local num_columns = #columns + 1

  if ImGui.BeginTable(ctx, "results", num_columns, self.table_flags(true)) then
    Trap(function ()
      ImGui.TableSetupColumn(ctx, "##actions", ImGui.TableColumnFlags_NoSort(), 20)

      for _, column in pairs(columns) do
        local column_flags = 0
        if TranscriptSegment.default_hide(column) then
          -- reaper.ShowConsoleMsg(string.format('column %s: %s\n', column, TranscriptSegment.default_hide(column)))
          column_flags = column_flags | ImGui.TableColumnFlags_DefaultHide()
        end
        local init_width = self.COLUMN_WIDTH
        if column == "text" or column == "file" then
          init_width = self.LARGE_COLUMN_WIDTH
        end
        -- reaper.ShowConsoleMsg(string.format('column %s: %s / flags: %s\n', column, TranscriptSegment.default_hide(column), column_flags))
        ImGui.TableSetupColumn(ctx, column, column_flags, init_width)
      end

      ImGui.TableSetupScrollFreeze(ctx, 0, 1)

      local clipper = self:_clipper()

      ImGui.ListClipper_Begin(clipper, #self.transcript + 1)

      while ImGui.ListClipper_Step(clipper) do
        local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)

        for row = display_start, display_end - 1 do
          if row == 0 then
            ImGui.TableHeadersRow(ctx)
            self:sort_table()
          else
            local segment = self.transcript:get_segment(row)
            ImGui.TableNextRow(ctx)
            ImGui.TableNextColumn(ctx)
            self:render_segment_actions(segment, row)
            for _, column in pairs(columns) do
              ImGui.TableNextColumn(ctx)
              self:render_table_cell(segment, column)
            end
          end
        end
      end
    end)
    ImGui.EndTable(ctx)
  end
end

function TranscriptUI:render_segment_actions(segment, index)
  if Widgets.icon(Icons.pencil, "##edit" .. index, 14, 14, "Edit") then
    self.transcript_editor:edit_segment(segment, index)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
end

function TranscriptUI:render_table_cell(segment, column)
  if column == "text" or column == "word" then
    self:render_text(segment, column)
  elseif column == "score" then
    self:render_score(segment:get(column, 0.0))
  elseif column == "start" or column == "end" then
    ImGui.Text(ctx, reaper.format_timestr(segment:get(column, 0.0), ''))
  else
    local value = segment:get(column)
    if type(value) == 'table' then
      value = table.concat(value, ', ')
    elseif math.type(value) == 'float' then
      value = self.FLOAT_FORMAT:format(value)
    end
    ImGui.Text(ctx, tostring(value))
  end
end

function TranscriptUI:render_text(segment, column)
  if self.words then
    self:render_text_words(segment, column)
  else
    self:render_text_simple(segment, column)
  end
end

function TranscriptUI:render_text_simple(segment, column)
  Widgets.link(segment:get(column, ""), function () segment:navigate(nil,self.autoplay) end)
end

function TranscriptUI:render_text_words(segment, _)
  if segment.words then
    for i, word in pairs(segment.words) do
      if i > 1 then
        ImGui.SameLine(ctx, 0, 0)
        ImGui.Text(ctx, ' ')
        ImGui.SameLine(ctx, 0, 0)
      end
      local color = nil
      if self.colorize_words then
        color = self.score_color(word:score())
      end
      Widgets.link(word.word, function () segment:navigate(i, self.autoplay) end, color)
    end
  end
end

function TranscriptUI:render_score(value)
  local w, h = 50 * value, 3
  local color = self.score_color(value)
  if color then
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    y = y + 7
    ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, color)
  end
  ImGui.Dummy(ctx, w, h)
end

function TranscriptUI.score_color(value)
  local colors = TranscriptUI.SCORE_COLORS

  if value > 0.9 then
    return colors.bright_green
  elseif value > 0.8 then
    return colors.dark_green
  elseif value > 0.7 then
    return colors.orange
  elseif value > 0.0 then
    return colors.red
  else
    return nil
  end
end

function TranscriptUI:sort_table()
  local specs_dirty, has_specs = ImGui.TableNeedSort(ctx)
  if not specs_dirty then return end

  if not has_specs then
    self.transcript:update()
    return
  end

  local columns = self.transcript:get_columns()
  local column = nil
  local ascending = true

  for next_id = 0, math.huge do
    local ok, col_idx, _, sort_direction =
      ImGui.TableGetColumnSortSpecs(ctx, next_id)
    if not ok then break end

    column = columns[col_idx]
    ascending = (sort_direction == ImGui.SortDirection_Ascending())
  end

  if column then
    self.transcript:sort(column, ascending)
  end
end
