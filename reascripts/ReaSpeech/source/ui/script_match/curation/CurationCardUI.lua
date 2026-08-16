CurationCardUI = Polo {}

function CurationCardUI:init()
  Logging().init(self, 'CurationCardUI')

  assert(self.session_id, 'CurationCardUI: session_id is required')
  assert(self.workflow, 'CurationCardUI: workflow is required')

  self.needles = self.needles or {}
  self.current_needle_index = self.current_needle_index or 1

  Fonts:register('needle_primary', 'sans-serif', 6, ImGui.FontFlags_Bold())
  Fonts:register('card_corner', 'sans-serif', -2)

  -- Callback-driven async job tracking (no polling in UI)
  self.active_suggestion_generator = nil
  self.current_status = 'idle'

  -- Enhanced job status tracking
  self.last_suggestion_count = 0  -- Count from last successful generation
  self.last_error_message = nil  -- Last error message for display

  -- Set up event listeners for navigation
  self:setup_navigation_event_listener()

  self:set_current_needle_index(self.current_needle_index)

  self:log("Initialized CurationCardUI")
end

-- Set up navigation event listener
function CurationCardUI:setup_navigation_event_listener()
  self.workflow:listen_for_event("needles_changed", function(event_data)
    self.needles = event_data.needles or {}
    self:set_current_needle_index(math.min(self.current_needle_index or 1, math.max(#self.needles, 1)))
  end)

  self.workflow:listen_for_event("needle_navigated", function(event_data)
    self:handle_needle_navigation(event_data.needle_index, event_data.needle_id, event_data.needle)
  end)

  -- Listen for suggestion decision events for cross-panel coordination
  self.workflow:listen_for_event("suggestion_decided", function(event_data)
    self:handle_suggestion_decided(event_data)
  end)

  self:log("Set up navigation and suggestion decision event listeners")
end

-- Handle navigation events from CurationNavigationUI
function CurationCardUI:handle_needle_navigation(needle_index, needle_id, _needle)
  self:log("Received needle_navigated event for needle_id: " .. needle_id .. " at index: " .. needle_index)
  self:set_current_needle_index(needle_index)
end

-- Handle suggestion decision events for cross-panel coordination
function CurationCardUI:handle_suggestion_decided(event_data)
  self:log(string.format("Received suggestion_decided event: %s suggestion %s for needle %s",
    event_data.action, event_data.suggestion_id, event_data.needle_id))

  -- Check if this event affects the current needle
  if event_data.needle_id == self:get_current_needle_id() then
    self:log("Suggestion decision affects current needle - triggering UI refresh")
    -- Note: No explicit action needed here since the CurationSuggestionsUI will update
    -- its local state and the UI will reflect changes on the next render cycle.
    -- This handler mainly exists for logging and potential future cross-panel features.
  end
end

-- Helper method to get current needle ID for event coordination
function CurationCardUI:get_current_needle_id()
  return self.current_needle and (self.current_needle.guid or self.current_needle.id or tostring(self.current_needle_index)) or "unknown"
end

function CurationCardUI:render(panel_width)
  -- No polling needed - purely callback-driven
  self:render_card(panel_width)
end

function CurationCardUI:set_current_needle_index(needle_index)
  self.current_needle_index = needle_index
  self.current_needle = self.needles[needle_index]

  -- Cancel any active suggestion generation when switching needles
  if self.active_suggestion_generator then
    self:log("Cancelling active suggestion generation due to needle change")
    self.active_suggestion_generator:cancel()
    self.active_suggestion_generator = nil
  end

  -- Job status belongs to the needle it ran for: reset on every needle
  -- change, or the last generation's ":check: N suggestions" follows
  -- the user to every card
  self.current_status = 'idle'
  self.last_suggestion_count = 0
  self.last_error_message = nil

  self:update_display_texts()
end

-- Update display texts (extracted for reuse)
function CurationCardUI:update_display_texts()
  if not self.current_needle then
    return
  end

  self.position_text = self:get_position_text()
  self.status_text = self:get_status_text()
  self.needle_content_text = '"' .. self.current_needle.content .. '"'
  self.navigation_path_text = self:format_navigation_path(self.current_needle.navigation)
  self.metadata_summary_text = self:format_metadata_summary(self.current_needle.metadata)
end

function CurationCardUI:render_card(panel_width)
  if not self.current_needle then
    return
  end

  -- Banner, not column: auto-size to content so the suggestions list
  -- below gets the remaining height
  if ImGui.BeginChild(Ctx(), 'curation-card', panel_width, 0, ImGui.ChildFlags_Borders() | ImGui.ChildFlags_AutoResizeY()) then
    Trap(function()
      self:render_top_row()
      self:render_needle_content()
      self:render_navigation_path(panel_width)
      self:render_metadata_summary(panel_width)
      self:render_diagnosis_line(panel_width)
      self:render_generate_suggestions_button()
      ImGui.Dummy(Ctx(), 0, 2)
    end)

    ImGui.EndChild(Ctx())
  end
end

CurationCardUI.DIAGNOSIS_COLORS = {
  unlinked_track = 0xE0B060FF,
  not_recorded = 0x999999FF,
  non_verbal = 0xB090E0FF,
}

-- The verdict for a rolled-but-empty line, right on the card: WHY it
-- found nothing (audio on an unlinked track, likely never recorded,
-- non-verbal direction). Colors match the nav badges.
function CurationCardUI:render_diagnosis_line(panel_width)
  local needle = self.current_needle
  if not needle or not needle.locator then return end

  local status = needle.guid and self.workflow:get_needle_status(needle.guid)
  if not status or status.total > 0 then return end

  local verdict = self.workflow:get_needle_diagnosis():get(needle.locator)
  if not verdict then return end

  local color = CurationCardUI.DIAGNOSIS_COLORS[verdict.class] or 0x999999FF
  ImGui.Dummy(Ctx(), 0, 2)
  ImGui.PushTextWrapPos(Ctx(), panel_width - 20)
  ImGui.TextColored(Ctx(), color, verdict.reason)
  ImGui.PopTextWrapPos(Ctx())

  if verdict.class == 'unlinked_track' and verdict.evidence then
    ImGui.SameLine(Ctx())
    ImGui.TextColored(Ctx(), 0x777777FF,
      (' (%.0f%%%s)'):format((verdict.evidence.confidence or 0) * 100,
        verdict.evidence.long_shot and ', long shot' or ''))

    -- The verdict names a project track: one press links it (with the
    -- evidence transcript) and re-rolls this line right here
    if verdict.evidence.track_name then
      ImGui.SameLine(Ctx(), 0, 10)
      Widgets.no_nav(function()
        if ImGui.SmallButton(Ctx(), ('Link %s & re-roll'):format(verdict.evidence.track_name)) then
          local ok, message = self.workflow:get_needle_diagnosis():link_evidence_track(verdict)
          self:log('Link & re-roll: ' .. tostring(message))
          if ok then
            self:start_suggestion_generation()
          end
        end
      end)
    end
  end
end

-- The element tile's caption line: no "Tags:" preamble (the layer
-- type is implementation vocabulary), just the pairs separated by
-- middle dots
function CurationCardUI:format_metadata_summary(metadata)
  if not metadata or #metadata == 0 then
    return ""
  end

  local parts = {}
  for _, item in ipairs(metadata) do
    table.insert(parts, item.tag .. ": " .. item.value)
  end

  return table.concat(parts, "  \xC2\xB7  ")
end

function CurationCardUI:format_navigation_path(navigation)
  if not navigation or #navigation == 0 then
    return ""
  end

  return table.concat(navigation, " > ")
end

function CurationCardUI:get_position_text()
  return string.format("%d/%d", self.current_needle_index, #self.needles)
end

function CurationCardUI:get_status_text()
  if self.current_status == 'pending' then
    return ":hourglass: Initializing..."
  elseif self.current_status == 'running' then
    return ":progress: Generating..."
  elseif self.current_status == 'completed' then
    local count = self.last_suggestion_count or 0
    return string.format(":check: %d suggestions", count)
  elseif self.current_status == 'error' then
    return ":error: " .. (self.last_error_message or "Error")
  elseif self.current_status == 'cancelled' then
    return ":stopped: Cancelled"
  end

  -- Default idle state
  return ":search: Ready"
end

function CurationCardUI:get_needle_content_text()
  return '"' .. self.current_needle.content .. '"'
end

function CurationCardUI:render_top_row()
  -- Position display on left
  Fonts.wrap(Ctx(), Fonts.card_corner, function()
    ImGui.Text(Ctx(), self.position_text)
  end)

  -- Corner affordance beside the position: copy the raw line text
  -- (sharing lines out of the app previously meant retyping them)
  if self.current_needle and self.current_needle.content then
    ImGui.SameLine(Ctx())
    local icon_size = Fonts.size:get() - 3
    if Widgets.icon(Icons.copy, '##copy_needle_line', icon_size, icon_size,
      'Copy line text', 0x888888FF, Theme.COLORS.pink_opaque) then
      ImGui.SetClipboardText(Ctx(), self.current_needle.content)
    end
  end

  -- Status on right. Icon slot sized to the DEFAULT font (measured
  -- before the corner-font wrap): corner text is deliberately small,
  -- but icons that small stop being legible
  ImGui.SameLine(Ctx())
  local icon_slot = ImGui.GetTextLineHeight(Ctx())
  local avail_width = ImGui.GetContentRegionAvail(Ctx())
  local status_width = EmojiText.calc_width(self.status_text, icon_slot)
  ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + avail_width - status_width)

  Fonts.wrap(Ctx(), Fonts.card_corner, function()
    EmojiText.render(self.status_text, nil, icon_slot)
  end)
end

function CurationCardUI:render_needle_content()
  ImGui.Spacing(Ctx())

  local content_text = self.needle_content_text
  local avail_width = ImGui.GetContentRegionAvail(Ctx())

  Fonts.wrap(Ctx(), Fonts.needle_primary, function()
    local text_width = ImGui.CalcTextSize(Ctx(), content_text)
    local center_x = (avail_width - text_width) / 2

    if center_x > 0 then
      ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + center_x)
    end

    ImGui.TextWrapped(Ctx(), content_text)
  end)

  ImGui.Spacing(Ctx())
end

-- Centered when it fits; wrapped (left-aligned) when it doesn't -
-- clipping mid-tag was the old behavior and it hid the interesting
-- half of long asset filenames
function CurationCardUI:render_centered_or_wrapped(text, panel_width)
  Fonts.wrap(Ctx(), Fonts.card_corner, function()
    local text_width = ImGui.CalcTextSize(Ctx(), text)
    local center_x = (panel_width - text_width) / 2

    if center_x > 0 then
      ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + center_x)
      ImGui.Text(Ctx(), text)
    else
      ImGui.TextWrapped(Ctx(), text)
    end
  end)
