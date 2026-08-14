ScriptMatchWorkflow = Polo {}

function ScriptMatchWorkflow:init()
  Logging().init(self, 'ScriptMatchWorkflow')

  assert(self.session_ui, 'ScriptMatchWorkflow: session_ui is required')

  -- Event system for component communication; every event name and its
  -- required payload fields are declared in WorkflowEvents.schema
  self.events = EventEmitter.new { schema = WorkflowEvents.schema }

  -- Initialize core services as workflow singletons
  -- Note: needle_generator will be lazily initialized when script materials are available
  self.needle_generator = nil

  self.needle_metadata_service = NeedleMetadataService.new {
    session_id = self.session_ui:session_id(),
    workflow = self -- Pass workflow for event emission
  }

  -- The single suggestion store shared by curation and export
  self.suggestion_state_manager = SuggestionStateManager.new {
    session_id = self.session_ui:session_id()
  }

  -- The single script materials store shared by setup and generation
  self.script_materials_service = ScriptMaterials.new {
    session_id = self.session_ui:session_id()
  }

  self.phases = {
    setup = SetupPhaseUI.new { session_ui = self.session_ui, workflow = self },
    curation = CurationPhaseUI.new { session_ui = self.session_ui, workflow = self },
    export = ExportPhaseUI.new {
      session_ui = self.session_ui,
      workflow = self,
      needle_metadata_service = self.needle_metadata_service  -- Inject service
    },
  }

  self.ordered_phases = {
    'setup',
    'curation',
    'export',
  }

  -- Set on first render (not here) so the initial will_activate fires
  -- after every phase's event listeners exist
  self.active_phase = nil

  -- Derived completion counts for phase headers; event-invalidated
  self.session_status = SessionStatus.new {
    session_id = self.session_ui:session_id(),
    workflow = self,
  }

  -- Track registered nudgeables for centralized timing
  self.nudgeables = {}

  -- Tokenized transcript streams keyed by track+transcript file; shared
  -- across matcher instances so regeneration doesn't re-import transcripts
  self.matcher_stream_cache = {}

  -- Needles start stale ('initial': not generated this session yet —
  -- expected, not alarming); material changes escalate to
  -- 'setup_changed' (generated needles now outdated). Cleared by
  -- regenerate_needles(). Both values are truthy for needles_stale().
  self._needles_stale = 'initial'
  self:listen_for_event('script_material_updated', function()
    self._needles_stale = 'setup_changed'
  end)
  self:listen_for_event('script_material_unlinked', function()
    self._needles_stale = 'setup_changed'
  end)

  self:log("Initialized ScriptMatchWorkflow with event system and core services")
end

function ScriptMatchWorkflow:render()
  -- The session tab owns the keyboard (curation bindings, export inputs);
  -- suppress ImGui keyboard nav so arrows/Enter cannot wander into other
  -- widgets, e.g. the outer tab bar. Nav is restored each frame by
  -- ReaSpeechUI, so other tabs keep it.
  Widgets.set_keyboard_nav(false)

  -- Update all registered nudgeables before rendering phases
  self:nudgeables_react()

  -- First render picks the landing phase through the same path as a
  -- click, so its will_activate hook fires after all listeners are
  -- registered
  if not self.active_phase then
    self:activate_phase(self:initial_phase())
  end

  self:render_phase_bar()

  ImGui.Dummy(Ctx(), 0, 4)
  ImGui.Separator(Ctx())

  self.phases[self.active_phase]:render()
end

-- The session opens on the first phase with work remaining (the '*'
-- completion indicator marks a finished phase, same source the cards
-- display); a fully complete session lands on export, where the
-- output lives
function ScriptMatchWorkflow:initial_phase()
  for _, phase_key in ipairs(self.ordered_phases) do
    if self.phases[phase_key]:get_completion_status().indicator ~= '*' then
      return phase_key
    end
  end

  return 'export'
end

function ScriptMatchWorkflow:activate_phase(phase_key)
  if phase_key == self.active_phase then return end

  local phase = self.phases[phase_key]
  if phase.will_activate then
    phase:will_activate()
  end

  self.active_phase = phase_key
