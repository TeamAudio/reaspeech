
ScriptMaterialConfigurationUI = Polo {}

function ScriptMaterialConfigurationUI:init()
  Logging().init(self, 'MaterialConfigurationUI')

  assert(self.session_id, 'MaterialConfigurationUI: session_id is required')
  assert(self.workflow, 'MaterialConfigurationUI: workflow is required')
  assert(self.material, 'MaterialConfigurationUI: material is required')
  assert(self.handler, 'MaterialConfigurationUI: handler is required')

  ToolWindow.init(self, {
    title = 'Script Material Configuration',
    width = 900,
    height = 600,
    window_flags = ImGui.WindowFlags_None() | ImGui.WindowFlags_NoCollapse() | ImGui.WindowFlags_NoDocking(),
  })

  self:log("Initialized MaterialConfigurationUI for material: " .. (self.material.name or '<no name>'))
end

-- ToolWindow wraps this class method: it runs once, when the close
-- animation finalizes (will_close is a TabBar hook, not a ToolWindow one)
function ScriptMaterialConfigurationUI:close()
  self:log("MaterialConfigurationUI closed")

  -- Pending edits persist on the NEXT frame's render, which never comes
  -- once the window closes; flush before regenerating from storage
  if self.handler.save_if_dirty then
    self.handler:save_if_dirty()
  end

  -- Closing the config dialog marks the end of an editing session — a
  -- natural point to bring needles current automatically
  if self.workflow:needles_stale() then
    self.workflow:regenerate_needles()
  end
end

function ScriptMaterialConfigurationUI:render_content()
  Fonts.wrap(Ctx(), Fonts.bigboi, function()
    ImGui.Text(Ctx(), self.material.name)
  end, Trap)

  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 6)

  self.handler:render()
end