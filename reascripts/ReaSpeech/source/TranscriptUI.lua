--[[

  TranscriptUI.lua - @Transcript table & actions UI

]]

TranscriptUI = Polo {
  TITLE = 'Transcript',

  FLOAT_FORMAT = '%.4f',

  COLUMN_WIDTH = 55,
  LARGE_COLUMN_WIDTH = 300,

  ITEM_WIDTH = 125,

  SCORE_COLORS = {
    bright_green = 0xa3ff00a6,
    dark_green = 0x2cba00a6,
    orange = 0xffa700a6,
    red = 0xff0000a6
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

  self.words = false
  self.colorize_words = false
  self.autoplay = true

  self.transcript_editor = TranscriptEditor.new { transcript = self.transcript }
  self.transcript_exporter = TranscriptExporter.new { transcript = self.transcript }
end

function TranscriptUI:render()
  if self.transcript:has_segments() then
    ImGui.SeparatorText(ctx, "Transcript")
    self:render_result_actions()
    self:render_table()
  end

  self.transcript_editor:render()
  self.transcript_exporter:render()
end

function TranscriptUI:render_result_actions()
  if ImGui.Button(ctx, "Create Regions") then
    self:handle_create_markers(true)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Create Markers") then
    self:handle_create_markers(false)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Create Notes Track") then
    self:handle_create_notes_track()
  end

  ImGui.SameLine(ctx)
  rv, value = ImGui.Checkbox(ctx, "words", self.words)
  if rv then
    self.words = value
  end

  if self.words then
    ImGui.SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, "colorize", self.colorize_words)
    if rv then
      self.colorize_words = value
    end
  end

  local label_width, _ = ImGui.CalcTextSize(ctx, "search")
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH - label_width - 10)
  local search_changed, search = ImGui.InputText(ctx, 'search', self.transcript.search)
  if search_changed then
    self:handle_search(search)
  end
  ImGui.SameLine(ctx, ImGui.GetWindowWidth(ctx) - self.ITEM_WIDTH - label_width - 110)
  rv, value = ImGui.Checkbox(ctx, "auto-play", self.autoplay)
  if rv then
    self.autoplay = value
  end

  if self.transcript:has_segments() then
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Export") then
      self:handle_export()
    end

    ImGui.SameLine(ctx)
     if ImGui.Button(ctx, "Clear") then
      self:handle_transcript_clear()
    end
  end
end

function TranscriptUI:handle_create_markers(regions)
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  self.transcript:create_markers(0, regions, self.words)
  reaper.Undo_EndBlock(
    ("Create %s from speech"):format(regions and 'regions' or 'markers'), -1)
  reaper.PreventUIRefresh(-1)
end

function TranscriptUI:handle_create_notes_track()
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  self.transcript:create_notes_track(self.words)
  reaper.Undo_EndBlock("Create notes track from speech", -1)
  reaper.PreventUIRefresh(-1)
end

function TranscriptUI:handle_export()
  self.transcript_exporter:open()
end

function TranscriptUI:handle_transcript_clear()
  self.transcript:clear()
end

function TranscriptUI:handle_search(search)
  self.transcript.search = search
  self.transcript:update()
end

-- formerly ReaSpeechUI:render_table()
function TranscriptUI:render_table()
  local columns = self.transcript:get_columns()
  local num_columns = #columns + 1

  local ok = ImGui.BeginTable(ctx, "results", num_columns, self.table_flags(true))
  if ok then
    app:trap(function ()
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

      ImGui.TableSetupScrollFreeze(ctx, num_columns, 1)
      ImGui.TableHeadersRow(ctx)

      self:sort_table()

      for index, segment in pairs(self.transcript:get_segments()) do
        ImGui.TableNextRow(ctx)
        ImGui.TableNextColumn(ctx)
        self:render_segment_actions(segment, index)
        for _, column in pairs(columns) do
          ImGui.TableNextColumn(ctx)
          self:render_table_cell(segment, column)
        end
      end
    end)
    ImGui.EndTable(ctx)
  end
end

function TranscriptUI:render_segment_actions(segment, index)
  ImGui.PushFont(ctx, Fonts.icons)
  app:trap(function()
    ImGui.Text(ctx, Fonts.ICON.pencil)
  end)
  ImGui.PopFont(ctx)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
  if ImGui.IsItemClicked(ctx) then
    self.transcript_editor:edit_segment(segment, index)
  end
  app:tooltip("Edit")
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

function TranscriptUI:render_link(text, onclick, text_color, underline_color)
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

function TranscriptUI:render_text(segment, column)
  if self.words then
    self:render_text_words(segment, column)
  else
    self:render_text_simple(segment, column)
  end
end

function TranscriptUI:render_text_simple(segment, column)
  self:render_link(segment:get(column, ""), function () segment:navigate(nil,self.autoplay) end)
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
      self:render_link(word.word, function () segment:navigate(i, self.autoplay) end, color)
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
  if has_specs and specs_dirty then
    local columns = self.transcript:get_columns()
    local column = nil
    local ascending = true

    for next_id = 0, math.huge do
      local ok, _, col_idx, _, sort_direction =
        ImGui.TableGetColumnSortSpecs(ctx, next_id)
      if not ok then break end

      column = columns[col_idx]
      ascending = (sort_direction == ImGui.SortDirection_Ascending())
    end

    if column then
      self.transcript:sort(column, ascending)
    else
      self.transcript:update()
    end
  end
end