end

-- Phase selector cards, styled after the source selector on a
-- physical device: each phase is one pressable region - identity icon
-- left, phase name over a status tagline right - and the active card
-- is the lit-up one. Uniform sizing keeps the row reading as one
-- control.
ScriptMatchWorkflow.PHASE_CARD = {
  PADDING = 10,
  ICON_GAP = 10,
  CARD_GAP = 8,
  ROUNDING = 6,
  PRESS_NUDGE = 1,
  TAGLINE_COLOR = 0x999999FF,
  NAME_NUDGE = 2,
}

-- Card row height: big-font title line over a main-font tagline line
-- plus padding (font handles carry their created size, so this needs
-- no active font context)
function ScriptMatchWorkflow.phase_card_row_height()
  return ScriptMatchWorkflow.PHASE_CARD.PADDING * 2 + Fonts.big.size + Fonts.main.size
end

-- How far the session name (rendered in bigboi by the session header)
-- must drop to sit centered against the card row. Geometric centering
-- reads slightly low - line height includes descender space the name
-- rarely uses - so NAME_NUDGE lifts it a touch.
function ScriptMatchWorkflow.phase_card_center_offset()
  return (ScriptMatchWorkflow.phase_card_row_height() - Fonts.bigboi.size) / 2
    - ScriptMatchWorkflow.PHASE_CARD.NAME_NUDGE
end

