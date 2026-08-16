--[[

ExportTemplateEditorUI.lua - Enhanced template editor with autocomplete and quick insert

Provides advanced template editing features:
- Autocomplete popup when typing ${
- Quick insert chips for common variables
- Live preview of generated filenames
- Template syntax validation with error display
- Recent templates dropdown (future enhancement)

]]--

ExportTemplateEditorUI = Polo {}

function ExportTemplateEditorUI:init()
  Logging().init(self, 'ExportTemplateEditorUI')

  assert(self.settings, 'ExportTemplateEditorUI: settings is required')
  assert(self.needle_metadata_service, 'ExportTemplateEditorUI: needle_metadata_service is required')

  -- Create template engine with metadata service instead of session_id
  self.template_engine = ExportTemplateEngine.new {
    needle_metadata_service = self.needle_metadata_service
  }

  -- Create enhanced text input widget
  self.template_input = Widgets.TextInput.new {
    state = self.settings.template,
    label = 'Output Template',
    help_text = 'Template for generating output filenames using ${variable:processor} syntax. '
      .. 'A quoted separator renders only when the variable has a value: ${"-":character}',
    on_change = function(value)
      self:on_template_changed(value)
    end,
    on_enter = function(value)
      self:on_template_changed(value)
    end,
  }

  -- Set up event listener for metadata changes (if workflow is available)
  if self.needle_metadata_service and self.needle_metadata_service.workflow then
    self.needle_metadata_service.workflow:listen_for_event('metadata_variables_changed', function(event_data)
      self:on_metadata_variables_changed(event_data)
    end)
  end

  -- Autocomplete state: set while the template contains an unclosed
  -- ${ block; nil otherwise
  self._autocomplete = nil

  -- Processor tokens act on the variable most recently inserted from
  -- the quick-insert panel; nil until the first variable click
  self._last_inserted_variable = nil
  self._input_active = false
  self._autocomplete_hovered = false

  -- True while the in-flight value holds an unclosed ${ block: the
  -- signal for "a replacement code is being typed right now"
  self._mid_block = false
  self._live_value = self.settings:get_template()

  -- Template validation state
  self.validation_errors = {}
  self.preview_filename = ''
  self.preview_segments = nil

  -- Initialize with current template
  self:validate_current_template()

  -- Callback for template changes (optional)
  self.on_template_change = self.on_template_change or function() end

  self:log("Initialized ExportTemplateEditorUI")
end

function ExportTemplateEditorUI:on_template_changed(value)
  -- While typing, the value has not been committed to settings yet, so
  -- validate and preview the passed value
  self._live_value = value
  self:validate_current_template(value)
  self:update_autocomplete(value)

  -- Nonsense-state filter: while a replacement code is mid-edit (an
  -- unclosed ${ block) or the value fails validation, the preview line
  -- and the tree downstream hold their last good render instead of
  -- flashing through half-formed filenames
  if self._mid_block or #self.validation_errors > 0 then return end

  self:update_preview(value)

  -- Call the optional template change callback with the live value
  if self.on_template_change then
    self.on_template_change(value)
  end
end

-- Handler for metadata variable changes - refreshes available variables and updates preview
function ExportTemplateEditorUI:on_metadata_variables_changed(_event_data)
  self:log('Received metadata variables changed event - refreshing template editor')

  -- Invalidate template engine cache to pick up new variables
  self.template_engine:invalidate_cache()

  -- Refresh template validation and preview with new metadata
  self:validate_current_template()
  self:update_preview()

  -- Clear autocomplete suggestions to force refresh with new variables
  self.autocomplete_suggestions = {}
end

function ExportTemplateEditorUI:validate_current_template(template)
  template = template or self.settings:get_template()
  self.validation_errors = self.template_engine:validate_template(template)
end

function ExportTemplateEditorUI:update_preview(template)
  template = template or self.settings:get_template()

  -- Real curated match data when available; the engine falls back to
  -- mock data otherwise. Substituted spans come back marked so the
  -- preview can color them apart from the template's literal text.
  local curated_matches = self:get_curated_matches_sample()
  self.preview_segments = self.template_engine:generate_preview_segments(template, curated_matches)

  local parts = {}
  for _, segment in ipairs(self.preview_segments) do
    table.insert(parts, segment.text)
  end
  self.preview_filename = table.concat(parts)
end

-- Get a sample of curated matches for preview purposes
function ExportTemplateEditorUI:get_curated_matches_sample()
  -- Use metadata service to get sample needle data for preview
  local sample_needles = self.needle_metadata_service:get_sample_needles_for_preview()

  if sample_needles and #sample_needles > 0 then
    self:log('Using ' .. #sample_needles .. ' sample needles for template preview')
    return sample_needles
  end

  self:log('No sample needles available for preview - using fallback mock data')
  return nil
end

function ExportTemplateEditorUI:insert_variable(variable)
  local current_template = self.settings:get_template()
  local insertion = ('${%s}'):format(variable)

  -- For now, append to end. In future, we could insert at cursor position
  local new_template = current_template .. insertion

  self._last_inserted_variable = variable

  self.settings:set_template(new_template)
  self.template_input:clear_edit_buffer()
  self:on_template_changed(new_template)

  self:log('Inserted variable: ' .. insertion)
end

-- Find the last ${...} block for the given variable; returns start/end
-- indices or nil when the template has no block for it
function ExportTemplateEditorUI.find_variable_block(template, variable)
  local last_start, last_end
  local search_from = 1
  while true do
    local s, e, inner = template:find('%${([^}]*)}', search_from)
    if not s then break end
    if inner:match('^([^:]*)') == variable then
      last_start, last_end = s, e
    end
    search_from = e + 1
  end
  return last_start, last_end
end

-- Apply a processor to the variable most recently inserted from the
-- quick-insert panel, replacing any processor already on its block.
-- No-op when no panel-inserted variable is live in the template.
function ExportTemplateEditorUI:apply_processor(processor)
  local variable = self._last_inserted_variable
  if not variable then return end

  local current_template = self.settings:get_template()
  local block_start, block_end = self.find_variable_block(current_template, variable)
  if not block_start then return end

  local new_template = current_template:sub(1, block_start - 1)
    .. ('${%s:%s}'):format(variable, processor)
    .. current_template:sub(block_end + 1)

  self.settings:set_template(new_template)
  self.template_input:clear_edit_buffer()
  self:on_template_changed(new_template)

  self:log('Applied processor: ' .. processor .. ' to ' .. variable)
end

function ExportTemplateEditorUI:render_template_input(width)
  ImGui.PushItemWidth(Ctx(), width - 20)
  Trap(function()
    self.template_input:render()
  end)
  ImGui.PopItemWidth(Ctx())
  self._input_active = ImGui.IsItemActive(Ctx())
  -- Enter deactivates the input on the same frame the completion
  -- should apply; the popup needs to see that frame
  self._input_deactivated = ImGui.IsItemDeactivated(Ctx())

  -- The autocomplete overlay anchors to the input's on-screen rect
  local min_x, min_y = ImGui.GetItemRectMin(Ctx())
  local max_x, max_y = ImGui.GetItemRectMax(Ctx())
  self._input_rect = { min_x = min_x, min_y = min_y, max_x = max_x, max_y = max_y }
end

-- Inspect an in-flight template value for an unclosed ${ block and build
-- the narrowing suggestion list: variables inside ${, processors after :
function ExportTemplateEditorUI:update_autocomplete(value)
  self._autocomplete = nil
  self._mid_block = false
  if not value or value == '' then return end

  -- Find the last ${ in the value
  local open_start, search_from = nil, 1
  while true do
    local found = value:find('${', search_from, true)
    if not found then break end
    open_start = found
    search_from = found + 2
  end
  if not open_start then return end
  if value:find('}', open_start + 2, true) then return end -- block closed

  -- An unclosed block means a replacement code is mid-edit, whether or
  -- not it yields suggestions below
  self._mid_block = true

  local partial = value:sub(open_start + 2)
  if partial:find('%s') then return end -- not variable-shaped

  -- A quoted conditional prefix ('"-":') rides ahead of the variable;
  -- carry it through completions untouched
  local conditional_prefix = ''
  local quoted, after_quote = partial:match('^("[^"]*":)(.*)$')
  if quoted then
    conditional_prefix = quoted
    partial = after_quote
  end

  local variable_part, processor_part = partial:match('^([^:]*):(.*)$')

  local prefix, candidates
  if processor_part then
    prefix = value:sub(1, open_start + 1) .. conditional_prefix .. variable_part .. ':'
    candidates = {}
    for name in pairs(self.template_engine.processors) do
      table.insert(candidates, { name = name })
    end
    table.sort(candidates, function(a, b) return a.name < b.name end)
    partial = processor_part
  else
    prefix = value:sub(1, open_start + 1) .. conditional_prefix
    candidates = self.template_engine:get_available_variables_for_editor()
  end

  local matches = {}
  local needle = partial:lower()
  for _, candidate in ipairs(candidates) do
    if needle == '' or candidate.name:lower():sub(1, #needle) == needle then
      table.insert(matches, candidate)
      if #matches >= 12 then break end
    end
  end

  if #matches == 0 then return end

  -- Keyboard selection survives recomputes of the same in-flight
  -- value (the Enter-commit frame recomputes without changing it) and
  -- resets when typing changes the list
  if self._autocomplete_value ~= value then
    self._ac_selected = nil
  end
  self._autocomplete_value = value

  self._autocomplete = {
    prefix = prefix,
    matches = matches,
  }
end

-- Complete the unclosed block with the chosen name and close the brace
function ExportTemplateEditorUI:apply_autocomplete(name)
  local autocomplete = self._autocomplete
  if not autocomplete then return end

  local new_template = autocomplete.prefix .. name .. '}'

  self.settings:set_template(new_template)
  self.template_input:clear_edit_buffer()
  self._autocomplete = nil

  self:on_template_changed(new_template)
end

function ExportTemplateEditorUI:render_validation_errors(_width)
  -- Feedback, not punishment: while the input is active with a
  -- replacement code mid-edit (or momentarily cleared), the red text
  -- stays quiet - errors surface once the block closes or the edit ends
  if self._input_active and (self._mid_block or self._live_value == '') then return end

  if #self.validation_errors > 0 then
    ImGui.Spacing(Ctx())
    ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red text

    Trap(function()
      for _, error in ipairs(self.validation_errors) do
        ImGui.Text(Ctx(), "Error: " .. error)
      end
    end)

    ImGui.PopStyleColor(Ctx())
  end
end

-- Substituted values render in the accent color so what came from the
-- template's variables reads apart from its literal text
function ExportTemplateEditorUI:render_live_preview(_width)
  local segments = self.preview_segments
  if not segments or #segments == 0 then return end

  ImGui.Spacing(Ctx())
  ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), 0x888888FF) -- Gray text
  Trap(function()
    ImGui.Text(Ctx(), "Preview: ")
    for _, segment in ipairs(segments) do
      ImGui.SameLine(Ctx(), 0, 0)
      if segment.from_template then
        ImGui.TextColored(Ctx(), Theme.COLORS.pink_opaque, segment.text)
      else
        ImGui.Text(Ctx(), segment.text)
      end
    end
  end)
  ImGui.PopStyleColor(Ctx())
end

ExportTemplateEditorUI.TOKENS = {
  TOKEN_GAP = 14,
  ROW_GAP = 5,
  GUTTER_GAP = 14,
  HEADER_COLOR = 0x888888FF,
  DISABLED_COLOR = 0x5C5C5CFF,
  IDLE_ALPHA = 0xC4,
}

-- Display order + tooltips for the processor row; functions live in
-- ExportTemplateEngine:init_processors
ExportTemplateEditorUI.PROCESSORS = {
  { name = 'basename',  description = 'Strip directory and extension: takes/Take_01.wav -> Take_01' },
  { name = 'dirname',   description = 'Keep only the directory part of a path' },
  { name = 'lowercase', description = 'QUIET -> quiet' },
  { name = 'uppercase', description = 'quiet -> QUIET' },
  { name = 'padded',    description = 'Zero-pad a number: 3 -> 003' },
  { name = 'percent',   description = 'Fraction to percent: 0.94 -> 94pct' },
  { name = 'slugify',   description = 'Safe filename text: "Who, me?" -> who_me' },
  { name = 'timecode',  description = 'Seconds to timecode: 83.5 -> 01_23_5' },
}

-- Clickable-text insert menu: dim gutter headers on the left, accent
-- text tokens flowing and wrapping to their right. Variables append a
-- ${block}; processors attach to the last block in the template.
function ExportTemplateEditorUI:render_quick_insert_tokens(_width)
  ImGui.Spacing(Ctx())

  local variables_by_type = self.template_engine:get_variables_by_type()
  local template = self.settings:get_template()

  -- Processors act on the variable last inserted from this panel,
  -- as long as its block is still present in the template
  local target_variable = self._last_inserted_variable
  if target_variable and not self.find_variable_block(template, target_variable) then
    target_variable = nil
  end

  local groups = {}
  for _, group in ipairs({
    { label = 'System', variables = variables_by_type.system },
    { label = 'Session Data', variables = variables_by_type.dynamic },
  }) do
    if group.variables and #group.variables > 0 then
      local tokens = {}
      for _, variable in ipairs(group.variables) do
        table.insert(tokens, {
          id = 'var_' .. variable.name,
          text = variable.name,
          description = variable.description,
          on_click = function() self:insert_variable(variable.name) end,
        })
      end
      table.insert(groups, { label = group.label, tokens = tokens })
    end
  end

  local processor_tokens = {}
  for _, processor in ipairs(ExportTemplateEditorUI.PROCESSORS) do
    table.insert(processor_tokens, {
      id = 'proc_' .. processor.name,
      text = ':' .. processor.name,
      description = target_variable
        and ('%s\nApplies to ${%s}'):format(processor.description, target_variable)
        or nil,
      disabled = not target_variable,
      disabled_hint = 'Click a variable token first',
      on_click = function() self:apply_processor(processor.name) end,
    })
  end
  table.insert(groups, { label = 'Processors', tokens = processor_tokens })

  local c = ExportTemplateEditorUI.TOKENS
  local line_h = ImGui.GetTextLineHeight(Ctx())

  local header_w = 0
  for _, group in ipairs(groups) do
    header_w = math.max(header_w, (ImGui.CalcTextSize(Ctx(), group.label)))
  end
  local gutter_w = header_w + c.GUTTER_GAP

  local start_x = ImGui.GetCursorScreenPos(Ctx())
  local row_right = start_x + ImGui.GetContentRegionAvail(Ctx())
  local dl = ImGui.GetWindowDrawList(Ctx())

  for _, group in ipairs(groups) do
    local x0, y0 = ImGui.GetCursorScreenPos(Ctx())

    local label_w = ImGui.CalcTextSize(Ctx(), group.label)
    ImGui.DrawList_AddText(dl, x0 + header_w - label_w, y0, c.HEADER_COLOR, group.label)

    local pen_x, pen_y = x0 + gutter_w, y0
    for _, token in ipairs(group.tokens) do
      local token_w = ImGui.CalcTextSize(Ctx(), token.text)
      if pen_x > x0 + gutter_w and pen_x + token_w > row_right then
        pen_x = x0 + gutter_w
        pen_y = pen_y + line_h + c.ROW_GAP
      end
      ImGui.SetCursorScreenPos(Ctx(), pen_x, pen_y)
      self:render_insert_token(token, token_w, line_h)
      pen_x = pen_x + token_w + c.TOKEN_GAP
    end

    ImGui.SetCursorScreenPos(Ctx(), x0, pen_y + line_h + c.ROW_GAP)
  end
end

function ExportTemplateEditorUI:render_insert_token(token, token_w, line_h)
  local c = ExportTemplateEditorUI.TOKENS
  local x, y = ImGui.GetCursorScreenPos(Ctx())

  local clicked = ImGui.InvisibleButton(Ctx(), '##qi_' .. token.id, token_w, line_h)
  local hovered = ImGui.IsItemHovered(Ctx())
  local held = ImGui.IsItemActive(Ctx())
  local dl = ImGui.GetWindowDrawList(Ctx())

  if token.disabled then
    ImGui.DrawList_AddText(dl, x, y, c.DISABLED_COLOR, token.text)
    if token.disabled_hint then
      Widgets.tooltip(token.disabled_hint)
    end
    return
  end

  if hovered then
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end
  if token.description then
    Widgets.tooltip(token.description)
  end

  local color = hovered
    and Theme.COLORS.pink_opaque
    or (Theme.COLORS.pink_opaque & 0xFFFFFF00 | c.IDLE_ALPHA)
  local press = held and 1 or 0

  ImGui.DrawList_AddText(dl, x, y + press, color, token.text)
  if hovered then
    local underline_y = y + line_h + press
    ImGui.DrawList_AddLine(dl, x, underline_y, x + token_w, underline_y, color, 1)
  end

  if clicked and token.on_click then
    token.on_click()
  end
end

-- Narrowing suggestion list rendered directly beneath the input while an
-- unclosed ${ block is being typed. Click a row to complete it. Shown
-- while the input is active or the list itself is hovered (clicking a
-- row defocuses the input for a frame).
-- Keyboard driving for the suggestion list: arrows move the
-- selection, Enter applies it (no selection = Enter just commits the
-- text as typed), Escape dismisses. Returns the applied name, if any.
function ExportTemplateEditorUI:autocomplete_keyboard(matches)
  if self._input_active then
    if ImGui.IsKeyPressed(Ctx(), ImGui.Key_DownArrow()) then
      self._ac_selected = math.min((self._ac_selected or 0) + 1, #matches)
    elseif ImGui.IsKeyPressed(Ctx(), ImGui.Key_UpArrow()) then
      self._ac_selected = math.max((self._ac_selected or 2) - 1, 1)
    elseif ImGui.IsKeyPressed(Ctx(), ImGui.Key_Escape()) then
      self._autocomplete = nil
      return
    end
  end

  -- Enter lands on the frame the input deactivates
  if self._ac_selected and (self._input_active or self._input_deactivated)
    and (ImGui.IsKeyPressed(Ctx(), ImGui.Key_Enter())
      or ImGui.IsKeyPressed(Ctx(), ImGui.Key_KeypadEnter())) then
    return matches[self._ac_selected] and matches[self._ac_selected].name
  end
end

-- The suggestion list floats in an overlay window anchored under the
-- input, so it never pushes the controls below it down while typing.
-- NoFocusOnAppearing keeps keystrokes landing in the input; TopMost
-- keeps the overlay clickable above the main window.
function ExportTemplateEditorUI:render_autocomplete_popup(width)
  local autocomplete = self._autocomplete

  if not autocomplete
    or not (self._input_active or self._autocomplete_hovered or self._input_deactivated) then
    self._autocomplete_hovered = false
    return
  end

  local rect = self._input_rect
  if not rect then return end

  local overlay_w = math.max(rect.max_x - rect.min_x, math.min(width - 20, 200))
  ImGui.SetNextWindowPos(Ctx(), rect.min_x, rect.max_y + 2)
  ImGui.SetNextWindowSizeConstraints(Ctx(), overlay_w, 0, overlay_w, 10000)

  local flags = ImGui.WindowFlags_NoTitleBar()
    | ImGui.WindowFlags_NoResize()
    | ImGui.WindowFlags_NoMove()
    | ImGui.WindowFlags_AlwaysAutoResize()
    | ImGui.WindowFlags_NoSavedSettings()
    | ImGui.WindowFlags_NoFocusOnAppearing()
    | ImGui.WindowFlags_NoDocking()
    | ImGui.WindowFlags_NoNav()
    | ImGui.WindowFlags_TopMost()

  if ImGui.Begin(Ctx(), '##template_autocomplete', nil, flags) then
    Trap(function()
      local apply = self:autocomplete_keyboard(autocomplete.matches)

      for i, match in ipairs(autocomplete.matches) do
        local label = match.name
        if match.description then
          label = ('%s   (%s)'):format(match.name, match.description:sub(1, 50))
        end
        if ImGui.Selectable(Ctx(), label .. '##ac_' .. match.name, i == self._ac_selected) then
          apply = match.name
        end
      end

      ImGui.TextColored(Ctx(), 0x666666FF, '\xE2\x86\x91\xE2\x86\x93 select \xC2\xB7 Enter complete')

      self._autocomplete_hovered = ImGui.IsWindowHovered(Ctx())

      if apply then
        self:apply_autocomplete(apply)
      end
    end)
    ImGui.End(Ctx())
  end
end

function ExportTemplateEditorUI:render(width)
  Trap(function()
    self:render_template_input(width)
    self:render_autocomplete_popup(width)
    self:render_validation_errors(width)
    self:render_live_preview(width)
    self:render_quick_insert_tokens(width)
  end)
end
