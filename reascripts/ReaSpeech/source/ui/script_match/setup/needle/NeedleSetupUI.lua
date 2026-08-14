
NeedleSetupUI = Polo {}

function NeedleSetupUI:init()
  Logging().init(self, 'NeedleSetupUI')

  assert(self.session_id, 'NeedleSetupUI: session_id is required')
  assert(self.workflow, 'NeedleSetupUI: workflow is required')

  self.script_materials = self.workflow:get_script_materials_service()

  self.script_materials_ui = ScriptMaterialsUI.new {
    session_id = self.session_id,
    workflow = self.workflow,
    script_materials = self.script_materials,
  }

  self:log("Initialized NeedleSetupUI")
end

function NeedleSetupUI:render(panel_width)
  if ImGui.BeginChild(Ctx(), 'needle-setup', panel_width, 0, ImGui.WindowFlags_None()) then
    Trap(function()
      self.script_materials_ui:render()

      ImGui.Dummy(Ctx(), 0, 4)
      self:render_import_button()
    end)

    ImGui.EndChild(Ctx())
  end
end

function NeedleSetupUI:render_import_button()
  if ImGui.Button(Ctx(), "Import Script Materials") then
    self.script_materials_ui:import()
  end
end

function NeedleSetupUI:has_script_materials()
  return self.script_materials_ui:has_script_materials()
end