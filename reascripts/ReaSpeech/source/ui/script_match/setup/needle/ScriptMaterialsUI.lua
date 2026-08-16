
ScriptMaterialsUI = Polo {}

function ScriptMaterialsUI:init()
  Logging().init(self, 'ScriptMaterialsUI')

  assert(self.session_id, 'ScriptMaterialsUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialsUI: workflow is required')
  assert(self.script_materials, 'ScriptMaterialsUI: script_materials is required')

  self.material_uis = self:init_material_uis()

  -- Obvious candidates already in the project folder, offered as
  -- one-press quick choices below the linked materials
  self.folder_scan = ProjectFolderScan.new {}
  self._scan = self.folder_scan:scan()

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

    self:render_quick_choices()
  end)
  ImGui.PopStyleVar(Ctx())
  ImGui.Unindent(Ctx(), 6)
end

-- Spreadsheets discovered next to the project, minus what's already
-- linked: one press imports without the file browser
function ScriptMaterialsUI:quick_choice_spreadsheets()
  local linked = {}
  for _, material in ipairs(self.script_materials:get_materials()) do
    linked[material.filepath] = true
  end

  local candidates = {}
  for _, filepath in ipairs((self._scan and self._scan.spreadsheets) or {}) do
    if not linked[filepath] then
      table.insert(candidates, filepath)
    end
  end
  return candidates
end

function ScriptMaterialsUI:render_quick_choices()
  local candidates = self:quick_choice_spreadsheets()
  if #candidates == 0 then return end

  ImGui.Dummy(Ctx(), 0, 2)
  ImGui.TextColored(Ctx(), 0x888888FF, 'Found in project folder:')
  ImGui.SameLine(Ctx())
  Widgets.link('rescan', function()
    self._scan = self.folder_scan:scan()
  end, 0x888888FF, 0xEEEEEEFF)

  for _, filepath in ipairs(candidates) do
    local lower = filepath:lower()
    local import_this = function()
      self:import_quick_choice(filepath)
    end
    RowChip.render('##quick-material-' .. filepath, {
      icon = (lower:match('%.csv$') or lower:match('%.tsv$')) and 'csv' or 'spreadsheet',
      label = PathUtil.get_filename(filepath),
      dim = true,
      tooltip = filepath .. '\nPress to import as a script material.',
      on_press = import_this,
      action = {
        label = 'import',
        tooltip = 'Import as a script material',
        on_press = import_this,
      },
    })
  end
end

function ScriptMaterialsUI:import_quick_choice(filepath)
  local material = self.script_materials:import_file(filepath)
  self.workflow:emit_event('script_material_updated', { material = material })
  self.material_uis = self:init_material_uis()
  self:log("Imported quick choice: " .. filepath)
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