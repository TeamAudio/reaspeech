CurationSuggestionsUI = Polo {}

function CurationSuggestionsUI:init()
  Logging().init(self, 'CurationSuggestionsUI')

  assert(self.session_id, 'CurationSuggestionsUI: session_id is required')
  assert(self.workflow, 'CurationSuggestionsUI: workflow is required for event communication')

  -- Initialize SuggestionStateManager for persistence
  self.state_manager = self.workflow:get_suggestion_state_manager()

  -- Data Structure & State Management
  self.suggestions = {}          -- Received suggestions for current needle
  self.focused_index = 1         -- Currently focused suggestion (keyboard)
  self.current_needle_id = nil   -- Which needle's suggestions we're showing
  self.show_accepted = true      -- Visibility toggle for accepted suggestions
  self.show_rejected = false     -- Visibility toggle for rejected suggestions

  -- Job Status Tracking
  self.current_job_status = 'idle'     -- Current job status for this needle
  self.current_job_error = nil         -- Last error message if job failed

  -- Event-Driven Integration Pattern
  self:setup_event_listeners()

  -- Initialize keyboard navigation using KeyMap pattern
  self.key_bindings = self:init_key_bindings()

  self:log("Initialized CurationSuggestionsUI - Steps 9.1, 9.2, 9.3, 12.2 complete")
end

