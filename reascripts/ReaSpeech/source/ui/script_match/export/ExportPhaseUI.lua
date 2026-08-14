ExportPhaseUI = Polo {}

function ExportPhaseUI:init()
  Logging().init(self, 'ExportPhaseUI')

  assert(self.session_ui, 'ExportPhaseUI: session_ui is required')
  assert(self.needle_metadata_service, 'ExportPhaseUI: needle_metadata_service is required')
  assert(self.workflow, 'ExportPhaseUI: workflow is required')

  PhaseContainer.init(self, 'export', 'Export', 'package')

  -- Initialize settings
  self.settings = ExportPhaseSettings.new {
    session_id = self.session_ui.session.id
  }

  -- Initialize UI components with metadata service
  self.configuration_ui = ExportConfigurationUI.new {
    settings = self.settings,
    needle_metadata_service = self.needle_metadata_service
  }

  self.preview_ui = ExportPreviewUI.new {
    settings = self.settings,
    session_id = self.session_ui.session.id,
    template_engine = self.configuration_ui.template_editor.template_engine,
    workflow = self.workflow,
  }


  -- React to template edits per keystroke: the preview tree renders
  -- against the in-flight value while typing
  self.configuration_ui.template_editor.on_template_change = function(value)
    self.preview_ui:set_live_template(value)
  end

  -- Suggestion data changes (regeneration heals fields, decisions change
  -- the accepted set) must rebuild export items from storage, or exports
  -- run against a stale in-memory snapshot
  self.workflow:listen_for_event('suggestions_generated', function()
    self.preview_ui:invalidate_cache()
  end)
  self.workflow:listen_for_event('suggestion_decided', function()
    self.preview_ui:invalidate_cache()
  end)
  self.workflow:listen_for_event('suggestion_time_adjusted', function()
    self.preview_ui:invalidate_cache()
  end)

  self:log("Initialized ExportPhaseUI")
end

function ExportPhaseUI:get_status_callback()
  if self.workflow:needles_stale() == 'setup_changed' then
    return {
      indicator = '!',
      hint = "setup changed",
    }
  end

  local status = self.workflow:get_session_status()

  if status.accepted == 0 then
    return {
      hint = "no accepted takes yet",
    }
  end

  local done = status.exported >= status.accepted

  return {
    indicator = done and '*' or 'o',
    hint = ('%d/%d exported'):format(status.exported, status.accepted),
  }
end

-- Config rail + preview: the filename tree is what wants width, so
-- the set-mostly-once configuration takes the smaller share
ExportPhaseUI.CONFIG_RAIL_FRACTION = 0.42
ExportPhaseUI.RAIL_GAP = 12

function ExportPhaseUI:render_content_callback()
  local avail_w = ImGui.GetContentRegionAvail(Ctx())
  local config_w = math.floor(avail_w * ExportPhaseUI.CONFIG_RAIL_FRACTION)

  if ImGui.BeginChild(Ctx(), 'export-config', config_w, 0, ImGui.ChildFlags_None()) then
    Trap(function()
      self.configuration_ui:render(config_w)
    end)
    ImGui.EndChild(Ctx())
  end

  ImGui.SameLine(Ctx(), 0, ExportPhaseUI.RAIL_GAP)

  if ImGui.BeginChild(Ctx(), 'export-preview', 0, 0, ImGui.ChildFlags_None()) then
    Trap(function()
      self.preview_ui:render(ImGui.GetContentRegionAvail(Ctx()))
    end)
    ImGui.EndChild(Ctx())
  end
end

function ExportPhaseUI:will_activate()
  if self.workflow:needles_stale() then
    -- Regenerate needles and refresh the metadata service, then rebuild
    -- export items with fresh enrichment
    self.workflow:regenerate_needles()
    self.preview_ui:invalidate_cache()
  end
end