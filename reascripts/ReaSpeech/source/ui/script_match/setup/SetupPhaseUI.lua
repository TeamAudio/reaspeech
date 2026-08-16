
SetupPhaseUI = Polo {}

function SetupPhaseUI:init()
  Logging().init(self, 'SetupPhaseUI')

  assert(self.session_ui, 'SetupPhaseUI: session_ui is required')
  assert(self.workflow, 'SetupPhaseUI: workflow is required')

  PhaseContainer.init(self, 'setup', 'Setup', 'gear')

  local renderers = {
    self:haystack_renderer(),
    self:needle_renderer()
  }

  self.column_layout = ColumnLayout.new {
    column_padding = 12,
    margin_bottom = 0,
    margin_left = 0,
    margin_right = 0,
    num_columns = #renderers,

    render_column = function (column)
      -- self:log(("Rendering column %d with width %f"):format(column.num, column.width))
      Trap(function()
        renderers[column.num](column.width)
      end)
    end
  }


  self:log("Initialized SetupPhaseUI")
end

function SetupPhaseUI:get_status_callback()
  local status = self.workflow:get_session_status()

  if status.tracks > 0 and status.materials > 0 then
    return {
      indicator = '*',
      hint = ('%d tracks, %d materials'):format(status.tracks, status.materials),
    }
  end

  local missing = {}
  if status.tracks == 0 then table.insert(missing, 'link audio tracks') end
  if status.materials == 0 then table.insert(missing, 'import script materials') end

  return {
    hint = table.concat(missing, ' and '),
  }
end

function SetupPhaseUI:render_content_callback()
  if not self:oneshot_band_visible() then
    self.column_layout:render()
    return
  end

  -- Pin the band inside the window: the columns get the remaining
  -- height in a child (scrolling internally when cramped), so GO sits
  -- at the bottom edge instead of pushing past it. The reservation
  -- must count the ItemSpacing the child and margin dummy each add,
  -- or the total lands a few pixels tall and grows a scrollbar.
  local c = SetupPhaseUI.ONESHOT
  local avail_w, avail_h = ImGui.GetContentRegionAvail(Ctx())
  local _, spacing_y = ImGui.GetStyleVar(Ctx(), ImGui.StyleVar_ItemSpacing())
  local reserved = c.HEIGHT + c.BAND_MARGIN + spacing_y * 2 + 2
  local columns_h = math.max(math.floor(avail_h - reserved), 50)

  -- NoScrollbar mirrors the phase container's philosophy: the columns
  -- carry a few px of trailing padding that would otherwise grow a
  -- pointless scrollbar against the reduced height
  if ImGui.BeginChild(Ctx(), '##setup-columns', avail_w, columns_h,
    ImGui.ChildFlags_None(), ImGui.WindowFlags_NoScrollbar()) then
    Trap(function()
      self.column_layout:render()
    end)
    ImGui.EndChild(Ctx())
  end

  self:render_oneshot_band()
end

SetupPhaseUI.ONESHOT = {
  HEIGHT = 64,
  PADDING = 12,
  ICON_SIZE = 40,
  ICON_GAP = 14,
  ROUNDING = 8,
  PRESS_NUDGE = 1,
  BAND_MARGIN = 8,
  TAGLINE_COLOR = 0xAAAAAAFF,

  -- Risk slider cluster on the band's right: comb (precision) to
  -- dice (gamble) = auto-accept confidence threshold
  SLIDER = {
    TRACK_W = 140,
    TRACK_H = 4,
    HIT_H = 28,
    KNOB_R = 7,
    ICON_SIZE = 28,
    GAP = 10,
    ZONE_PAD = 18,
    TRACK_COLOR = 0x5C5C5CFF,
  },
}

-- Visible once setup can be rolled (or a roll is underway); hidden
-- again when every line already has suggestions
function SetupPhaseUI:oneshot_band_visible()
  local runner = self.workflow:get_oneshot_runner()
  if runner:is_rolling() or runner.state == 'done' then return true end

  local status = self.workflow:get_session_status()
  if status.tracks == 0 or status.materials == 0 then return false end
  if status.lines > 0 and status.with_suggestions >= status.lines then return false end

  return true
