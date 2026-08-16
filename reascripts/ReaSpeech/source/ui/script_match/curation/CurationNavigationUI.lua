CurationNavigationUI = Polo {}

function CurationNavigationUI:init()
  Logging().init(self, 'CurationNavigationUI')

  assert(self.session_id, 'CurationNavigationUI: session_id is required')
  assert(self.curation_ui, 'CurationNavigationUI: curation_ui is required')
  assert(self.workflow, 'CurationNavigationUI: workflow is required')

  self.needles = self.needles or {}
  self._current_needle_index = 1
  self._current_group_index = 1
  self._needle_row_spans = {}

  self.key_bindings = self:init_key_bindings()
  self.navigation_list = self:init_navigation_list()

  self.workflow:listen_for_event('needles_changed', function(event)
    self:set_needles(event.needles)
  end)

  self.workflow:listen_for_event('curation_jump_requested', function(event)
    self:navigate_to_needle_guid(event.needle_id)
  end)

  self:log("Initialized CurationNavigationUI")
end

-- Jump straight to a needle by guid (e.g. from an export file row)
function CurationNavigationUI:navigate_to_needle_guid(needle_guid)
  for index, needle in ipairs(self.needles) do
    if needle.guid == needle_guid then
      self._current_needle_index = index
      self:emit_navigation_event()
      return true
    end
  end

  self:log("Jump target needle not in list: " .. tostring(needle_guid))
  return false
end

-- Re-derive the navigation structure from a fresh needle list
function CurationNavigationUI:set_needles(needles)
  self.needles = needles or {}
  self.navigation_list = self:init_navigation_list()

  -- Recorded row geometry belongs to the old list
  self._needle_row_spans = {}

  if self._current_needle_index > #self.needles then
    self._current_needle_index = 1
  end

  -- List content changed under the scroll position; re-center on the
  -- selection next render
  self._scrolled_to_index = nil
end

function CurationNavigationUI:current_needle_index()
  return self._current_needle_index
end

function CurationNavigationUI:render(panel_width)
  self:handle_keyboard_input()

  -- Group the list + key legend into one layout item: the workbench
  -- SameLines after this render, and SameLine aligns to the LAST
  -- item's line - without the group that's the legend at the bottom
  -- of the rail
  ImGui.BeginGroup(Ctx())
  Trap(function()
    self:render_navigation_list(panel_width)
  end)
  ImGui.EndGroup(Ctx())
end

-- Using the flat list of needles, create a new flat list that inserts hierarchical structure
-- So for a list of needles like:
-- {
--   { content = "Needle 1", navigation = {"Group A"}, ... },
--   { content = "Needle 2", navigation = {"Group A"}, ... },
--   { content = "Needle 3", navigation = {"Group B"}, ... },
--   { content = "Needle 4", navigation = {"Group B", "Subgroup 1"}, ... },
-- }
-- The navigation tree-looking list would look like:
-- {
--   { name = "Group A", group_index = 1, level = 1 },
--   { name = "Needle 1", index = 1, level = 2 },
--   { name = "Needle 2", index = 2, level = 2 },
--   { name = "Group B", group_index = 2, level = 1 },
--   { name = "Needle 3", index = 3, level = 2 },
--   { name = "Subgroup 1", group_index = 3, root_group_index = 2level = 2 },
--   { name = "Needle 4", index = 4, level = 3 },
-- }
function CurationNavigationUI:init_navigation_list()
  local navigation_list = {}
  local group_counter = 0

  -- Build a hierarchical structure first
  local hierarchy = {}

  -- Process each needle and build the hierarchy
  for index, needle in ipairs(self.needles) do
    local navigation_path = needle.navigation or {"Ungrouped"}
    local current_level = hierarchy
    local root_group_index = nil

    -- Navigate/create the path in the hierarchy
    for level, path_part in ipairs(navigation_path) do
      local found = false
      for _, node in ipairs(current_level) do
        if node.name == path_part and node.type == "group" then
          current_level = node.children
          found = true
          -- Track the root group index (level 1 group)
          if level == 1 then
            root_group_index = node.group_index
          end
          break
        end
      end

      if not found then
        group_counter = group_counter + 1
        local new_group = {
          name = path_part,
          type = "group",
          group_index = group_counter,
          level = level,
          children = {}
        }

        -- Set root_group_index for subgroups (level > 1)
        if level > 1 and root_group_index then
          new_group.root_group_index = root_group_index
        elseif level == 1 then
          root_group_index = group_counter
        end

        table.insert(current_level, new_group)
        current_level = new_group.children
      end
    end

    -- Add the needle at the end of its navigation path
    table.insert(current_level, {
      name = needle.content,
      type = "needle",
      index = index,
      level = #navigation_path + 1,
      root_group_index = root_group_index
    })
  end

  -- Flatten the hierarchy into the expected structure
  local function flatten_hierarchy(nodes, result)
    for _, node in ipairs(nodes) do
      if node.type == "group" then
        -- Add the group node
        local group_entry = {
          name = node.name,
          group_index = node.group_index,
          level = node.level
        }
        -- Add root_group_index for subgroups
        if node.root_group_index then
          group_entry.root_group_index = node.root_group_index
        end
        table.insert(result, group_entry)

        -- Recursively add children
        flatten_hierarchy(node.children, result)
      elseif node.type == "needle" then
        -- Add the needle node
        local needle_entry = {
          name = node.name,
          index = node.index,
          level = node.level
        }
        -- Add root_group_index for needles
        if node.root_group_index then
          needle_entry.root_group_index = node.root_group_index
        end
        table.insert(result, needle_entry)
      end
    end
  end

  flatten_hierarchy(hierarchy, navigation_list)

  self:log("navigation_list: " .. dump(navigation_list))
  return navigation_list
