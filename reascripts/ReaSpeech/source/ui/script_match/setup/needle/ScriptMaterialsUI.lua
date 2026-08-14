
ScriptMaterialsUI = Polo {}

function ScriptMaterialsUI:init()
  Logging().init(self, 'ScriptMaterialsUI')

  assert(self.session_id, 'ScriptMaterialsUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialsUI: workflow is required')
  assert(self.script_materials, 'ScriptMaterialsUI: script_materials is required')

  self.material_uis = self:init_material_uis()

  self.workflow:listen_for_event('script_material_unlinked', function(event)
    self:log("Received script_material_unlinked event for material: " .. dump(event.material))
    self:mark_dirty()
  end)

  self:log("Initialized ScriptMaterialsUI")
end

function ScriptMaterialsUI:init_material_uis()
  local materials = self.script_materials:get_materials()
  local material_uis = {}

  for _, material in ipairs(materials) do
    local material_ui = ScriptMaterialUI.new {
      session_id = self.session_id,
      workflow = self.workflow,
      material = material,
      materials = self.script_materials,
    }
    table.insert(material_uis, material_ui)
  end

  return material_uis
end

function ScriptMaterialsUI:render()
  self:reload_if_dirty()

  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), "Script Materials")
  end, Trap)
  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)

  ImGui.Indent(Ctx(), 6)
  ImGui.PushStyleVar(Ctx(), ImGui.StyleVar_ItemSpacing(), 8, 7)
  Trap(function()
    for _, material_ui in ipairs(self.material_uis) do
      material_ui:render_summary()
    end
  end)
  ImGui.PopStyleVar(Ctx())
  ImGui.Unindent(Ctx(), 6)
end

function ScriptMaterialsUI:import()
  local files = self:import_selector()

  for _, file in ipairs(files) do
    local material = self.script_materials:import_file(file)
    self.workflow:emit_event('script_material_updated', { material = material })
  end

  -- Rebuild from storage so existing materials stay listed alongside
  -- the new imports
  self.material_uis = self:init_material_uis()

  self:log("Imported files: " .. table.concat(files, ", "))
end

function ScriptMaterialsUI:import_selector()
  return Widgets.FileSelector.simple_open(
    'Import Script Materials',
    self.script_materials:get_supported_extensions(),
    { allow_multiple = true }
  )
end

function ScriptMaterialsUI:mark_dirty()
  self._dirty_flag = true
  self:log("Marked ScriptMaterialsUI as dirty")
end

function ScriptMaterialsUI:reload_if_dirty()
  if not self._dirty_flag then
    return
  end

  self.material_uis = self:init_material_uis()

  self._dirty_flag = false
end

function ScriptMaterialsUI:has_script_materials()
  return #self.material_uis > 0
end