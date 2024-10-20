--[[

  TranscriptAnnotations.lua - create/manage markers and regions for transcripts

]]--

TranscriptAnnotations = Polo {
  TITLE = 'Transcript Annotations',
  WIDTH = 650,
  HEIGHT = 200,
  INPUT_WIDTH = 300,
  BUTTON_WIDTH = 120,
}

function TranscriptAnnotations:init()
  assert(self.transcript, "TranscriptAnnotations: transcript is required")

  Logging.init(self, 'TranscriptAnnotations')

  self.disabler = ReaUtil.disabler(ctx)

  self.is_open = false

  self.annotation_types = TranscriptAnnotationTypes.new {
    TranscriptAnnotationTypes.take_markers(),
    TranscriptAnnotationTypes.project_markers(),
    TranscriptAnnotationTypes.project_regions(),
    TranscriptAnnotationTypes.notes_track()
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

  local selected_type = self.annotation_types:selected_type()

  if selected_type then
    self:render_separator()

    ImGui.Spacing(ctx)

    self.annotation_types:render_type_options(self.annotation_type)

    ImGui.Spacing(ctx)
  end

  self:render_separator()

  self:render_buttons(selected_type == nil)
end

function TranscriptAnnotations:render_separator()
  ImGui.Dummy(ctx, 0, 0)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 0)
end

function TranscriptAnnotations:render_buttons(is_disabled)
  local disable_if = self.disabler

  disable_if(is_disabled, function()
    if ImGui.Button(ctx, 'Create', self.BUTTON_WIDTH, 0) then
      self:handle_create()
    end
  end)

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Close', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function TranscriptAnnotations:open()
  self.annotation_types:reset()
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

function TranscriptAnnotations:take_markers(use_words, track_filter_config)
    track_filter_config = track_filter_config or { mode = 'ignore', tracks = {} }

    local oddly_specific_black = 0x01030405

    local takes = {}

    for element in self.transcript:iterator(use_words) do
      local _, take_guid = reaper.GetSetMediaItemTakeInfo_String(element.take, 'GUID', '', false)

      if not takes[take_guid] then
        takes[take_guid] = {}
        local path = ReaSpeechUI.get_source_path(element.take)

        for item in ReaIter.each_media_item() do
          for take in ReaIter.each_take(item) do
            local take_path = ReaSpeechUI.get_source_path(take)

            if take_path == path then
              local track_guid = reaper.GetTrackGUID(reaper.GetMediaItemTake_Track(take))
              if track_filter_config.mode == 'ignore' and not track_filter_config.tracks[track_guid]
              or track_filter_config.mode == 'include' and track_filter_config.tracks[track_guid] then
                table.insert(takes[take_guid], take)
              end
            end
          end
        end
      end

      for _, take in ipairs(takes[take_guid]) do
        reaper.SetTakeMarker(take, -1, element.text, element.start, oddly_specific_black)
      end
    end
end

function TranscriptAnnotations:project_markers(project, use_words)
  self:create_project_markers(project, false, use_words)
end

function TranscriptAnnotations:project_regions(project, use_words)
  self:create_project_markers(project, true, use_words)
end

function TranscriptAnnotations:create_project_markers(project, use_regions, use_words)
  project = project or 0
  use_regions = use_regions or false
  use_words = use_words or false

  for element in self.transcript:iterator(use_words) do
    local offset = Transcript.calculate_offset(element.item, element.take)
    local want_index = element.id or 0
    local color = 0

    local start = element.start + offset
    local end_ = element.end_ + offset
    reaper.AddProjectMarker2(project, use_regions, start, end_, element.text, want_index, color)
  end
end

function TranscriptAnnotations:notes_track(use_words, track_name)
  track_name = track_name or 'Speech'
  local stretch = not use_words
  local original_position = reaper.GetCursorPosition()

  local index = 0
  reaper.InsertTrackAtIndex(index, false)
  local track = reaper.GetTrack(0, index)
  reaper.SetOnlyTrackSelected(track)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)

  for element in self.transcript:iterator(use_words) do
    local offset = Transcript.calculate_offset(element.item, element.take)
    local start = element.start + offset
    local end_ = element.end_ + offset
    self:_create_note(start, end_, element.text, stretch)
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

