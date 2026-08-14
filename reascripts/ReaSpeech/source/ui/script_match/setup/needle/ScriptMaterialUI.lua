
ScriptMaterialUI = Polo {}

function ScriptMaterialUI:init()
  Logging().init(self, 'ScriptMaterialUI')

  assert(self.session_id, 'ScriptMaterialUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialUI: workflow is required')
  assert(self.material, 'ScriptMaterialUI: material is required')
  assert(self.materials, 'ScriptMaterialUI: materials is required')

  self.handlers = {
    [ScriptMaterialExcelSpreadsheet.key] = ScriptMaterialExcelSpreadsheetUI,
  }

  self.handler = self:find_handler(self.material.type).new {
    session_id = self.session_id,
    workflow = self.workflow,
    material = self.material,
    materials = self.materials,
  }

  self:log("Initialized ScriptMaterialUI")
end

function ScriptMaterialUI:find_handler(material_type)
  local handler = self.handlers[material_type]
  if not handler then
    self:log("No handler found for material type: " .. (material_type or "<no type>"))
  end
  return handler
end

function ScriptMaterialUI:render()
  ImGui.Text(Ctx(), self.material.name)
end

function ScriptMaterialUI:render_summary()
  EmojiText.icon('spreadsheet')
  ImGui.SameLine(Ctx(), 0, 4)
  self:render_material_name()

  if self.material_configuration_ui then
    self.material_configuration_ui:render()
  end
end

function ScriptMaterialUI:render_material_name()
  local link_color = 0xeeeeeeff

  Widgets.link(self.material.name, function()
    self.material_configuration_ui = ScriptMaterialConfigurationUI.new {
      session_id = self.session_id,
      workflow = self.workflow,
      material = self.material,
      handler = self.handler,
    }

    -- Defensive re-add; opening the dialog is not a data change, so no
    -- script_material_updated here (it would flag needles stale on open)
    self.materials:add_material(self.material)
    self.material_configuration_ui:present()
  end, link_color, link_color)

  ImGui.SameLine(Ctx())

  Widgets.link('[unlink]', function()
    self:log('Unlinking material: ' .. self.material.name)
    self:unlink_material()
  end, 0xbbbbbbff, 0xbbbbbbff)
end

function ScriptMaterialUI:unlink_material()
  self:log('Unlinking material: ' .. self.material.name)
  self.materials:unlink_material(self.material)
  self.workflow:emit_event('script_material_unlinked', { material = self.material })

  -- Unlinking is a completed action, not a mid-edit state; bring
  -- needles current immediately
  self.workflow:regenerate_needles()
end