-- Event listener setup and management
function CurationSuggestionsUI:setup_event_listeners()
  -- Listen for new suggestions from CurationCardUI
  self.workflow:listen_for_event("suggestions_generated", function(event_data)
    self:log(string.format("Received suggestions_generated event: needle_id='%s', current_needle_id='%s', suggestions_count=%d",
      tostring(event_data.needle_id),
      tostring(self.current_needle_id),
      #(event_data.suggestions or {})))

    if event_data.needle_id == self.current_needle_id then
      self:update_suggestions(event_data.suggestions)
    else
      self:log("Needle ID mismatch - not updating suggestions")
    end
  end)

  -- Listen for needle navigation changes
  self.workflow:listen_for_event("needle_navigated", function(event_data)
    self:change_needle(event_data.needle_id)
  end)

  -- A jump (e.g. from an export file row) can name the suggestion to
  -- focus; applied now if its needle is already loaded, otherwise when
  -- the navigation's suggestions arrive
  self.workflow:listen_for_event("curation_jump_requested", function(event_data)
    self._pending_focus_suggestion_id = event_data.suggestion_id
    self:apply_pending_focus()
  end)

  -- Listen for job status changes from CurationCardUI
  self.workflow:listen_for_event("job_status_changed", function(event_data)
    self:log(string.format("Received job_status_changed event: needle_id='%s', status='%s'",
      tostring(event_data.needle_id), tostring(event_data.status)))

    if event_data.needle_id == self.current_needle_id then
      self:update_job_status(event_data.status, event_data.error_message)
    else
      self:log("Job status event needle ID mismatch - ignoring")
    end
  end)

  self:log("Event listeners configured for suggestions, navigation, and job status")
end

-- Update job status for current needle
function CurationSuggestionsUI:update_job_status(status, error_message)
  self.current_job_status = status or 'idle'
  self.current_job_error = error_message

  self:log(string.format("Updated job status: %s%s",
    self.current_job_status,
    error_message and string.format(" - Error: %s", error_message) or ""))
end

function CurationSuggestionsUI:update_suggestions(suggestions)
  -- The suggestions_generated event carries the needle's full merged
  -- suggestion list (decided + fresh), so replace rather than append
  self.suggestions = suggestions or {}
  self._scrolled_to_focus = nil

  -- Validate and reset focus when suggestions change
  if #self.suggestions > 0 then
    self.focused_index = self:find_first_pending_suggestion() or 1
  else
    self.focused_index = 1  -- Default for when no suggestions exist yet
  end

  -- A jump (e.g. from an export row) may have named the suggestion to
  -- land on; it wins over the default once, hit or miss
  self:apply_pending_focus()
  self._pending_focus_suggestion_id = nil

  self:log(string.format("Updated suggestions for needle %s, total: %d, focused_index=%d",
    self.current_needle_id or "unknown", #self.suggestions, self.focused_index))
end

function CurationSuggestionsUI:apply_pending_focus()
  if not self._pending_focus_suggestion_id or not self.suggestions then return end

  for i, suggestion in ipairs(self.suggestions) do
    if suggestion.guid == self._pending_focus_suggestion_id then
      self.focused_index = i
      self._pending_focus_suggestion_id = nil
      self._scrolled_to_focus = nil
      return
    end
  end
end

function CurationSuggestionsUI:change_needle(needle_id)
  if needle_id ~= self.current_needle_id then
    self.current_needle_id = needle_id
    self._scrolled_to_focus = nil

    -- Load existing suggestions for this needle
    if needle_id and self.state_manager then
      local loaded_suggestions = self.state_manager:load_needle_suggestions(needle_id)
      self.suggestions = loaded_suggestions or {}
      self:log(string.format("Loaded %d existing suggestions for needle: %s", #self.suggestions, needle_id))
    else
      self.suggestions = {}  -- Clear suggestions if no needle or state manager
    end

    self.focused_index = 1

    -- Reset job status when changing needles
    self.current_job_status = 'idle'
    self.current_job_error = nil

    -- Validate and reset focus when suggestions change
    if #self.suggestions > 0 then
      self.focused_index = self:find_first_pending_suggestion() or 1
    else
      self.focused_index = 1  -- Default for when no suggestions exist yet
    end

    self:log(string.format("Changed to needle: %s, total suggestions: %d", needle_id or "none", #self.suggestions))
  end
end

-- Helper method to validate and adjust focus when visibility filters change
function CurationSuggestionsUI:validate_focus_after_filter_change()
  if not self.suggestions or #self.suggestions == 0 then
    return
  end

  -- Check if currently focused suggestion is still visible
  local current_suggestion = self.suggestions[self.focused_index]
  if current_suggestion and self:should_show_suggestion(current_suggestion) then
    -- Current focus is still valid
    self:log("Focus remains valid after filter change: index " .. self.focused_index)
    return
  end

  -- Current focus is not visible, find a new valid focus
  -- First try to find a pending visible suggestion
  local new_focus = self:find_first_pending_suggestion()
  if new_focus and new_focus ~= self.focused_index then
    self.focused_index = new_focus
    self:log("Adjusted focus after filter change to first pending visible: index " .. self.focused_index)
    return
  end

  -- If no pending, just find first visible
  for i = 1, #self.suggestions do
    if self:should_show_suggestion(self.suggestions[i]) then
      self.focused_index = i
      self:log("Adjusted focus after filter change to first visible: index " .. self.focused_index)
      return
    end
  end

  -- No visible suggestions (edge case)
  self:log("Warning: No visible suggestions after filter change")
end

function CurationSuggestionsUI:find_first_pending_suggestion()
  for i, suggestion in ipairs(self.suggestions) do
    -- Check both pending state AND visibility filter
    if (suggestion.state == 'pending' or not suggestion.state) and self:should_show_suggestion(suggestion) then
      return i
    end
  end

  -- If no pending visible suggestions, find any visible suggestion
  for i, suggestion in ipairs(self.suggestions) do
    if self:should_show_suggestion(suggestion) then
      return i
    end
  end

  -- Fallback to 1 if no visible suggestions (graceful degradation)
  return 1
end

function CurationSuggestionsUI:render(panel_width)
  -- Handle keyboard navigation input
  self:handle_keyboard_input()

  -- Show job status if active (takes priority over empty state)
  if self.current_job_status == 'pending' or self.current_job_status == 'running' then
    self:render_job_loading_state()
    return
  end

  -- Show error state if job failed
  if self.current_job_status == 'error' then
    self:render_job_error_state()
    return
  end

  -- Replace debug render with actual suggestion display logic
  if not self.suggestions or #self.suggestions == 0 then
    self:render_empty_state()
    return
  end

  self:render_summary_header()
  self:render_suggestion_list(panel_width)
end

-- Loading state for active job
function CurationSuggestionsUI:render_job_loading_state()
  -- Center the loading text
  EmojiText.render(":hourglass: Generating suggestions...")
  ImGui.TextWrapped(Ctx(), "Please wait while suggestions are being generated for the current needle.")
end

-- Error state for failed job
function CurationSuggestionsUI:render_job_error_state()
  ImGui.Text(Ctx(), "Generation failed")
  local error_text = self.current_job_error or "An unknown error occurred during suggestion generation."
  ImGui.TextWrapped(Ctx(), error_text)
  ImGui.Spacing(Ctx())
  ImGui.TextWrapped(Ctx(), "Please try generating suggestions again or check the logs for more details.")
end

-- Empty state for no suggestions
function CurationSuggestionsUI:render_empty_state()
  ImGui.Text(Ctx(), "No suggestions")
  ImGui.TextWrapped(Ctx(), "Generate suggestions using the controls in the curation card.")
end

-- Summary header with stats and toggle links
function CurationSuggestionsUI:render_summary_header()
  local stats = self:calculate_suggestion_stats()
  ImGui.Text(Ctx(), string.format("%d suggestions (%d accepted, %d rejected)",
    stats.total, stats.accepted, stats.rejected))

  -- Toggle links for visibility control
  ImGui.SameLine(Ctx())

  local accepted_link_color = self.show_accepted and 0xddddddff or 0x888888ff
  Widgets.link("Show Accepted", function()
    self.show_accepted = not self.show_accepted
    self:validate_focus_after_filter_change()
  end, accepted_link_color, accepted_link_color)

  ImGui.SameLine(Ctx())

  local rejected_link_color = self.show_rejected and 0xddddddff or 0x888888ff
  Widgets.link("Show Rejected", function()
    self.show_rejected = not self.show_rejected
    self:validate_focus_after_filter_change()
  end, rejected_link_color, rejected_link_color)

end

-- Suggestion list with visibility filtering
function CurationSuggestionsUI:render_suggestion_list(panel_width)
  -- Negative height reserves a line under the list for the key legend
  local legend_height = ImGui.GetTextLineHeightWithSpacing(Ctx()) + 2

  if ImGui.BeginChild(Ctx(), "suggestions_scroll", panel_width, -legend_height, ImGui.ChildFlags_None()) then
    Trap(function()
      for i, suggestion in ipairs(self.suggestions) do
        if self:should_show_suggestion(suggestion) then
          self:render_suggestion_card(suggestion, i, panel_width)
        end
      end
    end)
    ImGui.EndChild(Ctx())
  end

  ImGui.TextDisabled(Ctx(), "Up/Down select  \xC2\xB7  Left/Right nudge  \xC2\xB7  Shift+L/R narrow/widen")
end

-- Calculate suggestion statistics helper
function CurationSuggestionsUI:calculate_suggestion_stats()
  local stats = { total = #self.suggestions, accepted = 0, rejected = 0, pending = 0 }

  for _, suggestion in ipairs(self.suggestions) do
    if suggestion.state == 'accepted' then
      stats.accepted = stats.accepted + 1
    elseif suggestion.state == 'rejected' then
      stats.rejected = stats.rejected + 1
    else
      stats.pending = stats.pending + 1
    end
  end

  return stats
end

-- Visibility filter method
function CurationSuggestionsUI:should_show_suggestion(suggestion)
  if suggestion.state == 'accepted' and not self.show_accepted then
    return false
  end
  if suggestion.state == 'rejected' and not self.show_rejected then
    return false
  end
  return true
end

-- Individual suggestion card rendering with focus-based height adjustment
function CurationSuggestionsUI:render_suggestion_card(suggestion, index, panel_width)
  local is_focused = (index == self.focused_index)

  -- Generate unique ID for ImGui child window
  local suggestion_id = suggestion.guid or suggestion.id or tostring(index)
  local child_id = "suggestion_" .. suggestion_id

  -- Focus and state express through separate channels: the border
  -- (and its width) belongs to keyboard focus, the background tint to
  -- the editorial state - so a focused accepted card reads as BOTH
  -- focused and accepted (state used to vanish under the focus blue)
  local border_color = self:get_border_color_for_suggestion(suggestion, is_focused)
  local state_color = self:get_state_color_for_suggestion(suggestion)
  local background_alpha = self:get_background_alpha_for_suggestion(suggestion)

  ImGui.PushStyleColor(Ctx(), ImGui.Col_Border(), border_color)
  ImGui.PushStyleColor(Ctx(), ImGui.Col_ChildBg(), (state_color & 0xFFFFFF00) | math.floor(background_alpha * 255))
  ImGui.PushStyleVar(Ctx(), ImGui.StyleVar_ChildBorderSize(), is_focused and 2.0 or 1.0)

  Trap(function()
    -- Auto-size to content: long matched lines wrap to several rows,
    -- and any fixed height either wastes space or grows a per-card
    -- scrollbar (and clips the focused card's controls). Progressive
    -- disclosure still works - the focused card grows because its
    -- controls render.
    if ImGui.BeginChild(Ctx(), child_id, panel_width - 10, 0, ImGui.ChildFlags_Borders() | ImGui.ChildFlags_AutoResizeY(), ImGui.WindowFlags_None()) then
      Trap(function()
        self:render_confidence_text(suggestion)
        self:render_timecode_text(suggestion)

        -- Matching text with proper wrapping (kept inline as it's simple)
        local matching_text = suggestion.matching_text or "Unknown"
        ImGui.TextWrapped(Ctx(), string.format('"%s"', matching_text))

        self:render_suggestion_state_indicator(suggestion)

        -- Progressive disclosure: waveform and controls only when focused
        if is_focused then
          self:render_waveform_strip(suggestion, panel_width - 30)
          self:render_suggestion_controls(suggestion)
        end
      end)

      ImGui.EndChild(Ctx())
    end
  end)

  -- Clean up applied styling
  ImGui.PopStyleVar(Ctx())  -- ChildBorderSize
  ImGui.PopStyleColor(Ctx(), 2)  -- Border and ChildBg colors

  -- Keyboard focus (arrows/Home/End/auto-advance) can land outside the
  -- visible scroll region; bring the card into view when focus changes
  if is_focused and self._scrolled_to_focus ~= index then
    ImGui.SetScrollHereY(Ctx(), 0.5)
    self._scrolled_to_focus = index
  end
end

-- Styling helpers for workflow-appropriate visual states
function CurationSuggestionsUI:get_border_color_for_suggestion(suggestion, is_focused)
  if is_focused then
    -- Bright blue for keyboard focus - highest priority visual state
    return 0x4A90E2FF
  end

  return self:get_state_color_for_suggestion(suggestion)
end

function CurationSuggestionsUI:get_state_color_for_suggestion(suggestion)
  if suggestion.state == 'accepted' then
    return 0x7ED321FF  -- Green - positive action
  elseif suggestion.state == 'rejected' then
    return 0xD0021BFF  -- Red - negative action
  else
    return 0x9B9B9BFF  -- Medium gray - pending
  end
end

function CurationSuggestionsUI:get_background_alpha_for_suggestion(suggestion)
  -- Subtle background opacity changes for editorial states
  if suggestion.state == 'rejected' then
    -- Lower opacity for rejected suggestions - visually recede
    return 0.3
  elseif suggestion.state == 'accepted' then
    -- Slightly elevated opacity for accepted suggestions
    return 0.8
  else
    -- Normal opacity for pending suggestions
    return 0.6
  end
end

-- Helper methods for suggestion card content rendering

function CurationSuggestionsUI:render_confidence_text(suggestion)
  local confidence_text = string.format("Confidence: %d%%", math.floor((suggestion.confidence or 0) * 100))

  -- Long shots wear the dice: the rescue tier found this below the
  -- normal floor, offered because a weak lead beats silent zero
  if suggestion.long_shot then
    EmojiText.render(':dice: Long shot - ' .. confidence_text)
    return
  end

  ImGui.Text(Ctx(), confidence_text)
end

function CurationSuggestionsUI:render_timecode_text(suggestion)
  if suggestion.start_time and suggestion.end_time then
    ImGui.SameLine(Ctx())
    local duration = suggestion.end_time - suggestion.start_time
    local timecode_text = string.format(":pin: %s - %s (%.1fs)",
      self:format_timecode(suggestion.start_time),
      self:format_timecode(suggestion.end_time),
      duration)
    EmojiText.render(timecode_text)
  end
end

-- Format a timecode S.ms into [HH:[MM:]]SS[.ms], ignoring unnecessary units
function CurationSuggestionsUI:format_timecode(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local seconds_remainder = seconds % 60

  -- Build formatted timecode string
  local timecode_parts = {}

  if hours > 0 then
    table.insert(timecode_parts, string.format("%02d:", hours))
  end

  if minutes > 0 or hours > 0 then
    table.insert(timecode_parts, string.format("%02d:", minutes))
  end

  table.insert(timecode_parts, string.format("%.2f", seconds_remainder))

  return table.concat(timecode_parts)
end

-- Icon + near-white text: the card background already carries the
-- state color, so dark colored text (the old treatment) just sank
-- into it
function CurationSuggestionsUI:render_suggestion_state_indicator(suggestion)
  if suggestion.state == 'accepted' then
    EmojiText.render(":accepted: Accepted", 0xF0F0F0FF)
  elseif suggestion.state == 'rejected' then
    EmojiText.render(":rejected: Rejected", 0xF0F0F0FF)
  end
end

function CurationSuggestionsUI:render_suggestion_controls(suggestion)
  -- Progressive disclosure: horizontal button layout for editorial controls
  -- Only called when suggestion has keyboard focus

  ImGui.Spacing(Ctx())  -- Add some space before controls

  -- Buttons carry their key bindings like shortcut engravings on a
  -- physical device
  Widgets.no_nav(function()
    if ImGui.Button(Ctx(), "Accept (Enter)") then
      self:accept_suggestion(suggestion)
    end

    ImGui.SameLine(Ctx())

    if ImGui.Button(Ctx(), "Reject (X)") then
      self:reject_suggestion(suggestion)
    end

    ImGui.SameLine(Ctx())

    -- Preview button (toggles while this suggestion is playing)
    local preview = self.workflow:get_audio_preview()
    local preview_label = preview:is_active(suggestion) and 'Stop (Space)##preview' or 'Preview (Space)##preview'
    if ImGui.Button(Ctx(), preview_label) then
      self:preview_suggestion(suggestion)
    end
  end)
end

-- Editorial decision: persist through the shared state manager (single
-- write to the needle's suggestion store), then mirror the result onto
-- the in-memory record
function CurationSuggestionsUI:decide_suggestion(suggestion, action)
  if not suggestion or not self.current_needle_id then
    self:log("ERROR: Cannot decide suggestion - missing suggestion or needle_id")
    return false
  end

  local success, updated = pcall(function()
    return self.state_manager:record_decision(self.current_needle_id, suggestion.guid, action)
  end)

  if not success then
    self:log("ERROR: Failed to persist decision: " .. tostring(updated))
    return false
  end

  if not updated then
    self:log("ERROR: Suggestion not found in store: " .. tostring(suggestion.guid))
    return false
  end

  suggestion.state = updated.state
  suggestion.editorial_log = updated.editorial_log
  suggestion.last_modified = updated.last_modified

  -- Auto-advance to next pending suggestion
  self:auto_advance_after_decision()

  -- Emit suggestion_decided event for cross-panel coordination
  self:emit_suggestion_decided_event(self.current_needle_id, suggestion.guid, action)

  self:log(string.format("Recorded %s for suggestion: %s", action, suggestion.guid))
  return true
end

function CurationSuggestionsUI:accept_suggestion(suggestion)
  return self:decide_suggestion(suggestion, 'accepted')
end

function CurationSuggestionsUI:reject_suggestion(suggestion)
  return self:decide_suggestion(suggestion, 'rejected')
end

function CurationSuggestionsUI:preview_suggestion(suggestion)
  self:log("Preview suggestion: " .. (suggestion.guid or suggestion.id or "unknown"))

  local preview = self.workflow:get_audio_preview()

  if preview:is_active(suggestion) then
    preview:stop()
  elseif not preview:play(suggestion) then
    self:log("Unable to preview suggestion - no matching media found on its track")
  end
end

function CurationSuggestionsUI:auto_advance_after_decision()
  -- Find next pending suggestion after current focus
  local next_pending_index = self:find_next_pending_suggestion_after(self.focused_index)

  if next_pending_index then
    -- Move focus to next pending suggestion
    self.focused_index = next_pending_index
    self:log("Auto-advanced to suggestion " .. next_pending_index)
  else
    -- No more pending suggestions - special "all done" state
    self:log("All suggestions have been decided - reached end")
    -- TODO: Implement "all done" state indicator (future feature for regeneration options)
  end
end

function CurationSuggestionsUI:find_next_pending_suggestion_after(start_index)
  -- Search from start_index+1 to end, then wrap to beginning
  local suggestions_count = #self.suggestions

  if suggestions_count == 0 then
    return nil
  end

  -- Search forward from start_index + 1
  for i = start_index + 1, suggestions_count do
    local suggestion = self.suggestions[i]
    if self:should_show_suggestion(suggestion) and ((suggestion.state or 'pending') == 'pending') then
      return i
    end
  end

  -- Wrap around: search from beginning to start_index
  for i = 1, start_index do
    local suggestion = self.suggestions[i]
    if self:should_show_suggestion(suggestion) and ((suggestion.state or 'pending') == 'pending') then
      return i
    end
  end

  -- No pending suggestions found
  return nil
end

-- Event Integration & Synchronization

function CurationSuggestionsUI:emit_suggestion_decided_event(needle_id, suggestion_id, action)
  if not needle_id or not suggestion_id or not action then
    self:log("ERROR: Cannot emit suggestion_decided event - missing required data")
    return
  end

  -- Calculate current summary for this needle
  local summary = self:get_cached_suggestion_summary()

  -- Emit the event following the established past-tense naming pattern
  self.workflow:emit_event("suggestion_decided", {
    needle_id = needle_id,
    suggestion_id = suggestion_id,
    action = action,
    summary = summary,
    timestamp = os.time()
  })

  self:log(string.format("Emitted suggestion_decided event: %s suggestion %s for needle %s (summary: %d total, %d accepted, %d rejected)",
    action, suggestion_id, needle_id, summary.total, summary.accepted, summary.rejected))
end

function CurationSuggestionsUI:get_cached_suggestion_summary()
  -- Calculate summary from current local state (fast, no file I/O)
  local summary = {
    total = #self.suggestions,
    accepted = 0,
    rejected = 0,
    pending = 0
  }

  for _, suggestion in ipairs(self.suggestions) do
    local state = suggestion.state or 'pending'
    if state == 'accepted' then
      summary.accepted = summary.accepted + 1
    elseif state == 'rejected' then
      summary.rejected = summary.rejected + 1
    else
      summary.pending = summary.pending + 1
    end
  end

  return summary
end

-- KEYBOARD NAVIGATION - Using KeyMap pattern for extensibility

function CurationSuggestionsUI:init_key_bindings()
  return KeyMap.new {
    -- Navigation: Arrow keys for moving between suggestions
    [ImGui.Key_UpArrow()] = function() self:navigate_to_previous_suggestion() end,
    [ImGui.Key_DownArrow()] = function() self:navigate_to_next_suggestion() end,

    -- Actions: Work on currently focused suggestion
    [ImGui.Key_Enter()] = function() self:accept_focused_suggestion() end,
    [ImGui.Key_X()] = function() self:reject_focused_suggestion() end,
    -- Delete = reject alias: it's what hands reach for
    [ImGui.Key_Delete()] = function() self:reject_focused_suggestion() end,
    [ImGui.Key_Space()] = function() self:preview_focused_suggestion() end,

    -- Extended navigation for future enhancement
    [ImGui.Key_Home()] = function() self:navigate_to_first_suggestion() end,
    [ImGui.Key_End()] = function() self:navigate_to_last_suggestion() end,

    -- Time controls: arrows nudge the focused window through the
    -- source; Shift+Right widens both edges, Shift+Left narrows
    [ImGui.Key_LeftArrow()] = function()
      if self:shift_down() then
        self:adjust_focused_suggestion_times(self.RESIZE_STEP, -self.RESIZE_STEP)
      else
        self:adjust_focused_suggestion_times(-self.NUDGE_STEP, -self.NUDGE_STEP)
      end
    end,
    [ImGui.Key_RightArrow()] = function()
      if self:shift_down() then
        self:adjust_focused_suggestion_times(-self.RESIZE_STEP, self.RESIZE_STEP)
      else
        self:adjust_focused_suggestion_times(self.NUDGE_STEP, self.NUDGE_STEP)
      end
    end,
  }
end

-- WAVEFORM STRIP

CurationSuggestionsUI.WAVEFORM = {
  HEIGHT = 40,
  CONTEXT_SECONDS = 0.35,
  MAX_COLUMNS = 400,
  MIN_COLUMNS = 64,
}

-- The focused suggestion's audio, read straight from the source WAV:
-- the suggestion window renders in accent pink over a dimmed context
-- margin on both sides, so nudging and resizing have something to
-- steer by. Cached single-slot: only the focused card draws this, and
-- the key changes exactly when the window (or panel width) does.
function CurationSuggestionsUI:render_waveform_strip(suggestion, width)
  if not suggestion.start_time or not suggestion.end_time then return end
  if width < 40 then return end

  local c = CurationSuggestionsUI.WAVEFORM
  local columns = math.floor(math.max(c.MIN_COLUMNS, math.min(c.MAX_COLUMNS, width)))
  local view_start = math.max(0, suggestion.start_time - c.CONTEXT_SECONDS)
  local view_end = suggestion.end_time + c.CONTEXT_SECONDS

  local key = table.concat({
    suggestion.guid or '?', view_start, view_end, columns
  }, ':')

  if self._waveform_key ~= key then
    self._waveform_key = key
    self._waveform_peaks = nil
    self._waveform_gain = 1

    local range = SuggestionTimeline.resolve(suggestion)
    if range and range.source_path and range.source_path ~= '' then
      -- Suggestion times are already source-file-relative
      self._waveform_peaks = WavFile.peaks(range.source_path, view_start, view_end, columns)
    end

    -- Normalize the view: VO peaks live way below full scale, and an
    -- un-scaled strip reads as a whisper (Mike: "quiet"). The loudest
    -- peak in view fills the strip; the gain cap keeps room tone from
    -- being amplified into a fake waveform.
    if self._waveform_peaks then
      local loudest = 0
      for _, pair in ipairs(self._waveform_peaks) do
        loudest = math.max(loudest, math.abs(pair[1]), math.abs(pair[2]))
      end
      if loudest > 0.005 then
        self._waveform_gain = math.min(1 / loudest, 24)
      end
    end
  end

  local peaks = self._waveform_peaks
  if not peaks or #peaks == 0 then return end -- unresolvable/non-WAV source: no strip

  ImGui.Spacing(Ctx())
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  ImGui.Dummy(Ctx(), width, c.HEIGHT)

  local dl = ImGui.GetWindowDrawList(Ctx())
  local mid_y = y + c.HEIGHT / 2
  local half = c.HEIGHT / 2 - 2
  local span = view_end - view_start
  local column_width = width / #peaks
  local gain = self._waveform_gain or 1

  local window_left = x + (suggestion.start_time - view_start) / span * width
  local window_right = x + (suggestion.end_time - view_start) / span * width

  -- The strip brings its own dark backing so it reads the same over
  -- any card tint (accepted-green washed the pink out entirely)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + c.HEIGHT,
    Theme.COLORS.very_dark_gray_semi_opaque, 3)

  local accent = Theme.COLORS.pink_opaque
  ImGui.DrawList_AddRectFilled(dl, window_left, y, window_right, y + c.HEIGHT,
    (accent & 0xFFFFFF00) | 0x2E)

  for i, pair in ipairs(peaks) do
    local px = x + (i - 1) * column_width
    local color = (px >= window_left and px <= window_right)
      and accent or Theme.COLORS.medium_gray_opaque

    local high = math.min(1, math.max(-1, pair[2] * gain))
    local low = math.min(1, math.max(-1, pair[1] * gain))
    local top = mid_y - high * half
    local bottom = mid_y - low * half
    if bottom - top < 1 then
      top, bottom = mid_y - 0.5, mid_y + 0.5
    end
    ImGui.DrawList_AddLine(dl, px, top, px, bottom, color, 1)
  end

  -- Window edges as full-height ticks: the things the keys move
  ImGui.DrawList_AddLine(dl, window_left, y, window_left, y + c.HEIGHT, accent, 1)
  ImGui.DrawList_AddLine(dl, window_right, y, window_right, y + c.HEIGHT, accent, 1)

  -- Playhead while this suggestion previews: a bright line riding the
  -- window as the transport plays through it
  local fraction = self.workflow:get_audio_preview():playhead_fraction(suggestion)
  if fraction then
    local playhead_x = window_left + (window_right - window_left) * fraction
    ImGui.DrawList_AddLine(dl, playhead_x, y, playhead_x, y + c.HEIGHT, 0xFFFFFFE6, 1)
  end
end

-- TIME CONTROLS

CurationSuggestionsUI.NUDGE_STEP = 0.05
CurationSuggestionsUI.RESIZE_STEP = 0.05
CurationSuggestionsUI.MIN_WINDOW_SECONDS = 0.1

function CurationSuggestionsUI:shift_down()
  return ImGui.IsKeyDown(Ctx(), ImGui.Key_LeftShift())
    or ImGui.IsKeyDown(Ctx(), ImGui.Key_RightShift())
end

-- Move the focused suggestion's window edges (deltas in seconds),
-- persist, and announce so export estimates track the new slice
function CurationSuggestionsUI:adjust_focused_suggestion_times(start_delta, end_delta)
  local suggestion = self.suggestions and self.suggestions[self.focused_index]
  if not suggestion or not suggestion.start_time or not suggestion.end_time then return end
  if not self.current_needle_id then return end

  local start_time = math.max(0, suggestion.start_time + start_delta)
  local end_time = suggestion.end_time + end_delta
  if end_time - start_time < self.MIN_WINDOW_SECONDS then return end

  local ok, updated = pcall(function()
    return self.state_manager:adjust_suggestion_times(
      self.current_needle_id, suggestion.guid, start_time, end_time)
  end)

  if not ok or not updated then
    self:log("ERROR: Failed to persist time adjustment: " .. tostring(updated))
    return
  end

  suggestion.start_time = updated.start_time
  suggestion.end_time = updated.end_time
  suggestion.time_adjusted = updated.time_adjusted
  suggestion.last_modified = updated.last_modified

  self.workflow:emit_event('suggestion_time_adjusted', {
    needle_id = self.current_needle_id,
    suggestion_id = suggestion.guid,
    start_time = suggestion.start_time,
    end_time = suggestion.end_time,
  })
end

function CurationSuggestionsUI:handle_keyboard_input()
  Widgets.set_keyboard_nav(false)

  -- An active item (e.g. a text input elsewhere in the session) owns the
  -- keyboard; arrows/Space/Enter must not act on suggestions meanwhile
  if ImGui.IsAnyItemActive(Ctx()) then
    return
  end

  if self.key_bindings then
    self.key_bindings:react()
  end
end

-- Navigation Methods

function CurationSuggestionsUI:navigate_to_previous_suggestion()
  if not self.suggestions or #self.suggestions == 0 then
    return
  end

  local current_index = self.focused_index or 1
  local search_index = current_index
  local attempts = 0

  -- Search backward for a visible suggestion
  repeat
    search_index = search_index > 1 and search_index - 1 or #self.suggestions
    attempts = attempts + 1

    -- If we've checked all suggestions and none are visible, stay where we are
    if attempts > #self.suggestions then
      self:log("Warning: No visible suggestions found during backward navigation")
      return
    end
  until self:should_show_suggestion(self.suggestions[search_index])

  self.focused_index = search_index
  self:log("Navigated to previous visible suggestion: index " .. self.focused_index)
end

function CurationSuggestionsUI:navigate_to_next_suggestion()
  if not self.suggestions or #self.suggestions == 0 then
    return
  end

  local current_index = self.focused_index or 1
  local search_index = current_index
  local attempts = 0

  -- Search forward for a visible suggestion
  repeat
    search_index = search_index < #self.suggestions and search_index + 1 or 1
    attempts = attempts + 1

    -- If we've checked all suggestions and none are visible, stay where we are
    if attempts > #self.suggestions then
      self:log("Warning: No visible suggestions found during forward navigation")
      return
    end
  until self:should_show_suggestion(self.suggestions[search_index])

  self.focused_index = search_index
  self:log("Navigated to next visible suggestion: index " .. self.focused_index)
end

function CurationSuggestionsUI:navigate_to_first_suggestion()
  if not self.suggestions or #self.suggestions == 0 then
    return
  end

  -- Find first visible suggestion
  for i = 1, #self.suggestions do
    if self:should_show_suggestion(self.suggestions[i]) then
      self.focused_index = i
      self:log("Navigated to first visible suggestion: index " .. self.focused_index)
      return
    end
  end

  -- No visible suggestions found
  self:log("Warning: No visible suggestions found for first navigation")
end

function CurationSuggestionsUI:navigate_to_last_suggestion()
  if not self.suggestions or #self.suggestions == 0 then
    return
  end

  -- Find last visible suggestion (search backward from end)
  for i = #self.suggestions, 1, -1 do
    if self:should_show_suggestion(self.suggestions[i]) then
      self.focused_index = i
      self:log("Navigated to last visible suggestion: index " .. self.focused_index)
      return
    end
  end

  -- No visible suggestions found
  self:log("Warning: No visible suggestions found for last navigation")
end

-- Action Methods - Work on currently focused suggestion

function CurationSuggestionsUI:accept_focused_suggestion()
  local focused_suggestion = self:get_focused_suggestion()
  if focused_suggestion then
    self:accept_suggestion(focused_suggestion)
  end
end

function CurationSuggestionsUI:reject_focused_suggestion()
  local focused_suggestion = self:get_focused_suggestion()
  if focused_suggestion then
    self:reject_suggestion(focused_suggestion)
  end
end

function CurationSuggestionsUI:preview_focused_suggestion()
  local focused_suggestion = self:get_focused_suggestion()
  if focused_suggestion then
    self:preview_suggestion(focused_suggestion)
  end
end

-- Helper Methods

function CurationSuggestionsUI:get_focused_suggestion()
  if not self.suggestions or #self.suggestions == 0 then
    return nil
  end

  local index = self.focused_index or 1
  if index < 1 or index > #self.suggestions then
    self:log("Warning: focused_index " .. index .. " out of bounds, resetting to 1")
    self.focused_index = 1
    index = 1
  end

  return self.suggestions[index]
end
