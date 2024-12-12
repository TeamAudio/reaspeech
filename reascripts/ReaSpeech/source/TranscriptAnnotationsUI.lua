--[[

  TranscriptAnnotationsUI.lua - UI methods to drive TranscriptAnnotations

]]--

TranscriptAnnotationsUI = Polo {
  TITLE = 'Transcript Annotations',
  WIDTH = 650,
  HEIGHT = 200,
  INPUT_WIDTH = 300,
  BUTTON_WIDTH = 120,
}

function TranscriptAnnotationsUI:init()
  assert(self.transcript, "TranscriptAnnotationsUI: transcript is required")

  Logging.init(self, 'TranscriptAnnotationsUI')

  ToolWindow.init(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    theme = Theme.popup,
    window_flags = 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
  })

  self.annotation_types = TranscriptAnnotationTypes.new {
    TranscriptAnnotationTypes.project_markers(),
    TranscriptAnnotationTypes.project_regions(),
    TranscriptAnnotationTypes.take_markers(),
    TranscriptAnnotationTypes.notes_track()
  }

  self.annotations = TranscriptAnnotations.new { transcript = self.transcript }
end

function TranscriptAnnotationsUI:render_content()
  self.annotation_types:render_tab_bar()

  local selected_type = self.annotation_types:selected_type()

  if selected_type then
    ImGui.Spacing(ctx)

    self.annotation_types:render_type_options(self.annotation_type)

    ImGui.Spacing(ctx)
  end

  self:render_separator()

  self:render_buttons(selected_type == nil)
end

function TranscriptAnnotationsUI:render_buttons(is_disabled)
  local disable_if = ReaUtil.disabler(ctx)

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

function TranscriptAnnotationsUI:open()
  self.annotation_types:reset()
end

function TranscriptAnnotationsUI:handle_create()
  local type = self.annotation_types:selected_type()

  if type then
    type.creator(self.annotations)
    self:close()
  end
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

function TranscriptAnnotationTypes:init()
  self.tab_bar = ReaSpeechTabBar.new {
    default = self.types[1].key,
    tabs = self.types,
  }
end

function TranscriptAnnotationTypes:render_tab_bar()
  self.tab_bar:render()
  self.selected_type_key = self.tab_bar:value()
end

function TranscriptAnnotationTypes:selected_key()
  return self:selected_type().key
end

function TranscriptAnnotationTypes:selected_type()
  if not self.selected_type_key then
    return self.types[1]
  end

  return self.types[self.types_map[self.selected_type_key]]
end

function TranscriptAnnotationTypes:render_type_options(options)
  Trap(function()
    local type = self:selected_type()

    if type then
      type.renderer(options)
    end
  end)
end

function TranscriptAnnotationsUI.granularity_combo()
  local combo = ReaSpeechCombo.new {
    state = Storage.memory('segment'),
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
  local granularity_combo = TranscriptAnnotationsUI.granularity_combo()

  local track_filter_mode = ReaSpeechButtonBar.new {
    state = Storage.memory('ignore'),
    label = 'Track Filter Mode',
    buttons = { { 'Include', 'include' }, { 'Ignore', 'ignore' } },
    column_padding = 10,
  }

  local guids_with_tracks = ReaUtil.track_guids()
  local track_guids = {}
  local track_names = {}
  for _, guid_with_track in ipairs(guids_with_tracks) do
    local guid, track = table.unpack(guid_with_track)
    local _, track_name = reaper.GetTrackName(track)
    table.insert(track_guids, guid)
    track_names[guid] = track_name
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
      ImGui.Spacing(ctx)
      track_filter_mode:render()
      ImGui.Spacing(ctx)
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
  local granularity_combo = TranscriptAnnotationsUI.granularity_combo()

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
  local granularity_combo = TranscriptAnnotationsUI.granularity_combo()

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
  local granularity_combo = TranscriptAnnotationsUI.granularity_combo()
  local track_name = ReaSpeechTextInput.simple('Transcript', 'Track Name')

  return {
    label = 'Notes Track',
    key = 'notes_track',

    renderer = function ()
      track_name:render()
      ImGui.Spacing(ctx)
      granularity_combo:render()
    end,

    creator = function (annotations)
      local undo_label = 'Create notes track from transcript'

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
