--[[

  TranscriptEditor.lua - Transcript editor UI

]]--

TranscriptEditor = Polo {
  TITLE = 'Edit Segment',
  WIDTH = 500,
  HEIGHT = 500,
  MIN_CONTENT_WIDTH = 375,
  BUTTON_WIDTH = 120,
  WORDS_PER_LINE = 5,
}

function TranscriptEditor:init()
  assert(self.transcript, 'missing transcript')
  self.editing = nil
  self.is_open = false
  self.sync_time_selection = false
  self.zoom_level = "none"
end

function TranscriptEditor:edit_segment(segment, index)
  self.editing = {
    segment = segment,
    words = {},
    index = index,
    text = segment:get('text'),
  }
  for i, word in pairs(segment.words) do
    self.editing.words[i] = word:copy()
  end
  self:edit_word(self.editing.words[1], 1)
end

function TranscriptEditor:edit_word(word, index)
  self.editing.word = word
  self.editing.word_index = index
  if self.sync_time_selection then
    self:update_time_selection()
    self:zoom(self.zoom_level)
  end
end

function TranscriptEditor:render()
  if not self.editing then
    return
  end

  local opening = not self.is_open
  if opening then
    self:_open()
  end

  local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
  ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, self.WIDTH, self.HEIGHT, ImGui.Cond_FirstUseEver())

  if ImGui.BeginPopupModal(ctx, self.TITLE, true, ImGui.WindowFlags_AlwaysAutoResize()) then
    app:trap(function () self:render_content() end)
    ImGui.EndPopup(ctx)
  else
    self:_close()
  end
end

function TranscriptEditor:render_content()
  if self.editing.word then
    self:render_word_navigation()
    self:render_separator()
  end

  local edit_requested = self:render_words()

  if self.editing.word then
    self:render_separator()
    self:render_word_actions()
    self:render_word_inputs()
  end

  if edit_requested then
    self:edit_word(table.unpack(edit_requested))
  end

  self:render_separator()

  if ImGui.Button(ctx, 'Save', self.BUTTON_WIDTH, 0) then
    self:handle_save()
    self:_close()
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Cancel', self.BUTTON_WIDTH, 0) then
    self:_close()
  end
end

function TranscriptEditor:render_word_navigation()
  local words = self.editing.words
  local word_index = self.editing.word_index
  local num_words = #words
  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing())
  local disable_if = ReaUtil.disabler(ctx, app.onerror)

  ImGui.PushButtonRepeat(ctx, true)
  app:trap(function ()
    if ImGui.ArrowButton(ctx, '##left', ImGui.Dir_Left()) then
      local index = self.editing.word_index - 1
      if index > 0 then
        self:edit_word(words[index], index)
      end
    end
    ImGui.SameLine(ctx, 0, spacing)
    if ImGui.ArrowButton(ctx, '##right', ImGui.Dir_Right()) then
      local index = self.editing.word_index + 1
      if index <= num_words then
        self:edit_word(words[index], index)
      end
    end
  end)
  ImGui.PopButtonRepeat(ctx)

  ImGui.SameLine(ctx)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, 'Word ' .. word_index .. ' / ' .. num_words)

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Add') then
    self:handle_word_add()
  end
  app:tooltip('Add word after current word')

  ImGui.SameLine(ctx, 0, spacing)

  disable_if(num_words <= 1, function()
    if ImGui.Button(ctx, 'Delete') then
      self:handle_word_delete()
    end
  end)
  app:tooltip('Delete current word')

  ImGui.SameLine(ctx, 0, spacing)
  if ImGui.Button(ctx, 'Split') then
    self:handle_word_split()
  end
  app:tooltip('Split current word into two words')

  ImGui.SameLine(ctx, 0, spacing)
  disable_if(word_index >= num_words, function()
    if ImGui.Button(ctx, 'Merge') then
      self:handle_word_merge()
    end
  end)
  app:tooltip('Merge current word with next word')
end

function TranscriptEditor:render_words()
  local words = self.editing.words
  local num_words = #words
  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing())
  local edit_requested = nil

  for i, word in pairs(words) do
    if self.editing.word_index ~= i then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button(), 0xffffff33)
    end
    app:trap(function()
      if ImGui.Button(ctx, word.word .. '##' .. i) then
        edit_requested = {word, i}
      end
    end)
    if self.editing.word_index ~= i then
      ImGui.PopStyleColor(ctx)
    end

    if i < num_words and i % self.WORDS_PER_LINE ~= 0 then
      ImGui.SameLine(ctx, 0, spacing)
    end
  end

  return edit_requested
end

function TranscriptEditor:render_word_inputs()
  self:render_word_input()

  if self.sync_time_selection then
    local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local offset = Transcript.calculate_offset(self.editing.segment.item, self.editing.segment.take)
    self.editing.word.start = sel_start - offset
    self.editing.word.end_ = sel_end - offset
  end

  self:render_time_input('start', self.editing.word.start, function (time)
    self.editing.word.start = time
  end)

  self:render_time_input('end', self.editing.word.end_, function (time)
    self.editing.word.end_ = time
  end)

  self:render_score_input()
end

function TranscriptEditor:render_word_input()
  local rv, value = ImGui.InputText(ctx, 'word', self.editing.word.word)
  if rv then
    value = value:gsub('^%s*(.-)%s*$', '%1')
    if #value > 0 then
      self.editing.word.word = value
    end
  end
end