end

-- The big GO: one press rolls matches for every line in the script.
-- Idle it glows and begs to be pressed; while rolling it becomes its
-- own progress bar; done, it hands the session to curation.
function SetupPhaseUI:render_oneshot_band()
  local runner = self.workflow:get_oneshot_runner()

  if runner.state == 'done' then
    runner:reset()
    self.workflow:activate_phase('curation')
    return
  end

  if runner:is_rolling() then
    self:render_oneshot_progress(runner)
    runner:tick()
    return
  end

  local status = self.workflow:get_session_status()
  local c = SetupPhaseUI.ONESHOT
  ImGui.Dummy(Ctx(), 0, SetupPhaseUI.ONESHOT.BAND_MARGIN)

  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local width = ImGui.GetContentRegionAvail(Ctx())

  -- The slider cluster claims the band's right edge; GO keeps the rest
  local s = c.SLIDER
  local cluster_w = s.ICON_SIZE * 2 + s.GAP * 2 + s.TRACK_W
  local go_w = math.max(width - cluster_w - s.ZONE_PAD - c.PADDING, 120)

  local clicked = ImGui.InvisibleButton(Ctx(), '##oneshot-go', go_w, c.HEIGHT)
  local hovered = ImGui.IsItemHovered(Ctx())
  local held = ImGui.IsItemActive(Ctx())

  if hovered then
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end

  local dl = ImGui.GetWindowDrawList(Ctx())

  -- Always-on halo with a slow pulse; hover holds it at full glow
  local pulse = hovered and 1 or (0.5 + 0.5 * math.sin(reaper.time_precise() * 2.2))
  local accent = Theme.COLORS.pink_opaque
  for i, alpha in ipairs({ 0x99, 0x55, 0x26 }) do
    local halo = math.floor(alpha * (0.45 + 0.55 * pulse))
    ImGui.DrawList_AddRect(dl,
      x - i, y - i, x + width + i, y + c.HEIGHT + i,
      (accent & 0xFFFFFF00) | halo, c.ROUNDING + i)
  end

  local bg = Theme.COLORS.dark_gray_translucent
  if held then
    bg = Theme.COLORS.dark_gray_opaque
  elseif hovered then
    bg = Theme.COLORS.dark_gray_semi_transparent
  end
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + c.HEIGHT, bg, c.ROUNDING)

  local press = held and c.PRESS_NUDGE or 0
  local icon_y = y + (c.HEIGHT - c.ICON_SIZE) / 2 + press
  ImGui.SetCursorScreenPos(Ctx(), x + c.PADDING, icon_y)
  EmojiText.icon('dice', c.ICON_SIZE)

  local text_x = x + c.PADDING + c.ICON_SIZE + c.ICON_GAP
  ImGui.SetCursorScreenPos(Ctx(), text_x, y + 8 + press)
  Fonts.wrap(Ctx(), Fonts.bigboi, function()
    ImGui.Text(Ctx(), 'GO')
  end, Trap)

  local tagline
  if status.lines == 0 then
    tagline = 'Roll matches for every line in the script'
  elseif status.with_suggestions == 0 then
    tagline = ('Roll matches for all %d lines'):format(status.lines)
  else
    tagline = ('Roll matches for the remaining %d lines'):format(status.lines - status.with_suggestions)
  end
  ImGui.SetCursorScreenPos(Ctx(), text_x, y + c.HEIGHT - 24 + press)
  ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), c.TAGLINE_COLOR)
  Trap(function()
    ImGui.Text(Ctx(), tagline)
  end)
  ImGui.PopStyleColor(Ctx())

  self:render_risk_slider(x + width - c.PADDING - cluster_w, y)

  if clicked then
    self:start_oneshot()
  end
end

-- Current slider position (0 = comb .. 1 = dice), session-persisted
function SetupPhaseUI:oneshot_risk()
  if not self._oneshot_risk then
    self._oneshot_risk = self.session_ui:get_oneshot_risk()
  end
  return self._oneshot_risk
end

