
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

-- A pressable row per material (chips over small text links): the
-- whole row opens the configuration dialog, unlink keeps its own zone
function ScriptMaterialUI:render_summary()
  RowChip.render('##material-row-' .. (self.material.guid or self.material.name), {
    icon = 'spreadsheet',
    label = self.material.name,
    tooltip = self.material.filepath,
    on_press = function()
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
    end,
    action = {
      icon = Icons.x_mark,
      tooltip = 'Unlink this material from the session',
      on_press = function()
        self:log('Unlinking material: ' .. self.material.name)
        self:unlink_material()
      end,
    },
  })

  if self.material_configuration_ui then
    self.material_configuration_ui:render()
  end
end

function ScriptMaterialUI:unlink_material()
  self:log('Unlinking material: ' .. self.material.name)
  self.materials:unlink_material(self.material)
  self.workflow:emit_event('script_material_unlinked', { material = self.material })

  -- Unlinking is a completed action, not a mid-edit state; bring
  -- needles current immediately
  self.workflow:regenerate_needles()
end