function ScriptMatchWorkflow:phase_bar_width(metrics)
  metrics = metrics or self:phase_card_metrics()

  return #self.ordered_phases * metrics.width
    + (#self.ordered_phases - 1) * ScriptMatchWorkflow.PHASE_CARD.CARD_GAP
end

function ScriptMatchWorkflow:render_phase_bar()
  -- The session name preceded us on this row, vertically centered;
  -- undo its centering offset so the cards define the row top
  ImGui.SetCursorPosY(Ctx(), ImGui.GetCursorPosY(Ctx()) - ScriptMatchWorkflow.phase_card_center_offset())

  local metrics = self:phase_card_metrics()

  -- Right-aligned: the cards anchor to the window edge, leaving the
  -- rest of the row to the session name (and its rename editor)
  local avail_w = ImGui.GetContentRegionAvail(Ctx())
  local x, row_top = ImGui.GetCursorScreenPos(Ctx())
  ImGui.SetCursorScreenPos(Ctx(), x + math.max(0, avail_w - self:phase_bar_width(metrics)), row_top)

  for i, phase_key in ipairs(self.ordered_phases) do
    if i > 1 then
      -- SameLine aligns follow-on cards to the session name's
      -- (dropped) line Y, not the card row top, so pin Y explicitly
      ImGui.SameLine(Ctx(), 0, ScriptMatchWorkflow.PHASE_CARD.CARD_GAP)
      local card_x = ImGui.GetCursorScreenPos(Ctx())
      ImGui.SetCursorScreenPos(Ctx(), card_x, row_top)
    end

    self:render_phase_card(phase_key, metrics)
  end
end

-- Cards share one size: icon slot spans both text lines, width fits
-- the widest title/tagline across all phases (so cards don't shift as
-- counts change)
function ScriptMatchWorkflow:phase_card_metrics()
  local c = ScriptMatchWorkflow.PHASE_CARD

  local title_h = 0
  local text_w = 0

  Fonts.wrap(Ctx(), Fonts.big, function()
    title_h = ImGui.GetTextLineHeight(Ctx())
    for _, phase_key in ipairs(self.ordered_phases) do
      local w = ImGui.CalcTextSize(Ctx(), self.phases[phase_key]:phase_name())
      if w > text_w then text_w = w end
    end
  end, Trap)

  local tagline_h = ImGui.GetTextLineHeight(Ctx())
  for _, phase_key in ipairs(self.ordered_phases) do
    local w = EmojiText.calc_width(self:phase_tagline(self.phases[phase_key]))
    if w > text_w then text_w = w end
  end

  local icon_size = title_h + tagline_h

  return {
    icon_size = icon_size,
    title_h = title_h,
    width = c.PADDING * 2 + icon_size + c.ICON_GAP + text_w,
    height = c.PADDING * 2 + title_h + tagline_h,
  }
end

function ScriptMatchWorkflow:phase_tagline(phase)
  local status = phase:get_completion_status()
  local tag = status.indicator and PhaseContainer.INDICATOR_TAGS[status.indicator]
  local hint = status.hint or ''

  if tag then
    return ':' .. tag .. ': ' .. hint
  end

  return hint
end

function ScriptMatchWorkflow:render_phase_card(phase_key, metrics)
  local c = ScriptMatchWorkflow.PHASE_CARD
  local phase = self.phases[phase_key]
  local active = phase_key == self.active_phase

  -- The group makes the whole card one layout item, so SameLine chains
  -- across cards despite the cursor repositioning inside
  ImGui.BeginGroup(Ctx())
  Trap(function()
    local x, y = ImGui.GetCursorScreenPos(Ctx())

    -- The button provides interaction state; all pixels are DrawList
    local clicked = ImGui.InvisibleButton(Ctx(), '##phase-card-' .. phase_key, metrics.width, metrics.height)
    local hovered = ImGui.IsItemHovered(Ctx())
    local held = ImGui.IsItemActive(Ctx())

    if hovered then
      ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
    end

    local bg = Theme.COLORS.dark_gray_translucent
    if held then
      bg = Theme.COLORS.dark_gray_opaque
    elseif active then
      bg = Theme.COLORS.medium_gray_opaque
    elseif hovered then
      bg = Theme.COLORS.dark_gray_semi_transparent
    end

    local dl = ImGui.GetWindowDrawList(Ctx())

    -- Active card glows: accent border with a soft falloff halo
    if active then
      local accent = Theme.COLORS.pink_opaque
      local halo_alphas = { 0x99, 0x55, 0x26 }
      for i, alpha in ipairs(halo_alphas) do
        ImGui.DrawList_AddRect(dl,
          x - i, y - i, x + metrics.width + i, y + metrics.height + i,
          (accent & 0xFFFFFF00) | alpha, c.ROUNDING + i)
      end
    end

    ImGui.DrawList_AddRectFilled(dl, x, y, x + metrics.width, y + metrics.height, bg, c.ROUNDING)

    -- Held cards press in: contents shift down a pixel
    local content_y = y + c.PADDING + (held and c.PRESS_NUDGE or 0)
    local content_x = x + c.PADDING

    ImGui.SetCursorScreenPos(Ctx(), content_x, content_y)
    EmojiText.icon(phase:phase_icon(), metrics.icon_size)

    local text_x = content_x + metrics.icon_size + c.ICON_GAP

    ImGui.SetCursorScreenPos(Ctx(), text_x, content_y)
    Fonts.wrap(Ctx(), Fonts.big, function()
      ImGui.Text(Ctx(), phase:phase_name())
    end, Trap)

    ImGui.SetCursorScreenPos(Ctx(), text_x, content_y + metrics.title_h)
    EmojiText.render(self:phase_tagline(phase), c.TAGLINE_COLOR)

    if clicked then
      self:activate_phase(phase_key)
    end
  end)
  ImGui.EndGroup(Ctx())
end

function ScriptMatchWorkflow:audio_tracks()
  return self.phases.setup:audio_tracks()
end

function ScriptMatchWorkflow:audio_track(guid)
  return self.phases.setup:audio_track(guid)
end

function ScriptMatchWorkflow:script_materials()
  return self.script_materials_service:get_materials()
end

-- Get the workflow-owned ScriptMaterials store
function ScriptMatchWorkflow:get_script_materials_service()
  return self.script_materials_service
end

-- Public accessor methods for workflow-owned core services

-- Get the workflow-owned NeedleMetadataService
function ScriptMatchWorkflow:get_needle_metadata_service()
  return self.needle_metadata_service
end

-- Get the workflow-owned SuggestionStateManager
function ScriptMatchWorkflow:get_suggestion_state_manager()
  return self.suggestion_state_manager
end

-- Get the workflow-owned SessionStatus summary
function ScriptMatchWorkflow:get_session_status()
  return self.session_status:summary()
end

-- Get one needle's suggestion summary (nil if none generated)
function ScriptMatchWorkflow:get_needle_status(needle_guid)
  return self.session_status:needle_summary(needle_guid)
end

-- Get the workflow-owned audio preview (created on first use)
function ScriptMatchWorkflow:get_audio_preview()
  if not self.audio_preview then
    self.audio_preview = SuggestionAudioPreview.new { workflow = self }
  end
  return self.audio_preview
end

-- Get the shared matcher stream cache
function ScriptMatchWorkflow:get_matcher_stream_cache()
  return self.matcher_stream_cache
end

-- Get the workflow-owned oneshot runner (created on first use)
function ScriptMatchWorkflow:get_oneshot_runner()
  if not self.oneshot_runner then
    self.oneshot_runner = OneshotRunner.new {
      session_id = self.session_ui:session_id(),
      workflow = self,
    }
  end
  return self.oneshot_runner
end

-- Regenerate needles from current script materials, refresh the metadata
-- service, and broadcast the new list to listening components
function ScriptMatchWorkflow:regenerate_needles()
  self:initialize_needle_generator()

  local needles = self.needle_generator:needles()
  self.needle_metadata_service:refresh_from_needles(needles)

  self._needles_stale = false
  self:emit_event('needles_changed', { needles = needles })

  self:log('Regenerated ' .. #needles .. ' needles')
  return needles
end

function ScriptMatchWorkflow:needles_stale()
  return self._needles_stale
end

-- Initialize needle generator with current script materials (called by phases)
function ScriptMatchWorkflow:initialize_needle_generator()
  local script_materials = self:script_materials()

  -- Reinitialize the generator with current script materials
  self.needle_generator = NeedleGenerator.new {
    session_id = self.session_ui:session_id(),
    script_materials = script_materials,
    materials_service = self.script_materials_service
  }

  self:log('Initialized needle generator with ' .. #script_materials .. ' script materials')
end

-- Register a nudgeable (IntervalFunction) with optional stop check
function ScriptMatchWorkflow:register_nudgeable(interval_function, stop_check)
  local registration = {
    interval_function = interval_function,
    stop_check = stop_check or function() return false end,
  }

  table.insert(self.nudgeables, registration)
  self:log("Registered nudgeable (total: " .. #self.nudgeables .. ")")
end

-- React all registered nudgeables and clean up completed ones
function ScriptMatchWorkflow:nudgeables_react()
  local current_time = reaper.time_precise()
  local active_nudgeables = {}

  for _, registration in ipairs(self.nudgeables) do
    if not registration.stop_check() then
      -- Still active, react and keep
      registration.interval_function:react(current_time)
      table.insert(active_nudgeables, registration)
    else
      -- Completed, don't keep (auto-cleanup)
      self:log("Auto-cleaned up completed nudgeable")
    end
  end

  -- Update nudgeables list to only active ones
  self.nudgeables = active_nudgeables
end

-- Event System Methods for Component Communication

function ScriptMatchWorkflow:listen_for_event(event_name, callback)
  self.events:listen(event_name, callback)
  self:log(string.format("Added listener for event: %s (%d total)",
    event_name, self.events:listener_count(event_name)))
end

function ScriptMatchWorkflow:emit_event(event_name, event_data)
  self:log(string.format("Emitting event: %s to %d listeners",
    event_name, self.events:listener_count(event_name)))
  self.events:emit(event_name, event_data)
end

function ScriptMatchWorkflow:remove_event_listener(event_name, callback_to_remove)
  self.events:remove_listener(event_name, callback_to_remove)
  self:log(string.format("Removed listener for event: %s (%d remaining)",
    event_name, self.events:listener_count(event_name)))
end