function SetupPhaseUI:set_oneshot_risk(risk, persist)
  self._oneshot_risk = risk
  if persist then
    self.session_ui:set_oneshot_risk(risk)
  end
end

-- The risk slider: comb at the precision end, dice at the gamble end.
-- Position maps to an auto-accept confidence threshold (comb = none:
-- every take auditioned by hand).
function SetupPhaseUI:render_risk_slider(cluster_x, band_y)
  local c = SetupPhaseUI.ONESHOT
  local s = c.SLIDER
  local risk = self:oneshot_risk()

  local control_cy = band_y + 26
  local track_x = cluster_x + s.ICON_SIZE + s.GAP
  local dl = ImGui.GetWindowDrawList(Ctx())

  -- End icons snap the slider to their extremes
  local ends = {
    { icon = 'comb', x = cluster_x, risk = 0,
      tip = 'Fine-toothed comb - every take auditioned by hand' },
    { icon = 'dice', x = cluster_x + s.ICON_SIZE + s.GAP * 2 + s.TRACK_W, risk = 1,
      tip = 'Roll the dice - accept what the odds favor' },
  }
  for _, e in ipairs(ends) do
    ImGui.SetCursorScreenPos(Ctx(), e.x, control_cy - s.ICON_SIZE / 2)
    if ImGui.InvisibleButton(Ctx(), '##risk-' .. e.icon, s.ICON_SIZE, s.ICON_SIZE) then
      self:set_oneshot_risk(e.risk, true)
    end
    if ImGui.IsItemHovered(Ctx()) then
      ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
    end
    Widgets.tooltip(e.tip)
    ImGui.SetCursorScreenPos(Ctx(), e.x, control_cy - s.ICON_SIZE / 2)
    EmojiText.icon(e.icon, s.ICON_SIZE)
  end

  -- Track: drag anywhere on it (generous hit area) to set risk
  ImGui.SetCursorScreenPos(Ctx(), track_x, control_cy - s.HIT_H / 2)
  ImGui.InvisibleButton(Ctx(), '##risk-track', s.TRACK_W, s.HIT_H)
  local track_active = ImGui.IsItemActive(Ctx())
  if ImGui.IsItemHovered(Ctx()) or track_active then
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end
  if track_active then
    local mx = ImGui.GetMousePos(Ctx())
    risk = math.max(0, math.min(1, (mx - track_x) / s.TRACK_W))
    self:set_oneshot_risk(risk, false)
  end
  if ImGui.IsItemDeactivated(Ctx()) then
    self:set_oneshot_risk(risk, true)
  end

  local track_y = control_cy - s.TRACK_H / 2
  local knob_x = track_x + risk * s.TRACK_W
  ImGui.DrawList_AddRectFilled(dl, track_x, track_y,
    track_x + s.TRACK_W, track_y + s.TRACK_H, s.TRACK_COLOR, s.TRACK_H / 2)
  if risk > 0 then
    ImGui.DrawList_AddRectFilled(dl, track_x, track_y, knob_x,
      track_y + s.TRACK_H, (Theme.COLORS.pink_opaque & 0xFFFFFF00) | 0xAA, s.TRACK_H / 2)
  end
  ImGui.DrawList_AddCircleFilled(dl, knob_x, control_cy,
    track_active and s.KNOB_R + 1 or s.KNOB_R, Theme.COLORS.pink_opaque)

  -- Caption spells out what this roll will do
  local threshold = OneshotRunner.threshold_for_risk(risk)
  local caption, caption_color
  if threshold then
    caption = ('auto-accept >= %d%%'):format(math.floor(threshold * 100 + 0.5))
    caption_color = Theme.COLORS.pink_opaque
  else
    caption = 'hand-curate everything'
    caption_color = c.TAGLINE_COLOR
  end
  local caption_w = ImGui.CalcTextSize(Ctx(), caption)
  ImGui.SetCursorScreenPos(Ctx(),
    track_x + (s.TRACK_W - caption_w) / 2, band_y + c.HEIGHT - 22)
  ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), caption_color)
  Trap(function()
    ImGui.Text(Ctx(), caption)
  end)
  ImGui.PopStyleColor(Ctx())
