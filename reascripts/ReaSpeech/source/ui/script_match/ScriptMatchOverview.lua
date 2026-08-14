
ScriptMatchOverview = Polo {}

function ScriptMatchOverview:init()
  Logging().init(self, 'ScriptMatchOverview')

  assert(self.app, 'ScriptMatchOverview: app is required')
  assert(self.plugin, 'ScriptMatchOverview: plugin is required')
  assert(self.sessions, 'ScriptMatchOverview: sessions is required')
  assert(self.controls, 'ScriptMatchOverview: controls is required')

  self.saved_sessions = self.sessions:get_sessions()

  self:log("Initialized ScriptMatchOverview")
end

function ScriptMatchOverview:render()
  if ImGui.BeginChild(Ctx(), 'script-match-overview', 0, 0, ImGui.WindowFlags_None()) then
    Trap(function()
      Fonts.wrap(Ctx(), Fonts.bigboi, function()
        ImGui.Text(Ctx(), "Script Match Overview")
      end, Trap)

      ImGui.Separator(Ctx())

      self:render_overview_content()
    end)

    ImGui.EndChild(Ctx())
  end
end

function ScriptMatchOverview:render_overview_content()
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), "Sessions")
  end, Trap)

  if ImGui.BeginChild(Ctx(), 'active-sessions', 0, 0, ImGui.WindowFlags_None()) then
    Trap(function()
      for _, session in ipairs(self.saved_sessions) do
        ImGui.PushID(Ctx(), '#session-row-' .. session.id)
        Trap(function()
          ImGui.Text(Ctx(), "Session: " .. session.name)
          ImGui.SameLine(Ctx())
          if ImGui.Button(Ctx(), "Open") then
            self:log("Opening session: " .. session.name)
            self.controls:open_session(session.id)
          end
        end)
        ImGui.PopID(Ctx())
      end
      ImGui.Separator(Ctx())

      if #self.saved_sessions == 0 then
        ImGui.Text(Ctx(), "No active sessions found.")
      end
    end)

    ImGui.EndChild(Ctx())
  end
end