end

CurationNavigationUI.ROW_PADDING_Y = 2
CurationNavigationUI.BADGE_GAP = 4
CurationNavigationUI.ACCENT_BAR_WIDTH = 3
CurationNavigationUI.TEXT_INSET = 6
-- Reserved right-edge room so wrapped text never sits under the
-- scrollbar
CurationNavigationUI.SCROLLBAR_ALLOWANCE = 18

-- Per-row geometry for a (possibly wrapped) needle row. Also used by
-- apply_pending_scroll, which must predict row heights before the
-- list renders.
function CurationNavigationUI:needle_row_metrics(node, panel_width)
  local line_h = ImGui.GetTextLineHeight(Ctx())
  local indent_spacing = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_IndentSpacing())
  local indent = (node.level - 1) * indent_spacing

  local badge_slot = line_h + CurationNavigationUI.BADGE_GAP
  local wrap_width = panel_width - indent - badge_slot
    - CurationNavigationUI.TEXT_INSET - CurationNavigationUI.SCROLLBAR_ALLOWANCE
  if wrap_width < 60 then wrap_width = 60 end

  local _, text_h = ImGui.CalcTextSize(Ctx(), node.name, nil, wrap_width)

  return {
    wrap_width = wrap_width,
    row_height = text_h + CurationNavigationUI.ROW_PADDING_Y * 2,
  }
end

-- Scroll so the selected needle sits mid-panel. Must run BEFORE
-- BeginChild via SetNextWindowScroll: scroll functions called inside a
-- window (SetScrollY/SetScrollHereY) only take effect on the FOLLOWING
-- frame, which briefly flashes the selection at its old position.
-- Rows wrap, so their heights vary. The render pass records each
-- row's actual content-space geometry (needle_row_spans); scrolling
-- against last frame's recording is exact by construction, where a
-- height *prediction* accumulates error across wrapped rows and the
-- selection drifts off-center. The predictor below remains only as a
-- fallback for the first frame after a rebuild, before any recording
-- exists.
function CurationNavigationUI:apply_pending_scroll(panel_width)
  if self._scrolled_to_index == self._current_needle_index then
    return
  end

  local span = self._needle_row_spans[self._current_needle_index]

  local target_y
  if span then
    target_y = span.y + span.h / 2
  else
    target_y = self:predict_target_y(panel_width)
  end

  if not target_y then
    return
  end

  local _, panel_height = ImGui.GetContentRegionAvail(Ctx())
  local scroll_y = target_y - panel_height / 2
  if scroll_y < 0 then scroll_y = 0 end

  ImGui.SetNextWindowScroll(Ctx(), -1, scroll_y)
  self._scrolled_to_index = self._current_needle_index
end

function CurationNavigationUI:predict_target_y(panel_width)
  local group_row_height = ImGui.GetTextLineHeightWithSpacing(Ctx())
  local _, spacing_y = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_ItemSpacing())

  local y = 0

  for _, node in ipairs(self.navigation_list) do
    local row_height
    if node.index then
      row_height = self:needle_row_metrics(node, panel_width).row_height + spacing_y
    else
      row_height = group_row_height
    end

    if node.index == self._current_needle_index then
      return y + row_height / 2
    end

    y = y + row_height
  end