end

function SetupPhaseUI:render_oneshot_progress(runner)
  local c = SetupPhaseUI.ONESHOT
  ImGui.Dummy(Ctx(), 0, SetupPhaseUI.ONESHOT.BAND_MARGIN)

  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local width = ImGui.GetContentRegionAvail(Ctx())
  ImGui.Dummy(Ctx(), width, c.HEIGHT)

  local dl = ImGui.GetWindowDrawList(Ctx())
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + c.HEIGHT,
    Theme.COLORS.dark_gray_translucent, c.ROUNDING)

  -- The band is its own progress bar: pink fill sweeping left to right
  local fraction = runner.total > 0 and (runner.completed / runner.total) or 0
  if fraction > 0 then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + width * fraction, y + c.HEIGHT,
      (Theme.COLORS.pink_opaque & 0xFFFFFF00) | 0x38, c.ROUNDING)
  end
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + c.HEIGHT, Theme.COLORS.pink_opaque, c.ROUNDING)

  local icon_y = y + (c.HEIGHT - c.ICON_SIZE) / 2
  ImGui.SetCursorScreenPos(Ctx(), x + c.PADDING, icon_y)
  EmojiText.icon('dice', c.ICON_SIZE)

  local text_x = x + c.PADDING + c.ICON_SIZE + c.ICON_GAP
  ImGui.SetCursorScreenPos(Ctx(), text_x, y + 8)
  Fonts.wrap(Ctx(), Fonts.big, function()
    if runner:is_diagnosing() then
      ImGui.Text(Ctx(), ('Diagnosing %d unmatched…'):format(#runner.diagnosis_queue))
    else
      ImGui.Text(Ctx(), ('Rolling  %d / %d'):format(runner.completed, runner.total))
    end
  end, Trap)

  ImGui.SetCursorScreenPos(Ctx(), text_x, y + c.HEIGHT - 24)
  ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), c.TAGLINE_COLOR)
  Trap(function()
    local found = ('%d takes found'):format(runner.takes_found)
    if runner.auto_accepted > 0 then
      found = found .. (', %d auto-accepted'):format(runner.auto_accepted)
    end
    if runner.diagnosed > 0 then
      found = found .. (', %d diagnosed'):format(runner.diagnosed)
    end
    ImGui.Text(Ctx(), found)
  end)
  ImGui.PopStyleColor(Ctx())
end

function SetupPhaseUI:start_oneshot()
  -- Fresh needles first: GO rolls over the current setup, never stale data
  local needles = self.workflow:regenerate_needles()
  local queued = self.workflow:get_oneshot_runner():start(needles, {
    auto_accept_threshold = OneshotRunner.threshold_for_risk(self:oneshot_risk()),
  })

  -- Everything already has suggestions: GO's promise is "get me
  -- matching", so keep it and land on curation directly
  if queued == 0 then
    self.workflow:activate_phase('curation')
  end
end

function SetupPhaseUI:haystack_setup_ui()
  if not self._haystack_setup_ui then
    self._haystack_setup_ui = HaystackSetupUI.new {
      session_id = self.session_ui:session_id(),
      workflow = self.workflow,
    }
  end

  return self._haystack_setup_ui
end

function SetupPhaseUI:haystack_renderer()
  return function(panel_width)
    self:haystack_setup_ui():render(panel_width)
  end
end

function SetupPhaseUI:needle_setup_ui()
  if not self._needle_setup_ui then
    self._needle_setup_ui = NeedleSetupUI.new {
      session_id = self.session_ui:session_id(),
      workflow = self.workflow,
    }
  end
  return self._needle_setup_ui
end

function SetupPhaseUI:needle_renderer()
  return function(panel_width)
    self:needle_setup_ui():render(panel_width)
  end
end

function SetupPhaseUI:audio_tracks()
  return self:haystack_setup_ui().audio_tracks:get_tracks()
end

function SetupPhaseUI:audio_track(guid)
  return self:haystack_setup_ui().audio_tracks:get_track_by_guid(guid)
end