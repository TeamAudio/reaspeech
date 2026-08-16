
ScriptMaterials = Polo {}

function ScriptMaterials:init()
  Logging().init(self, 'ScriptMaterials')

  assert(self.session_id, 'ScriptMaterials: session_id is required')

  self.handlers = {
    ScriptMaterialExcelSpreadsheet,
  }

  self.storage = self:get_storage()

  self.materials = self.storage:table('materials', {})
end

-- Shape expected by Widgets.FileSelector.simple_open: dotless
-- extension(s) -> description, comma-joining extensions that share a
-- description into one filter row (handler maps use dotted keys for
-- can_handle_file; the dialog formats keys as '*.<key>')
function ScriptMaterials:get_supported_extensions()
  local extensions_by_description = {}

  for _, handler in ipairs(self.handlers) do
    for ext, description in pairs(handler.get_supported_extensions()) do
      local bare = ext:gsub('^%.', '')
      if extensions_by_description[description] then
        extensions_by_description[description] = extensions_by_description[description] .. ',' .. bare
      else
        extensions_by_description[description] = bare
      end
    end
  end

  local supported_extensions = {}
  for description, extensions in pairs(extensions_by_description) do
    supported_extensions[extensions] = description
  end

  return supported_extensions
end

function ScriptMaterials:session_storage_location()
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function ScriptMaterials:get_storage()
  local json_file = self:session_storage_location() .. '/script_materials.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  })
end

function ScriptMaterials:material_storage_location(material_guid)
  assert(material_guid, 'ScriptMaterials:material_storage_location: material_guid is required')

  return ('%s/script_materials/%s.json'):format(self:session_storage_location(), material_guid)
end

function ScriptMaterials:get_material_storage(material_guid)
  assert(material_guid, 'ScriptMaterials:get_material_storage: material_guid is required')

  local storage_location = self:material_storage_location(material_guid)

  return Storage.ProjectJSON(storage_location, {
    schema_version = 1,
    migrations = {}
  }):table('material_config', {})
end

function ScriptMaterials:get_materials()
  return self.materials:get()
end

function ScriptMaterials:import_file(filepath)
  local material = self:create_material {
    filepath = filepath
  }

  self:add_material(material)

  return material
end

function ScriptMaterials:find_handler_for_file(filepath)
  for _, handler in ipairs(self.handlers) do
    if handler:can_handle_file(filepath) then
      return handler
    end
  end

  error("No handler found for file: " .. filepath)
end

function ScriptMaterials:find_handler(material_type)
  for _, handler in ipairs(self.handlers) do
    if handler.key == material_type then
      return handler
    end
  end

  error("No handler found for material type: " .. (material_type or "<no type>"))
end

function ScriptMaterials:create_material(material)
  assert(material, 'ScriptMaterials:create_material: material is required')
  assert(material.filepath and material.filepath ~= '', 'ScriptMaterials:create_material: material.filepath is required')

  local handler = self:find_handler_for_file(material.filepath)

  if not handler then
    error("No handler found for file: " .. material.filepath)
  end

  local guid = reaper.genGuid('')
  material.guid = guid

  local material_storage = self:get_material_storage(guid)
  local material_data = {
    guid = guid,
    filepath = material.filepath,
    name = material.name or PathUtil.get_filename(material.filepath),
    created_at = os.time(),
    type = handler.key,
  }

  for k, v in pairs(handler:get_default_material_data()) do
    if not material_data[k] then
      material_data[k] = v
    end
  end

  material_storage:set(material_data)

  self:log("Created new script material with GUID: " .. guid)

  return material_data
end

function ScriptMaterials:add_material(material)
  assert(material, 'ScriptMaterials:add_material: material is required')

  local materials = self.materials:get()

  for _, existing_material in ipairs(materials) do
    if existing_material.filepath == material.filepath then
      self:log("Material with filepath '" .. material.filepath .. "' already exists, skipping addition.")
      return
    end
  end

  table.insert(materials, material)
  self.materials:set(materials)

  self:log("Added script material with GUID: " .. material.guid)
end

function ScriptMaterials:unlink_material(material)
  assert(material, 'ScriptMaterials:unlink_material: material is required')

  local materials = self.materials:get()

  for i, existing_material in ipairs(materials) do
    if existing_material.guid == material.guid then
      table.remove(materials, i)
      self.materials:set(materials)
      self:sweep_material_files(material.guid)
      self:log("Unlinked script material with GUID: %s", material.guid)
      return true
    end
  end

  self:log("Material with GUID '%s' not found, cannot unlink.", material.guid)
  return false
end

-- Everything on disk that belongs solely to one material: its config
-- store, its needle store, and one suggestion file per needle
function ScriptMaterials:material_file_subpaths(material_guid, needle_guids)
  local subpaths = {
    self:material_storage_location(material_guid),
    ('%s/needles/%s.json'):format(self:session_storage_location(), material_guid),
  }

  for _, needle_guid in ipairs(needle_guids) do
    table.insert(subpaths,
      ('%s/suggestions/%s.json'):format(self:session_storage_location(), needle_guid))
  end

  return subpaths
end

-- An unlinked material's derived files would otherwise haunt the
-- session directory as ghosts (live case: 1127 ghost needles once
-- inflated status counts). Sweep them at unlink; the storage cache is
-- invalidated so a re-import of the same file starts clean.
function ScriptMaterials:sweep_material_files(material_guid)
  local needle_store_subpath =
    ('%s/needles/%s.json'):format(self:session_storage_location(), material_guid)
  local needles = Storage.ProjectJSON(needle_store_subpath, {
    schema_version = 1,
    migrations = {}
  }):table('needles', {}):get()

  local needle_guids = {}
  for _, needle in ipairs(needles) do
    if needle.guid then
      table.insert(needle_guids, needle.guid)
    end
  end

  local project_path = PathUtil.normalize(reaper.GetProjectPathEx(0))
  for _, subpath in ipairs(self:material_file_subpaths(material_guid, needle_guids)) do
    local filepath = project_path .. '/' .. subpath
    Storage.JSONFile.invalidate(filepath)
    if reaper.file_exists(filepath) then
      os.remove(filepath)
      self:log("Swept: " .. subpath)
    end
  end
end