end

function CurationCardUI:render_navigation_path(panel_width)
  if self.navigation_path_text == "" then
    return
  end

  self:render_centered_or_wrapped(self.navigation_path_text, panel_width)
end

function CurationCardUI:render_metadata_summary(panel_width)
  if self.metadata_summary_text == "" then
    return
  end

  ImGui.Spacing(Ctx())
  self:render_centered_or_wrapped(self.metadata_summary_text, panel_width)
  ImGui.Spacing(Ctx())
end

function CurationCardUI:render_generate_suggestions_button()
  -- Enhanced button with cancellation support
  local is_job_active = self.current_status == 'pending' or self.current_status == 'running'

  if is_job_active then
    -- Show cancel button when job is active
    Widgets.no_nav(function()
      if ImGui.Button(Ctx(), "Cancel Generation") then
        self:cancel_suggestion_generation()
      end
    end)
    ImGui.SameLine(Ctx())
    ImGui.Text(Ctx(), "Press to cancel...")
  else
    -- Show generate button when idle; keyboard nav must not focus it, or
    -- Space (preview) would re-trigger generation
    Widgets.no_nav(function()
      if ImGui.Button(Ctx(), "Generate Suggestions") then
        self:start_suggestion_generation()
      end
    end)
  end
end

-- Cancel active suggestion generation
function CurationCardUI:cancel_suggestion_generation()
  if self.active_suggestion_generator then
    self:log("User requested cancellation of suggestion generation")
    self.active_suggestion_generator:cancel()
    self.active_suggestion_generator = nil
    self.current_status = 'cancelled'
    self:update_display_texts()

    -- Emit job status event
    self:emit_job_status_event('cancelled')
  end
