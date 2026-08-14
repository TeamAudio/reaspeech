
HaystackSetupUI = Polo {
  TRACK_HEIGHT = 60,
}

function HaystackSetupUI:init()
  Logging().init(self, 'HaystackSetupUI')

  assert(self.session_id, 'HaystackSetupUI: session_id is required')
  assert(self.workflow, 'HaystackSetupUI: workflow is required')

  self.audio_tracks = ScriptMatchAudioTracks.new {
    session_id = self.session_id,
  }

  self.project_audio_tracks = self.audio_tracks:get_project_tracks(ReaperConstants.CURRENT_PROJECT)

  self.track_uis = self:init_track_uis()

  self:log("Initialized HaystackSetupUI")
end

function HaystackSetupUI:init_track_uis()
  local track_uis = {}

  for _, track in ipairs(self.project_audio_tracks) do
    local track_ui = ScriptMatchAudioTrackUI.new {
      audio_tracks = self.audio_tracks,
      session_id = self.session_id,
      workflow = self.workflow,
      track = track,
    }
    table.insert(track_uis, track_ui)
  end

  return track_uis
end

function HaystackSetupUI:render(panel_width)
  if ImGui.BeginChild(Ctx(), 'haystack-setup', panel_width, 0, ImGui.WindowFlags_None()) then
    Trap(function()
      self:render_audio_tracks()
    end)

    ImGui.EndChild(Ctx())
  end
end

function HaystackSetupUI:render_audio_tracks()
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), "Project Audio Tracks")
  end, Trap)
  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)

  ImGui.Indent(Ctx(), 6)
  ImGui.PushStyleVar(Ctx(), ImGui.StyleVar_ItemSpacing(), 8, 7)
  Trap(function()
    for _, track_ui in ipairs(self.track_uis) do
      track_ui:render_summary()
    end
  end)
  ImGui.PopStyleVar(Ctx())
  ImGui.Unindent(Ctx(), 6)
end