function TranscriptAnnotationTypes:reset()
  self.selected_type_key = nil
end

function TranscriptAnnotationTypes:render_combo(width)
  ImGui.SetNextItemWidth(ctx, width)
  local selected_type = self:selected_type()
  if ImGui.BeginCombo(ctx, "##annotation_type", selected_type and selected_type.label or "Annotation Type") then
    app:trap(function()
      for _, type in pairs(self.types) do
        local is_selected = self.selected_type_key == type.key
        if ImGui.Selectable(ctx, type.label, is_selected, ImGui.SelectableFlags_None()) then
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

function TranscriptAnnotations.granularity_combo()
  local combo = ReaSpeechCombo.new {
    state = Storage.memory('word'),
    label = 'Granularity',
    items = { 'word', 'segment' },
    item_labels = { word = 'Word', segment = 'Segment' },
  }

  function combo:use_words()
    return self:value() == 'word'
  end

  return combo
end

function TranscriptAnnotationTypes.take_markers()
  local granularity_combo = TranscriptAnnotations.granularity_combo()

  local track_filter_mode = ReaSpeechButtonBar.new {
    state = Storage.memory('ignore'),
    label = 'Track Filter Mode',
    buttons = { { 'Include', 'include' }, { 'Ignore', 'ignore' } },
  }

  local track_guids = {}
  local track_names = {}
  for k, v in pairs(ReaUtil.track_guid_map()) do
    table.insert(track_guids, k)
    local _, track_name = reaper.GetTrackName(v)
    track_names[k] = track_name
  end

  local track_selector = ReaSpeechListBox.new {
    state = Storage.memory({}),
    label = 'Track Filter',
    items = track_guids,
    item_labels = track_names,
  }

  return {
    label = 'Take Markers',
    key = 'take_markers',
    renderer = function ()
      granularity_combo:render()
      track_filter_mode:render()
      track_selector:render()
    end,
    creator = function (annotations)
      local undo_label = 'Create take markers from transcript'

      local track_filter_config = {
        mode = track_filter_mode:value(),
        tracks = track_selector:value()
      }

      TranscriptAnnotationTypes._with_undo(undo_label, function()
        annotations:take_markers(granularity_combo:use_words(), track_filter_config)
      end)
    end
  }
end

function TranscriptAnnotationTypes.project_markers()
  local granularity_combo = TranscriptAnnotations.granularity_combo()

  return {
    label = 'Project Markers',
    key = 'project_markers',
    renderer = function ()
      granularity_combo:render()
    end,
    creator = function (annotations)
      local undo_label = 'Create project markers from transcript'

      TranscriptAnnotationTypes._with_undo(undo_label, function()
        annotations:project_markers(0, granularity_combo:use_words())
      end)
    end
  }
end

function TranscriptAnnotationTypes.project_regions()
  local granularity_combo = TranscriptAnnotations.granularity_combo()

  return {
    label = 'Project Regions',
    key = 'project_regions',

    renderer = function ()
      granularity_combo:render()
    end,

    creator = function (annotations)
      local undo_label = 'Create project regions from transcript'

      TranscriptAnnotationTypes._with_undo(undo_label, function()
        annotations:project_regions(0, granularity_combo:use_words())
      end)
    end
  }
end

function TranscriptAnnotationTypes.notes_track()
  local granularity_combo = TranscriptAnnotations.granularity_combo()
  local track_name = ReaSpeechTextInput.simple('Transcript', 'Track Name')

  return {
    label = 'Subtitle Notes Track',
    key = 'notes_track',

    renderer = function ()
      track_name:render()
      granularity_combo:render()
    end,

    creator = function (annotations)
      local undo_label = 'Create subtitle notes track from transcript'

      TranscriptAnnotationTypes._with_undo(undo_label, function()
        annotations:notes_track(granularity_combo:use_words(), track_name:value())
      end)
    end
  }
end

function TranscriptAnnotationTypes._with_undo(label, f)
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  f()
  reaper.Undo_EndBlock(label, -1)
  reaper.PreventUIRefresh(-1)
end