end

-- Emit job status change events for workflow coordination
function CurationCardUI:emit_job_status_event(status, additional_data)
  local needle_id = self.current_needle and (self.current_needle.guid or self.current_needle.id or tostring(self.current_needle_index)) or "unknown"

  local event_data = {
    needle_id = needle_id,
    status = status,
    suggestion_count = self.last_suggestion_count,
    error_message = self.last_error_message
  }

  -- Add any additional data
  if additional_data then
    for key, value in pairs(additional_data) do
      event_data[key] = value
    end
  end

  self.workflow:emit_event("job_status_changed", event_data)
  self:log("Emitted job_status_changed event: " .. status .. " for needle_id: " .. needle_id)
end

-- Start async suggestion generation with callback-driven UI updates
function CurationCardUI:start_suggestion_generation()
  -- Cancel any existing job
  if self.active_suggestion_generator then
    self.active_suggestion_generator:cancel()
    self.active_suggestion_generator = nil
    self.current_status = 'idle'
  end

  -- Create new suggestion generator with callbacks
  self.active_suggestion_generator = SuggestionGenerator.new {
    session_id = self.session_id,
    needle = self.current_needle,
    workflow = self.workflow,

    -- Callback functions for workflow registration pattern
    on_status_change = function(status)
      self:on_status_change(status)
    end,

    on_completion = function(results)
      self:on_completion(results)
    end,

    on_error = function(error_message)
      self:on_error(error_message)
    end,
  }

  -- Start async generation
  local started = self.active_suggestion_generator:start_async_generation()
  if not started then
    self:log("Failed to start suggestion generation")
    self.active_suggestion_generator = nil
    self.current_status = 'error'
    self.last_error_message = "Failed to start generation"
    self:update_display_texts()
    -- Emit job status event for startup failure
    self:emit_job_status_event('error', { error_message = self.last_error_message })
    return
  end

  -- Emit job status event for startup
  self:emit_job_status_event('pending')
  self:log("Starting callback-driven suggestion generation for needle: " .. self.current_needle.content)
