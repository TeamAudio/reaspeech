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

  ZOOM_LEVEL = {
    NONE =    { value = "none",    description = "None" },
    WORD =    { value = "word",    description = "Word" },
    SEGMENT = { value = "segment", description = "Segment" },
  },
}

function TranscriptEditor:init()
  assert(self.transcript, 'missing transcript')
  self.editing = nil

  self.on_save = self.on_save or function() end

  Logging().init(self, 'TranscriptEditor')

  ToolWindow.modal(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    window_flags = ImGui.WindowFlags_AlwaysAutoResize(),
    guard = function() return self:closing() or self.editing and true or false end
  })

  self.sync_time_selection = false
  self.zoom_level = self.ZOOM_LEVEL.NONE.value
  self.key_bindings = self:make_key_bindings()
end

function TranscriptEditor:make_key_bindings()
  return KeyMap.new({
    [ImGui.Key_LeftArrow()] = function ()
      self:edit_word(self.editing.word_index - 1)
    end,
    [ImGui.Key_RightArrow()] = function ()
      self:edit_word(self.editing.word_index + 1)
    end,
  })
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
  self:edit_word(1)
end

function TranscriptEditor:edit_word(index)
  if index < 1 or index > #self.editing.words then
    return
  end

  local word = self.editing.words[index]
  self.editing.word = word
  self.editing.word_index = index
  if self.sync_time_selection then
    self:update_time_selection()
    self:zoom(self.zoom_level)
  end
end

function TranscriptEditor:render_content()
  if not ImGui.IsAnyItemActive(Ctx()) then
    self.key_bindings:react()
  end

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
    self:edit_word(edit_requested)
  end

  self:render_separator()

  if ImGui.Button(Ctx(), 'Save', self.BUTTON_WIDTH, 0) then
    self:handle_save()
    self:close()
  end

  ImGui.SameLine(Ctx())
  if ImGui.Button(Ctx(), 'Cancel', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptEditor:render_word_navigation()
  local words = self.editing.words
  local word_index = self.editing.word_index
  local num_words = #words
  local spacing = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_ItemInnerSpacing())

  ImGui.PushButtonRepeat(Ctx(), true)
  Trap(function ()
    if ImGui.ArrowButton(Ctx(), '##left', ImGui.Dir_Left()) then
      self:edit_word(self.editing.word_index - 1)
    end
    ImGui.SameLine(Ctx(), 0, spacing)
    if ImGui.ArrowButton(Ctx(), '##right', ImGui.Dir_Right()) then
      self:edit_word(self.editing.word_index + 1)
    end
  end)
  ImGui.PopButtonRepeat(Ctx())

  ImGui.SameLine(Ctx())
  ImGui.AlignTextToFramePadding(Ctx())
  ImGui.Text(Ctx(), 'Word ' .. word_index .. ' / ' .. num_words)

  ImGui.SameLine(Ctx())
  if ImGui.Button(Ctx(), 'Add') then
    self:handle_word_add()
  end
  Widgets.tooltip('Add word after current word')

  ImGui.SameLine(Ctx(), 0, spacing)

  Widgets.disable_if(num_words <= 1, function()
    if ImGui.Button(Ctx(), 'Delete') then
      self:handle_word_delete()
    end
  end)
  Widgets.tooltip('Delete current word')

  ImGui.SameLine(Ctx(), 0, spacing)
  if ImGui.Button(Ctx(), 'Split') then
    self:handle_word_split()
  end
  Widgets.tooltip('Split current word into two words')

  ImGui.SameLine(Ctx(), 0, spacing)
  Widgets.disable_if(word_index >= num_words, function()
    if ImGui.Button(Ctx(), 'Merge') then
      self:handle_word_merge()
    end
  end)
  Widgets.tooltip('Merge current word with next word')
end

function TranscriptEditor:render_words()
  local words = self.editing.words
  local num_words = #words
  local spacing = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_ItemInnerSpacing())
  local edit_requested = nil

  for i, word in pairs(words) do
    if self.editing.word_index ~= i then
      ImGui.PushStyleColor(Ctx(), ImGui.Col_Button(), 0xffffff33)
    end
    Trap(function()
      if ImGui.Button(Ctx(), word.word .. '##' .. i) then
        edit_requested = i
      end
    end)
    if self.editing.word_index ~= i then
      ImGui.PopStyleColor(Ctx())
    end

    if i < num_words and i % self.WORDS_PER_LINE ~= 0 then
      ImGui.SameLine(Ctx(), 0, spacing)
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
  local rv, value = ImGui.InputText(Ctx(), 'word', self.editing.word.word)
  if rv then
    value = value:gsub('^%s*(.-)%s*$', '%1')
    if #value > 0 then
      self.editing.word.word = value
    end
  end