function TranscriptEditor:render_time_input(label, value, callback)
  local value_str = reaper.format_timestr(value, '')
  local rv, new_value = ImGui.InputText(ctx, label, value_str)
  if rv then
    callback(reaper.parse_timestr(new_value))
  end
end

function TranscriptEditor:render_score_input()
  local color = ReaSpeechUI:score_color(self.editing.word:score())
  if color then
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab(), color)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive(), color)
  end
  app:trap(function ()
    local rv, value = ImGui.SliderDouble(ctx, 'score', self.editing.word.probability, 0, 1)
    if rv then
      self.editing.word.probability = value
    end
  end)
  if color then
    ImGui.PopStyleColor(ctx, 2)
  end
end

function TranscriptEditor:render_icon_button(icon, callback)
  ImGui.PushFont(ctx, Fonts.icons)
  app:trap(function ()
    if ImGui.Button(ctx, Fonts.ICON[icon]) then
      callback()
    end
  end)
  ImGui.PopFont(ctx)
end

function TranscriptEditor:render_word_actions()
  self:render_icon_button('play', function ()
    self:update_time_selection()
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    reaper.Main_OnCommand(40630, 0) -- Go to start of time selection
    reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
  end)
  app:tooltip('Play word')

  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing())
  ImGui.SameLine(ctx, 0, spacing)

  self:render_icon_button('stop', function ()
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
  end)
  app:tooltip('Stop')

  ImGui.SameLine(ctx)
  local rv, value = ImGui.Checkbox(ctx, 'sync time selection', self.sync_time_selection)
  if rv then
    self.sync_time_selection = value
    if value then
      self:update_time_selection()
    end
  end

  ImGui.SameLine(ctx)
  ImGui.Text(ctx, 'and')
  ImGui.SameLine(ctx)
  self:render_zoom_combo()
end

function TranscriptEditor:render_zoom_combo()
  local disable_if = ReaUtil.disabler(ctx, app.onerror)

  ImGui.SameLine(ctx)
  ImGui.Text(ctx, "zoom to")
  ImGui.SameLine(ctx)
  ImGui.PushItemWidth(ctx, self.BUTTON_WIDTH)
  app:trap(function()
    disable_if(not self.sync_time_selection, function()
      if ImGui.BeginCombo(ctx, "##zoom_level", self.zoom_level) then
        app:trap(function()
          if ImGui.Selectable(ctx, "None", self.zoom_level == "none") then
            self.zoom_level = "none"
          end
          if ImGui.Selectable(ctx, "Word", self.zoom_level == "word") then
            self.zoom_level = "word"
            self:handle_zoom_change()
          end
          if ImGui.Selectable(ctx, "Segment", self.zoom_level == "segment") then
            self.zoom_level = "segment"
            self:handle_zoom_change()
          end
        end)
        ImGui.EndCombo(ctx)
      end
    end)
  end)
  ImGui.PopItemWidth(ctx)
end

function TranscriptEditor:offset()
  return Transcript.calculate_offset(self.editing.segment.item, self.editing.segment.take)
end

function TranscriptEditor:zoom(zoom_level)
  -- save current selection
  local start, end_ = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)

  if zoom_level == "word" then
    self.editing.word:select_in_timeline(self:offset())
  elseif zoom_level == "segment" then
    self.editing.segment:select_in_timeline(self:offset())
  else
    return
  end

  -- View: Zoom time selection
  reaper.Main_OnCommandEx(40031, 1)

  -- restore selection
  reaper.GetSet_LoopTimeRange(true, true, start, end_, false)
end

function TranscriptEditor:render_separator()
  ImGui.Dummy(ctx, self.MIN_CONTENT_WIDTH, 0)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 0)
end

function TranscriptEditor:update_time_selection()
  if self.editing then
    self.editing.word:select_in_timeline(self:offset())
  end
end

function TranscriptEditor:handle_save()
  if self.editing then
    local segment = self.editing.segment
    segment:set_words(self.editing.words)
    self.transcript:update()
  end
end

function TranscriptEditor:handle_word_add()
  local words = self.editing.words
  local word_index = self.editing.word_index
  table.insert(words, word_index + 1, TranscriptWord.new {
    word = '...',
    start = words[word_index].end_,
    end_ = words[word_index].end_,
    probability = 1.0
  })
  self:edit_word(words[word_index + 1], word_index + 1)
end

function TranscriptEditor:handle_word_delete()
  local words = self.editing.words
  local word_index = self.editing.word_index
  table.remove(words, word_index)
  local num_words = #words
  if word_index > num_words then
    word_index = num_words
  end
  self:edit_word(words[word_index], word_index)
end

function TranscriptEditor:handle_word_split()
  local words = self.editing.words
  local word_index = self.editing.word_index
  TranscriptSegment.split_word(words, word_index)
  self:edit_word(words[word_index], word_index)
end

function TranscriptEditor:handle_word_merge()
  local words = self.editing.words
  local word_index = self.editing.word_index
  local num_words = #words
  if word_index < num_words then
    TranscriptSegment.merge_words(words, word_index, word_index + 1)
    self:edit_word(words[word_index], word_index)
  end
end

function TranscriptEditor:handle_zoom_change()
  if self.sync_time_selection then
    self:zoom(self.zoom_level)
  end
end

function TranscriptEditor:_open()
  ImGui.OpenPopup(ctx, self.TITLE)
  self.is_open = true
end

function TranscriptEditor:_close()
  ImGui.CloseCurrentPopup(ctx)
  self.editing = nil
  self.is_open = false
end