end

CurationNavigationUI.NAME_CURATED_COLOR = 0x9FD9A0FF   -- soft green tint
CurationNavigationUI.NAME_UNMATCHED_COLOR = 0xE06060FF -- soft red: rolled, found nothing

-- Rolled-but-empty needles with a diagnosis wear its class instead of
-- the generic red: amber = the audio lives on an unlinked track
-- (actionable), dim gray = likely never recorded (excluded lane),
-- lavender = non-verbal direction (matching can't help yet)
CurationNavigationUI.DIAGNOSIS_BADGES = {
  unlinked_track = { 'warning', 0xE0B060FF },
  not_recorded = { 'stopped', 0x999999FF },
  non_verbal = { 'search', 0xB090E0FF },
}

-- Badge icon for a needle's curation state: check = curated, progress
-- = has suggestions, error = rolled but nothing found (name tints
-- red; a diagnosis refines icon + tint), none = untouched. Curated
-- names also tint green.
function CurationNavigationUI:needle_badge(node)
  local needle = self.needles[node.index]
  local status = needle and needle.guid and self.workflow:get_needle_status(needle.guid)

  if not status then
    return nil, nil
  end

  -- Rolled and found NOTHING: a red flag, not a quiet blank - this
  -- line needs a human. A diagnosis upgrades the flag to its WHY.
  if status.total == 0 then
    local verdict = needle.locator
      and self.workflow:get_needle_diagnosis():get(needle.locator)
    local badge = verdict and CurationNavigationUI.DIAGNOSIS_BADGES[verdict.class]
    if badge then
      return badge[1], badge[2]
    end
    return 'error', CurationNavigationUI.NAME_UNMATCHED_COLOR
  end

  if SessionStatus.is_curated(status) then
    return 'check', CurationNavigationUI.NAME_CURATED_COLOR
  end

  return 'progress', nil
end

-- Curated/total counts per needle-bearing group, keyed by group_index
function CurationNavigationUI:group_progress()
  local progress = {}
  local current = nil

  for _, node in ipairs(self.navigation_list) do
    if node.index then
      if current then
        current.total = current.total + 1

        local needle = self.needles[node.index]
        local status = needle and needle.guid and self.workflow:get_needle_status(needle.guid)
        if status and SessionStatus.is_curated(status) then
          current.curated = current.curated + 1
        end
      end
    elseif node.group_index then
      current = { total = 0, curated = 0 }
      progress[node.group_index] = current
    end
  end

  return progress
end

function CurationNavigationUI:render_navigation_list(panel_width)
  self:apply_pending_scroll(panel_width)

  local group_progress = self:group_progress()

  -- Negative height reserves a line under the list for the key legend
  local legend_height = ImGui.GetTextLineHeightWithSpacing(Ctx()) + 2

  if ImGui.BeginChild(Ctx(), 'navigation-list', panel_width, -legend_height, ImGui.WindowFlags_None()) then
    Trap(function()
      for _, node in ipairs(self.navigation_list) do
        if node.level > 1 then
          for _ = 1, node.level - 1 do
            ImGui.Indent(Ctx())
          end
        end

        if node.index then
          self:render_needle_row(node, panel_width)
        elseif node.group_index then
          local text_color = (self._current_group_index == node.group_index or node.root_group_index == self._current_group_index) and 0xffffffff or 0xbbbbbbff

          local label = node.name
          local progress = group_progress[node.group_index]
          if progress and progress.total > 0 then
            label = ('%s  [%d/%d]'):format(label, progress.curated, progress.total)
          end

          ImGui.TextColored(Ctx(), text_color, label)
        end

        if node.level > 1 then
          for _ = 1, node.level - 1 do
            ImGui.Unindent(Ctx())
          end
        end
      end
    end)

    ImGui.EndChild(Ctx())
  end

  ImGui.TextDisabled(Ctx(), "W/S line  \xC2\xB7  A/D group")

  -- Unmatched-lines report: one press copies every empty needle
  -- grouped by its diagnosis class, ready for a producer email
  local unmatched = self:unmatched_needles()
  if #unmatched > 0 then
    ImGui.SameLine(Ctx(), 0, 12)
    local size = Fonts.size:get() - 3
    if Widgets.icon(Icons.copy, '##copy-unmatched-report', size, size,
      ('Copy unmatched-lines report (%d)'):format(#unmatched),
      0x666666FF, Theme.COLORS.pink_opaque)
    then
      ImGui.SetClipboardText(Ctx(), self:unmatched_report(unmatched))
    end
  end
end

CurationNavigationUI.REPORT_TITLES = {
  { class = 'unlinked_track', title = 'Found on unlinked tracks' },
  { class = 'not_recorded', title = 'Likely never recorded' },
  { class = 'non_verbal', title = 'Non-verbal directions' },
  { class = 'undiagnosed', title = 'Unmatched, no diagnosis yet' },
}

function CurationNavigationUI:unmatched_needles()
  local unmatched = {}
  for _, needle in ipairs(self.needles) do
    local status = needle.guid and self.workflow:get_needle_status(needle.guid)
    if status and status.total == 0 then
      table.insert(unmatched, needle)
    end
  end
  return unmatched
end

function CurationNavigationUI:unmatched_report(unmatched)
  local groups = {}
  for _, needle in ipairs(unmatched) do
    local verdict = needle.locator and self.workflow:get_needle_diagnosis():get(needle.locator)
    local class = verdict and verdict.class or 'undiagnosed'

    local line = ('- "%s"'):format(needle.content or '')
    if verdict and verdict.class == 'unlinked_track' then
      line = line .. (' [%s]'):format(verdict.reason)
    end

    groups[class] = groups[class] or {}
    table.insert(groups[class], line)
  end

  local parts = { ('Unmatched lines (%d):'):format(#unmatched) }
  for _, entry in ipairs(CurationNavigationUI.REPORT_TITLES) do
    local lines = groups[entry.class]
    if lines and #lines > 0 then
      table.insert(parts, '')
      table.insert(parts, ('%s (%d):'):format(entry.title, #lines))
      for _, line in ipairs(lines) do
        table.insert(parts, line)
      end
    end
  end

  return table.concat(parts, '\n')
end

-- One clickable row per needle: status icon, wrapped line text, the
-- selection shown as a background bar with an accent edge (replacing
-- the old '>>' text decorator)
function CurationNavigationUI:render_needle_row(node, panel_width)
  local metrics = self:needle_row_metrics(node, panel_width)
  local selected = self._current_needle_index == node.index
  local badge_icon, name_tint = self:needle_badge(node)

  local row_width = math.max(ImGui.GetContentRegionAvail(Ctx()), 60)

  -- Content-space Y (scroll-independent), recorded for
  -- apply_pending_scroll's exact targeting
  local row_top = ImGui.GetCursorPosY(Ctx())

  -- The click target sizes from last frame's RECORDED height, exactly
  -- like the scroll math: predictions drift on wrapped rows, and a
  -- one-line button left every wrapped line unclickable. The predictor
  -- only serves a row's first frame.
  local recorded = self._needle_row_spans[node.index]
  local row_height = (recorded and recorded.h) or metrics.row_height

  ImGui.BeginGroup(Ctx())
  Trap(function()
    local x, y = ImGui.GetCursorScreenPos(Ctx())

    local clicked = ImGui.InvisibleButton(Ctx(), '##needle-row-' .. node.index, row_width, row_height)
    local hovered = ImGui.IsItemHovered(Ctx())

    if hovered then
      ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
    end

    local dl = ImGui.GetWindowDrawList(Ctx())
    if selected then
      ImGui.DrawList_AddRectFilled(dl, x, y, x + row_width, y + row_height, Theme.COLORS.dark_gray_opaque, 3)
      ImGui.DrawList_AddRectFilled(dl, x, y, x + CurationNavigationUI.ACCENT_BAR_WIDTH, y + row_height, Theme.COLORS.pink_opaque)
    elseif hovered then
      ImGui.DrawList_AddRectFilled(dl, x, y, x + row_width, y + row_height, Theme.COLORS.dark_gray_translucent, 3)
    end

    local line_h = ImGui.GetTextLineHeight(Ctx())
    ImGui.SetCursorScreenPos(Ctx(), x + CurationNavigationUI.TEXT_INSET, y + CurationNavigationUI.ROW_PADDING_Y)

    if badge_icon then
      EmojiText.icon(badge_icon)
    else
      ImGui.Dummy(Ctx(), line_h, line_h)
    end

    ImGui.SameLine(Ctx(), 0, CurationNavigationUI.BADGE_GAP)

    local text_color = selected and 0xffffffff or (name_tint or 0xbbbbbbff)
    ImGui.PushTextWrapPos(Ctx(), ImGui.GetCursorPosX(Ctx()) + metrics.wrap_width)
    ImGui.PushStyleColor(Ctx(), ImGui.Col_Text(), text_color)
    ImGui.Text(Ctx(), node.name)
    ImGui.PopStyleColor(Ctx())
    ImGui.PopTextWrapPos(Ctx())

    if clicked then
      self:navigate_to_needle_index(node.index)
    end
  end)
  ImGui.EndGroup(Ctx())

  local _, actual_height = ImGui.GetItemRectSize(Ctx())
  self._needle_row_spans[node.index] = { y = row_top, h = actual_height }
end

-- Click navigation: same path as the W/S key bindings, except the
-- clicked row is already in view - suppress the auto-centering scroll
function CurationNavigationUI:navigate_to_needle_index(index)
  if not self.needles[index] then
    return
  end

  self._current_needle_index = index
  self._scrolled_to_index = index
  self:emit_navigation_event()
end

function CurationNavigationUI:init_key_bindings()
  return KeyMap.new {
    [ImGui.Key_W()] = function() self:navigate_to_previous_needle() end,
    [ImGui.Key_A()] = function() self:navigate_to_previous_needle_group() end,
    [ImGui.Key_S()] = function() self:navigate_to_next_needle() end,
    [ImGui.Key_D()] = function() self:navigate_to_next_needle_group() end,
  }
end

function CurationNavigationUI:handle_keyboard_input()
  Widgets.set_keyboard_nav(false)

  -- An active item (e.g. a text input elsewhere in the session) owns the
  -- keyboard; arrows must not navigate needles meanwhile
  if ImGui.IsAnyItemActive(Ctx()) then
    return
  end

  self.key_bindings:react()
end

-- NAVIGATION

function CurationNavigationUI:navigate_to_previous_needle()
  local current_index = self._current_needle_index or 1
  self._current_needle_index = current_index > 1 and current_index - 1 or #self.needles
  self:emit_navigation_event()
  self:log("Navigated to previous needle: " .. self.needles[self._current_needle_index].content .. " from index " .. current_index)
end

function CurationNavigationUI:navigate_to_next_needle()
  local current_index = self._current_needle_index or 1
  self._current_needle_index = current_index < #self.needles and current_index + 1 or 1
  self:emit_navigation_event()
  self:log("Navigated to next needle: " .. self.needles[self._current_needle_index].content .. " from index " .. current_index)
end

-- The groups that directly contain needles (for spreadsheets: the
-- worksheets, which sit under a root group per file), each with the
-- index of its first needle. A/D hops between these.
function CurationNavigationUI:needle_group_anchors()
  local anchors = {}
  local pending_group = nil

  for _, entry in ipairs(self.navigation_list) do
    if entry.index then
      if pending_group then
        table.insert(anchors, {
          group_index = pending_group.group_index,
          needle_index = entry.index,
        })
        pending_group = nil
      end
    else
      pending_group = entry
    end
  end

  return anchors
end

function CurationNavigationUI:navigate_to_needle_group(direction)
  local anchors = self:needle_group_anchors()
  if #anchors == 0 then return end

  -- Which group's section is the current needle in? Needle indexes
  -- ascend through the list, so it's the last anchor at or before it.
  local current_needle_index = self._current_needle_index or 1
  local current_ordinal = 1
  for ordinal, anchor in ipairs(anchors) do
    if anchor.needle_index <= current_needle_index then
      current_ordinal = ordinal
    end
  end

  local target = current_ordinal + direction
  if target < 1 then target = #anchors end
  if target > #anchors then target = 1 end

  self._current_group_index = anchors[target].group_index
  self._current_needle_index = anchors[target].needle_index
  self:emit_navigation_event()
  self:log(('Navigated to needle group %d of %d'):format(target, #anchors))
end

function CurationNavigationUI:navigate_to_previous_needle_group()
  self:navigate_to_needle_group(-1)
end

function CurationNavigationUI:navigate_to_next_needle_group()
  self:navigate_to_needle_group(1)
end

-- Emit navigation event through workflow event system
function CurationNavigationUI:emit_navigation_event()
  if not self.needles[self._current_needle_index] then
    self:log("Warning: No needle at index " .. tostring(self._current_needle_index))
    return
  end

  local current_needle = self.needles[self._current_needle_index]
  local needle_id = current_needle.guid or current_needle.id or tostring(self._current_needle_index)

  self.workflow:emit_event("needle_navigated", {
    needle_index = self._current_needle_index,
    needle_id = needle_id,
    needle = current_needle
  })

  self:log("Emitted needle_navigated event for needle_id: " .. needle_id .. " at index: " .. self._current_needle_index)
end