end

function TranscriptEditor:render_time_input(label, value, callback)
  local value_str = reaper.format_timestr(value, '')
  local rv, new_value = ImGui.InputText(Ctx(), label, value_str)
  if rv then
    callback(reaper.parse_timestr(new_value))
  end
end

function TranscriptEditor:render_score_input()
  local color = TranscriptUI.score_color(self.editing.word:score())
  if color then
    ImGui.PushStyleColor(Ctx(), ImGui.Col_SliderGrab(), color)
    ImGui.PushStyleColor(Ctx(), ImGui.Col_SliderGrabActive(), color)
  end
  Trap(function ()
    local rv, value = ImGui.SliderDouble(Ctx(), 'score', self.editing.word.probability, 0, 1)
    if rv then
      self.editing.word.probability = value
    end
  end)
  if color then
    ImGui.PopStyleColor(Ctx(), 2)
  end
end

function TranscriptEditor:render_word_actions()
  if Widgets.icon_button(Icons.play, '##play', 27, 27, 'Play word') then
    self:update_time_selection()
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    reaper.Main_OnCommand(40630, 0) -- Go to start of time selection
    reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
  end

  local spacing = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_ItemInnerSpacing())
  ImGui.SameLine(Ctx(), 0, spacing)

  if Widgets.icon_button(Icons.stop, '##stop', 27, 27, 'Stop') then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
  end

  ImGui.SameLine(Ctx())
  local rv, value = ImGui.Checkbox(Ctx(), 'sync time selection', self.sync_time_selection)
  if rv then
    self.sync_time_selection = value
    if value then
      self:update_time_selection()
    end
  end

  ImGui.SameLine(Ctx())
  ImGui.Text(Ctx(), 'and')
  ImGui.SameLine(Ctx())
  self:render_zoom_combo()
end

function TranscriptEditor:render_zoom_combo()
  ImGui.SameLine(Ctx())
  ImGui.Text(Ctx(), "zoom to")
  ImGui.SameLine(Ctx())
  ImGui.PushItemWidth(Ctx(), self.BUTTON_WIDTH)
  Trap(function()
    Widgets.disable_if(not self.sync_time_selection, function()
      if ImGui.BeginCombo(Ctx(), "##zoom_level", self.zoom_level) then
        Trap(function()
          for _, zoom in pairs(self.ZOOM_LEVEL) do
            if ImGui.Selectable(Ctx(), zoom.description, self.zoom_level == zoom.value) then
              self.zoom_level = zoom.value
              self:handle_zoom_change()
            end
          end
        end)
        ImGui.EndCombo(Ctx())
      end
    end)
  end)
  ImGui.PopItemWidth(Ctx())
end

function TranscriptEditor:offset()
  return Transcript.calculate_offset(self.editing.segment.item, self.editing.segment.take)
end

function TranscriptEditor:zoom(zoom_level)
  -- save current selection
  local start, end_ = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)

  if zoom_level == self.ZOOM_LEVEL.WORD.value then
    self.editing.word:select_in_timeline(self:offset())
  elseif zoom_level == self.ZOOM_LEVEL.SEGMENT.value then
    self.editing.segment:select_in_timeline(self:offset())
  else
    return
  end

  -- View: Zoom time selection
  reaper.Main_OnCommandEx(40031, 1)

  -- restore selection
  reaper.GetSet_LoopTimeRange(true, true, start, end_, false)
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
    self.on_save()
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
  self:edit_word(word_index + 1)
end

function TranscriptEditor:handle_word_delete()
  local words = self.editing.words
  local word_index = self.editing.word_index
  table.remove(words, word_index)
  local num_words = #words
  if word_index > num_words then
    word_index = num_words
  end
  self:edit_word(word_index)
end

function TranscriptEditor:handle_word_split()
  local words = self.editing.words
  local word_index = self.editing.word_index
  TranscriptSegment.split_word(words, word_index)
  self:edit_word(word_index)
end

function TranscriptEditor:handle_word_merge()
  local words = self.editing.words
  local word_index = self.editing.word_index
  local num_words = #words
  if word_index < num_words then
    TranscriptSegment.merge_words(words, word_index, word_index + 1)
    self:edit_word(word_index)
  end
end

function TranscriptEditor:handle_zoom_change()
  if self.sync_time_selection then
    self:zoom(self.zoom_level)
  end
end

function TranscriptEditor:close()
  self.editing = nil
end
