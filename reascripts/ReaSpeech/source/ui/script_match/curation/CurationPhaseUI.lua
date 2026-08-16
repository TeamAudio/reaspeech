CurationPhaseUI = Polo {}

function CurationPhaseUI:init()
  Logging().init(self, 'CurationPhaseUI')

  assert(self.session_ui, 'CurationPhaseUI: session_ui is required')
  assert(self.workflow, 'CurationPhaseUI: workflow is required')

  PhaseContainer.init(self, 'curation', 'Curation', 'headphone')

  -- Components persist for the session; needles reach them via the
  -- needles_changed event
  self:init_components()

  -- Registered AFTER the children, so by the time this fires their
  -- needles_changed handlers have already absorbed the fresh list and
  -- selection can re-sync against it
  self.workflow:listen_for_event('needles_changed', function()
    self:emit_initial_state()
  end)

  self:log("Initialized CurationPhaseUI")
end

function CurationPhaseUI:will_activate()
  if self.workflow:needles_stale() then
    -- needles_changed re-syncs selection when regeneration completes
    self.workflow:regenerate_needles()
  else
    self:emit_initial_state()
  end
end

function CurationPhaseUI:get_status_callback()
  -- 'initial' staleness (nothing generated this session) is expected;
  -- disk-derived progress counts are still the most useful thing to show
  if self.workflow:needles_stale() == 'setup_changed' then
    return {
      indicator = '!',
      hint = "setup changed",
    }
  end

  local status = self.workflow:get_session_status()

  if status.with_suggestions == 0 then
    return {
      hint = "no suggestions generated yet",
    }
  end

  local done = status.curated >= status.with_suggestions
  local hint = ('%d/%d curated'):format(status.curated, status.with_suggestions)
  if status.lines > 0 then
    hint = hint .. (', %d lines'):format(status.lines)
  end
  if (status.excluded or 0) > 0 then
    hint = hint .. (', %d excluded'):format(status.excluded)
  end

  return {
    indicator = done and '*' or 'o',
    hint = hint,
  }
end

-- Nav rail + workbench: the locked-in designer lives on the card and
-- suggestions, so they get the width; the nav list is peripheral.
-- The card auto-sizes as a banner; suggestions fill the rest.
CurationPhaseUI.NAV_RAIL_FRACTION = 0.28
CurationPhaseUI.NAV_RAIL_MIN_WIDTH = 240
CurationPhaseUI.RAIL_GAP = 12

function CurationPhaseUI:render_content_callback()
  self:render_stale_banner()

  local avail_w = ImGui.GetContentRegionAvail(Ctx())
  local nav_w = math.max(
    CurationPhaseUI.NAV_RAIL_MIN_WIDTH,
    math.floor(avail_w * CurationPhaseUI.NAV_RAIL_FRACTION))

  self:navigation_ui():render(nav_w)

  ImGui.SameLine(Ctx(), 0, CurationPhaseUI.RAIL_GAP)

  if ImGui.BeginChild(Ctx(), 'curation-workbench', 0, 0, ImGui.ChildFlags_None(), ImGui.WindowFlags_NoScrollbar()) then
    Trap(function()
      local workbench_w = ImGui.GetContentRegionAvail(Ctx())
      self:curation_card_ui():render(workbench_w)
      ImGui.Dummy(Ctx(), 0, 8)
      self:suggestions_ui():render(workbench_w)
    end)

    ImGui.EndChild(Ctx())
  end
end

-- Same-frame acknowledgment when setup changes while this phase is
-- already expanded; regeneration stays a deliberate action
function CurationPhaseUI:render_stale_banner()
  if not self.workflow:needles_stale() then
    return
  end

  EmojiText.render(":warning: Setup has changed - the needle list may be out of date.", 0xffcc66ff)
  ImGui.SameLine(Ctx())

  if ImGui.Button(Ctx(), "Refresh needles") then
    self.workflow:regenerate_needles()
  end
end

function CurationPhaseUI:navigation_ui()
  return self._navigation_ui
end

function CurationPhaseUI:curation_card_ui()
  return self._curation_card_ui
end

function CurationPhaseUI:suggestions_ui()
  return self._suggestions_ui
end

-- Initialize all child components in predictable order
function CurationPhaseUI:init_components()
  -- 1. Navigation UI (no dependencies)
  self._navigation_ui = CurationNavigationUI.new {
    session_id = self.session_ui:session_id(),
    curation_ui = self,
    workflow = self.workflow,
  }

  -- 2. Curation Card UI (depends on navigation for current needle index)
  self._curation_card_ui = CurationCardUI.new {
    session_id = self.session_ui:session_id(),
    curation_ui = self,
    current_needle_index = self._navigation_ui:current_needle_index(),
    workflow = self.workflow,
  }

  -- 3. Suggestions UI (no dependencies, just needs workflow for events)
  self._suggestions_ui = CurationSuggestionsUI.new {
    session_id = self.session_ui:session_id(),
    curation_ui = self,
    workflow = self.workflow,
  }

  self:log("Initialized all curation components in explicit order")
end

-- Emit initial state after all components and event listeners are ready
function CurationPhaseUI:emit_initial_state()
  -- All components are now initialized and listeners are registered
  -- Safe to emit the initial navigation state
  self._navigation_ui:emit_navigation_event()
  self:log("Emitted initial curation state")
end