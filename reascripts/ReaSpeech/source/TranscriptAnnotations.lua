--[[

  TranscriptAnnotations.lua - create/manage markers and regions for transcripts

]]--

TranscriptAnnotations = Polo {
  TITLE = 'Transcript Annotations',
  WIDTH = 650,
  HEIGHT = 200,
  INPUT_WIDTH = 200,
  BUTTON_WIDTH = 120,
}

function TranscriptAnnotations:init()
  assert(self.transcript, "TranscriptAnnotations: transcript is required")

  Logging.init(self, 'TranscriptAnnotations')

  self.is_open = false

  self.annotation_types = TranscriptAnnotationTypes.new {
    TranscriptAnnotationType.type_project_markers(),
    TranscriptAnnotationType.type_notes_track()
  }
end

function TranscriptAnnotations:render()
  if not self.is_open then
    return
  end

  local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
  ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, self.WIDTH, self.HEIGHT, ImGui.Cond_FirstUseEver())

  local flags = (
    0
    | ImGui.WindowFlags_AlwaysAutoResize()
    | ImGui.WindowFlags_NoCollapse()
    | ImGui.WindowFlags_NoDocking()
  )

  local visible, open = ImGui.Begin(ctx, self.TITLE, true, flags)
  if visible then
    app:trap(function ()
      self:render_content()
    end)
    ImGui.End(ctx)
  end

  if not visible or not open then
    self:close()
  end
end

function TranscriptAnnotations:render_content()
  self.annotation_types:render_combo(self.INPUT_WIDTH)

  ImGui.Spacing(ctx)

  self.annotation_types:render_type_options(self.annotation_type)

  ImGui.Spacing(ctx)

  self:render_separator()

  self:render_buttons()
end

function TranscriptAnnotations:render_separator()
  ImGui.Dummy(ctx, 0, 0)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 0)
end

function TranscriptAnnotations:render_buttons()
  if ImGui.Button(ctx, 'Create', self.BUTTON_WIDTH, 0) then
    self:handle_create()
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Close', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptAnnotations:open()
  self.is_open = true
end

function TranscriptAnnotations:close()
  self.is_open = false
end

function TranscriptAnnotations:handle_create()
  local type = self.annotation_types:selected_type()

  if type then
    type.creator(self)
    self:close()
  end
end

function TranscriptAnnotations:project_markers(project, use_words)
  self:create_project_markers(project, false, use_words)
end

function TranscriptAnnotations:project_regions(project, use_words)
  self:create_project_markers(project, true, use_words)
end

function TranscriptAnnotations:take_markers(use_words)
  for _, segment in pairs(self.transcript.data) do
    local oddly_specific_black = 0x01030405

    if use_words then
      for _, word in pairs(segment.words) do
        reaper.SetTakeMarker(segment.take, -1, word.word, word.start, oddly_specific_black)
      end
    else
      reaper.SetTakeMarker(segment.take, -1, segment.text, segment.start, oddly_specific_black)
    end
  end
end

function TranscriptAnnotations:notes_track(use_words)
  self:create_notes_track(use_words)
end

function TranscriptAnnotations:create_project_markers(project, use_regions, use_words)
  project = project or 0
  use_regions = use_regions or false

  for i, segment in pairs(self.transcript.data) do
    self:debug('segment', segment)
    local offset = Transcript.calculate_offset(segment.item, segment.take)
    local want_index = segment:get('id', i)
    local color = 0

    if use_words then
      for _, word in pairs(segment.words) do
        local start = word.start + offset
        local end_ = word.end_ + offset
        local name = word.word
        reaper.AddProjectMarker2(project, use_regions, start, end_, name, want_index, color)
      end
    else
      local start = segment.start + offset
      local end_ = segment.end_ + offset
      local name = segment.text
      reaper.AddProjectMarker2(project, use_regions, start, end_, name, want_index, color)
    end
  end
end

function TranscriptAnnotations:create_notes_track(use_words)
  local original_position = reaper.GetCursorPosition()
  local index = 0

  reaper.InsertTrackAtIndex(index, false)
  local track = reaper.GetTrack(0, index)
  reaper.SetOnlyTrackSelected(track)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', 'Speech', true)
  for _, segment in pairs(self.transcript.data) do
    local offset = Transcript.calculate_offset(segment.item, segment.take)

    if use_words then
      for _, word in pairs(segment.words) do
        local start = word.start + offset
        local end_ = word.end_ + offset
        local text = word.word
        self:_create_note(start, end_, text, false)
      end
    else
      local start = segment.start + offset
      local end_ = segment.end_ + offset
      local text = segment.text
      self:_create_note(start, end_, text, true)
    end
  end
  reaper.SetEditCurPos(original_position, true, true)
end

function TranscriptAnnotations:_create_note(start, end_, text, stretch)
  local item = self:_create_empty_item(start, end_)
  self:_set_note_text(item, text, stretch)
end

