--[[

  TranscriptUI.lua - @Transcript table & actions UI

]]

TranscriptUI = Polo {
  TITLE = 'Transcript',
  TAB_TITLE_FORMAT = "Transcript: %s",

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

  Logging().init(self, 'TranscriptUI')

  self.words = false
  self.colorize_words = false
  self.autoplay = true

  self.editing_name = false
  self.name_editor = Widgets.TextInput.new {
    default = self.transcript.name,
    on_cancel = function()
      self.editing_name = false
      self.transcript.name = self._original_transcript_name
      self._original_transcript_name = nil
    end,
    on_change = function(value)
      self.transcript.name = value
    end,
    on_enter = function()
      self.transcript.name = self.name_editor:value()
      self.editing_name = false
    end,
  }

  self.confirmation_popup = AlertPopup.new {
    title = "Transcript not saved!",
  }

  self.transcript_editor = TranscriptEditor.new { transcript = self.transcript }
  self.transcript_exporter = TranscriptExporter.new {
    transcript = self.transcript,
    on_export = function()
      self._transcript_saved = true
    end
  }
  self.annotations = TranscriptAnnotationsUI.new { transcript = self.transcript }

  self._transcript_saved = false

  self:init_layouts()
end

function TranscriptUI:tabs()
  return {
    ReaSpeechPlugins.tab(
      self:transcript_id(),
      function() return self:transcript_name() end,
      function() self.tab_layout:render() end,
      {
        will_close = function()
          return self:confirm_close()
        end,
        on_close = function()
          app.plugins:remove_plugin(self)
        end
      }
    )
  }
end

function TranscriptUI:confirm_close()
  if self._transcript_saved then
    return true
  end

  self.confirmation_popup:show('Transcript not saved!', function()
    ImGui.Text(ctx, "This transcript hasn't been saved/exported. Are you sure you want to close it?")
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, 'Cancel') then
      self.confirmation_popup:close()
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Close without Saving') then
      self.confirmation_popup:close()
      app.plugins:remove_plugin(self)
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Save') then
      self.confirmation_popup:close()
      self.transcript_exporter.on_export = function()
        app.plugins:remove_plugin(self)
      end
      self.transcript_exporter:present()
    end
  end)

  return false
end

function TranscriptUI:transcript_id()
  if not self._transcript_id then
    self._transcript_id = ("transcript-%s"):format(os.date())
  end

  return self._transcript_id
end

function TranscriptUI:transcript_name()
  if not self.transcript.name or #self.transcript.name < 1 then
    return 'Untitled Transcript'
  end

  return TranscriptUI.TAB_TITLE_FORMAT:format(self.transcript.name)
end

function TranscriptUI:clipper()
  if not ImGui.ValidatePtr(self._clipper, 'ImGui_ListClipper*') then
    self._clipper = ImGui.CreateListClipper(ctx)
  end

  return self._clipper
end

function TranscriptUI:init_layouts()
  local renderers = {
    self.render_result_actions,
    self.render_options,
    self.render_search
  }

  self.actions_layout = ColumnLayout.new {
    column_padding = self.ACTIONS_PADDING,
    num_columns = #renderers,
    render_column = function (column)
      renderers[column.num](self, column)
    end
  }

  self.tab_layout = ColumnLayout.new {
    column_padding = self.ACTIONS_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = 0,
    num_columns = 1,

    render_column = function (_column)
      self:render()
    end
  }
end

function TranscriptUI:render()
  self:render_name()

  if self.transcript:has_segments() then
    self.actions_layout:render()
    self:render_table()
  end

  self.confirmation_popup:render()
  self.transcript_editor:render()
  self.transcript_exporter:render()
  self.annotations:render()
end

function TranscriptUI:render_name()
  ImGui.PushFont(ctx, Fonts.big)
  Trap(function()
    if self.editing_name then
      self.name_editor:render()
    else
      ImGui.Dummy(ctx, 1, 2)
      ImGui.Dummy(ctx, 2, 0)
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, self.transcript.name)
      ImGui.SameLine(ctx)
      local icon_size = Fonts.size:get() - 1
      if Widgets.icon(Icons.pencil, "##edit_name", icon_size, icon_size, "Edit") then
        self._original_transcript_name = self.transcript.name
        self.editing_name = true
      end
      ImGui.Dummy(ctx, 1, 2)
    end
  end)
  ImGui.PopFont(ctx)
end

function TranscriptUI:render_result_actions()
  self:render_annotations_button()
  ImGui.SameLine(ctx)
  self:render_export()
  ImGui.SameLine(ctx)
  self:render_clear()
end

function TranscriptUI:render_annotations_button()
  if ImGui.Button(ctx, "Create Markers") then
    self.annotations:present()
  end
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

function TranscriptUI:render_options()
  local rv, value

  rv, value = ImGui.Checkbox(ctx, "Auto Play", self.autoplay)
  if rv then
    self.autoplay = value
  end

  if self.transcript:has_words() then
    ImGui.SameLine(ctx)

    rv, value = ImGui.Checkbox(ctx, "Words", self.words)
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

  local imgui_id = self.transcript.name

  if #self.transcript.name < 1 then
    imgui_id = ("transcript-" .. tostring(reaper.time_precise()))
  end

  ImGui.PushID(ctx, imgui_id)
  if ImGui.BeginTable(ctx, "results", num_columns, self.table_flags(true), 0, -10) then
    Trap(function ()
      ImGui.TableSetupColumn(ctx, "##actions", ImGui.TableColumnFlags_NoSort(), 20)

      for _, column in pairs(columns) do
        local column_flags = 0
        local default_hide = TranscriptSegment.default_hide(column)
        if column == "score" and not self.transcript:has_words() then
          default_hide = true
        end
        if default_hide then
          -- reaper.ShowConsoleMsg(string.format('column %s: %s\n', column, default_hide))
          column_flags = column_flags | ImGui.TableColumnFlags_DefaultHide()
        end
        local init_width = self.COLUMN_WIDTH
        if column == "text" or column == "file" then
          init_width = self.LARGE_COLUMN_WIDTH
        end
        -- reaper.ShowConsoleMsg(string.format('column %s: %s / flags: %s\n', column, default_hide, column_flags))
        ImGui.TableSetupColumn(ctx, column, column_flags, init_width)
      end

      ImGui.TableSetupScrollFreeze(ctx, 0, 1)

      local clipper = self:clipper()
      local items_count = #self.transcript + 1
      local items_height = ImGui.GetTextLineHeightWithSpacing(ctx)

      ImGui.ListClipper_Begin(clipper, items_count, items_height)

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
  ImGui.PopID(ctx)
end

function TranscriptUI:render_segment_actions(segment, index)
  if not segment.words then return end

  local icon_size = Fonts.size:get() - 1
  if Widgets.icon(Icons.pencil, "##edit" .. index, icon_size, icon_size, "Edit") then
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