end

-- Enhanced callback for status changes with progress tracking
function CurationCardUI:on_status_change(status)
  self.current_status = status
  self:update_display_texts()
  self:log("Status changed to: " .. status)

  -- Emit job status event
  self:emit_job_status_event(status)
end

-- Enhanced callback for successful completion
function CurationCardUI:on_completion(results)
  self:log("Suggestion generation completed via callback")
  self:log("Generated suggestions: " .. dump(results))

  self.current_status = 'completed'
  self.last_suggestion_count = results and #results or 0
  self.active_suggestion_generator = nil
  self:update_display_texts()

  -- A card-generated roll that found something outdates any earlier
  -- diagnosis (the runner does the same for oneshot rolls)
  if results and #results > 0 and self.current_needle and self.current_needle.locator then
    self.workflow:get_needle_diagnosis():clear(self.current_needle.locator)
  end

  -- Emit job status event before suggestions event
  self:emit_job_status_event('completed', { suggestion_count = self.last_suggestion_count })

  -- Process and persist suggestions before emitting event
  if self.current_needle and results and #results > 0 then
    local needle_id = self.current_needle.guid or self.current_needle.id or tostring(self.current_needle_index)
    local processed_suggestions = self:process_and_persist_suggestions(needle_id, results)

    -- Step 9.3.1 - Emit suggestions_generated event for CurationSuggestionsUI
    self.workflow:emit_event("suggestions_generated", {
      needle_id = needle_id,
      suggestions = processed_suggestions
    })
    self:log("Emitted suggestions_generated event for needle_id: " .. needle_id .. " with " .. #processed_suggestions .. " processed suggestions")
  elseif self.current_needle then
    -- Handle empty results case
    local needle_id = self.current_needle.guid or self.current_needle.id or tostring(self.current_needle_index)
    self.workflow:emit_event("suggestions_generated", {
      needle_id = needle_id,
      suggestions = {}
    })
    self:log("Emitted suggestions_generated event for needle_id: " .. needle_id .. " with no suggestions")
  end
end

-- Enhanced callback for errors with detailed error handling
function CurationCardUI:on_error(error_message)
  self:log("Suggestion generation error via callback: " .. (error_message or "Unknown error"))

  self.current_status = 'error'
  self.current_progress = nil
  self.last_error_message = error_message or "Unknown error"
  self.active_suggestion_generator = nil
  self:update_display_texts()

  -- Emit job status event
  self:emit_job_status_event('error', { error_message = self.last_error_message })
end

-- Standardization + persistence live on the state manager (shared with
-- the oneshot batch); this wrapper adds the card's error tolerance
function CurationCardUI:process_and_persist_suggestions(needle_id, raw_suggestions)
  if not raw_suggestions or #raw_suggestions == 0 then
    return {}
  end

  local state_manager = self.workflow:get_suggestion_state_manager()

  local success, result = pcall(function()
    return state_manager:persist_generated(needle_id, raw_suggestions)
  end)

  if not success then
    self:log("ERROR: Failed to persist suggestions: " .. tostring(result))
    return {}
  end

  self:log("Persisted " .. #result .. " suggestions for needle: " .. needle_id)
  return result
end