function TranscriptAnnotations:_create_empty_item(start, end_)
  self:_insert_empty_item()
  local item = reaper.GetSelectedMediaItem(0, 0)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemPosition(item, start, true)
  reaper.SetMediaItemLength(item, end_ - start, true)
  return item
end

function TranscriptAnnotations:_insert_empty_item()
  reaper.Main_OnCommand(40142, 0)
end

function TranscriptAnnotations:_set_note_text(item, text, stretch)
  local _, chunk = reaper.GetItemStateChunk(item, "", false)
  local notes_chunk = ("<NOTES\n|%s\n>\n"):format(text:match("^%s*(.-)%s*$"))
  local flags_chunk = (stretch and "IMGRESOURCEFLAGS 11\n" or "")
  chunk = chunk:gsub('>', notes_chunk:gsub('%%', '%%%%') .. flags_chunk .. '>')
  reaper.SetItemStateChunk(item, chunk, false)
end

TranscriptAnnotationTypes = Polo {
  new = function(types)
    local types_map = {}

    for i, type in ipairs(types) do
      types_map[type.key] = i
    end

    return {
      types = types,
      types_map = types_map
    }
  end
}

function TranscriptAnnotationTypes:init()
  Logging.init(self, 'TranscriptAnnotationTypes')
end

function TranscriptAnnotationTypes:render_combo(width)
  ImGui.SetNextItemWidth(ctx, width)
  local selected_type = self:selected_type()
  if ImGui.BeginCombo(ctx, "##annotation_type", selected_type and selected_type.label or "Annotation Type") then
    app:trap(function()
      for _, type in pairs(self.types) do
        local is_selected = self.selected_type_key == type.key
        if ImGui.Selectable(ctx, type.label, is_selected, ImGui.SelectableFlags_None()) then
          self:log('Selected type: ' .. dump(type))
          self.selected_type_key = type.key
        end
        if is_selected then
          ImGui.SetItemDefaultFocus(ctx)
        end
      end
    end)
    ImGui.EndCombo(ctx)
  end
end

function TranscriptAnnotationTypes:selected_key()
  return self:selected_type().key
end

function TranscriptAnnotationTypes:selected_type()
  if not self.selected_type_key then
    return nil
  end

  return self.types[self.types_map[self.selected_type_key]]
end

function TranscriptAnnotationTypes:render_type_options(options)
  app:trap(function()
    local type = self:selected_type()

    if type then
      type.renderer(options)
    end
  end)
end

TranscriptAnnotationType = Polo {
  new = function(label, key, renderer, creator)
    return {
      label = label,
      key = key,
      renderer = renderer,
      creator = creator
    }
  end
}

function TranscriptAnnotationType.type_project_markers()
  local item_labels = {
    take_markers = 'Take Markers',
    project_markers = 'Project Markers',
    project_regions = 'Project Regions'
  }

  local marker_type_combo = ReaSpeechCombo.new {
    state = Storage.memory('take_markers'),
    label = 'Marker Type',
    items = { 'take_markers', 'project_markers', 'project_regions' },
    item_labels = item_labels,
  }

  local granularity_combo = TranscriptAnnotations.granularity_combo()

  return TranscriptAnnotationType.new(
    'Project Markers & Regions',
    'project_markers',
    function ()
      marker_type_combo:render()
      granularity_combo:render()
    end,
    function (annotations)

      local use_words = granularity_combo:value() == 'word'
      local marker_type = marker_type_combo:value()

      reaper.PreventUIRefresh(1)
      reaper.Undo_BeginBlock()

      if marker_type == 'take_markers' then
        annotations:take_markers(use_words)
      elseif marker_type == 'project_markers' then
        annotations:project_markers(0, use_words)
      elseif marker_type == 'project_regions' then
        annotations:project_regions(0, use_words)
      end

      local undo_label = ('Create %s from transcript'):format(item_labels[marker_type_combo:value()])
      reaper.Undo_EndBlock(undo_label, -1)
      reaper.PreventUIRefresh(-1)
    end
  )
end

function TranscriptAnnotations.granularity_combo()
  return ReaSpeechCombo.new {
    state = Storage.memory('word'),
    label = 'Granularity',
    items = { 'word', 'segment' },
    item_labels = { word = 'Word', segment = 'Segment' },
  }
end

function TranscriptAnnotationType.type_notes_track()
  local granularity_combo = TranscriptAnnotations.granularity_combo()

  return TranscriptAnnotationType.new(
    'Subtitle Notes Track',
    'notes_track',
    function ()
      granularity_combo:render()
    end,
    function (annotations)
      reaper.PreventUIRefresh(1)
      reaper.Undo_BeginBlock()

      annotations:notes_track(granularity_combo:value() == 'word')

      local undo_label = 'Create subtitle notes track from transcript'
      reaper.Undo_EndBlock(undo_label, -1)
      reaper.PreventUIRefresh(-1)
    end
  )
end