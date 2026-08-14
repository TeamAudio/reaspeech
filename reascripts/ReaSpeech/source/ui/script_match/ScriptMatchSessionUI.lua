
ScriptMatchSessionUI = Polo {}

function ScriptMatchSessionUI:init()
  Logging().init(self, 'ScriptMatchSessionUI')

  assert(self.app, 'ScriptMatchSessionUI: app is required')
  assert(self.session, 'ScriptMatchSessionUI: session is required')

  self:log('Initializing ScriptMatchSessionUI for session: ' .. dump(self.session))
  self.workflow = ScriptMatchWorkflow.new {
    plugin = self,
    session_ui = self,
  }

  self.sessions = ScriptMatchSessions.new {}

  self.editing_name = false
  self.name_editor = Widgets.TextInput.new {
    default = self.session.name,
    on_cancel = function()
      self.editing_name = false
    end,
    on_enter = function(value)
      self.editing_name = false
      self:rename_session(value)
    end,
    width = function()
      -- Leave the right-aligned phase cards their room while editing
      local avail = ImGui.GetContentRegionAvail(Ctx())
      return math.max(180, avail - self.workflow:phase_bar_width() - 40)
    end,
  }
end

function ScriptMatchSessionUI:key()
  return 'script-match-session-' .. self.session.id
end

function ScriptMatchSessionUI:tabs()
  return { self:tab() }
end

function ScriptMatchSessionUI:session_id()
  return self.session.id
end

function ScriptMatchSessionUI:new_tab_menu()
  return {}
end

function ScriptMatchSessionUI:tab()
  return ReaSpeechPlugins.tab(
    self:key(),
    self.session.name,
    {
      render = function()
        self:render_header()
        self.workflow:render()
      end,

      render_bg = function() end
    },
    {
      will_close = function() return self:confirm_session_close() end,
      on_close = function() self:close_session() end
    }
  )
end

-- One compact row: session name on the left (with a rename
-- affordance, same pattern as the ASR transcript name), the
-- right-aligned phase cards filling out the rest. The identifying
-- details moved into a tooltip on the name.
ScriptMatchSessionUI.NAME_LEFT_PAD = 8

function ScriptMatchSessionUI:render_header()
  ImGui.Dummy(Ctx(), 0, 2)

  ImGui.SetCursorPosX(Ctx(), ImGui.GetCursorPosX(Ctx()) + ScriptMatchSessionUI.NAME_LEFT_PAD)

  -- Drop the name to center it against the taller phase cards sharing
  -- this row; render_phase_bar pulls its cursor back up by the same
  -- amount (SameLine carries this offset Y over to the cards). The
  -- offset math assumes the bigboi font used here.
  local offset = ScriptMatchWorkflow.phase_card_center_offset()
  ImGui.SetCursorPosY(Ctx(), ImGui.GetCursorPosY(Ctx()) + offset)

  Fonts.wrap(Ctx(), Fonts.bigboi, function()
    if self.editing_name then
      self.name_editor:render()
    else
      ImGui.Text(Ctx(), self.session.name)

      ImGui.SetItemTooltip(Ctx(), table.concat({
        'Session ID: ' .. self.session.id,
        'Created: ' .. os.date('%Y-%m-%d %H:%M:%S', self.session.created_at),
        'Updated: ' .. os.date('%Y-%m-%d %H:%M:%S', self.session.updated_at),
      }, '\n'))

      ImGui.SameLine(Ctx())
      local icon_size = Fonts.size:get() - 1
      if Widgets.icon(Icons.pencil, "##rename_session", icon_size, icon_size, "Rename") then
        self.name_editor:set(self.session.name)
        self.editing_name = true
      end
    end
  end, Trap)

  ImGui.SameLine(Ctx(), 0, 24)
end

function ScriptMatchSessionUI:rename_session(name)
  if name == '' or name == self.session.name then
    return
  end

  self.session.name = name
  self.session.updated_at = os.time()
  self.sessions:update_session(self.session)

  -- Tab labels are collected at plugin registration; rebuild so the
  -- session tab shows the new name
  self.app.plugins:init_tabs()

  self:log('Renamed session to: ' .. name)
end

-- Oneshot risk slider position (0 = comb/hand-curate everything,
-- 1 = dice/auto-accept what the odds favor): a session-level setting,
-- persisted on the session record
function ScriptMatchSessionUI:get_oneshot_risk()
  return self.session.oneshot_risk or 0
end

function ScriptMatchSessionUI:set_oneshot_risk(risk)
  if risk == self.session.oneshot_risk then
    return
  end

  self.session.oneshot_risk = risk
  self.session.updated_at = os.time()
  self.sessions:update_session(self.session)
end

function ScriptMatchSessionUI:confirm_session_close()
  return true
end

function ScriptMatchSessionUI:close_session()
  self.app.plugins:remove_plugin(self)
  self:log('Closing session: ' .. self.session.name)
end