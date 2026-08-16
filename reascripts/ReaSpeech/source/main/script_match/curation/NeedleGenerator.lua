NeedleGenerator = Polo {}

function NeedleGenerator:init()
  Logging().init(self, 'NeedleGenerator')

  assert(self.session_id, 'NeedleGenerator: session_id is required')
  assert(self.script_materials, 'NeedleGenerator: script_materials is required')
  assert(self.materials_service, 'NeedleGenerator: materials_service is required')

  self.storage = self:get_storage()
  self.needles_index = self.storage:table('needles_index', {})

  self:log("Initialized NeedleGenerator")
end

function NeedleGenerator:needles()
  self:log("Generating needles for session_id: " .. self.session_id)

  local all_needles = {}

  for _, material in ipairs(self.script_materials) do
    local material_needles = self:generate_material_needles(material)

    -- Add all needles from this material to the combined list
    for _, needle in ipairs(material_needles) do
      table.insert(all_needles, needle)
    end
  end

  self:log(string.format("Generated total of %d needles across %d materials",
    #all_needles, #self.script_materials))

  return all_needles
end

function NeedleGenerator:generate_material_needles(material)
  assert(material.guid, 'NeedleGenerator:generate_material_needles: material.guid is required')

  self:log("Processing material: " .. material.guid)

  local material_storage = self:get_material_storage(material.guid)
  local existing_needles = material_storage:get()
  local existing_by_locator = self:build_locator_lookup(existing_needles)

  local fresh_needles = self:generate_fresh_needles(material)
  local deduplicated_needles = self:deduplicate_needles(fresh_needles, existing_by_locator, material)

  self:persist_material_needles(material.guid, deduplicated_needles, #existing_needles)

  return deduplicated_needles
end

function NeedleGenerator:build_locator_lookup(existing_needles)
  local existing_by_locator = {}
  for _, needle in ipairs(existing_needles) do
    if needle.locator then
      existing_by_locator[needle.locator] = needle
    end
  end
  return existing_by_locator
end

function NeedleGenerator:generate_fresh_needles(material)
  local instance = ScriptMaterial.new {
    session_id = self.session_id,
    material = material,
    materials = self.materials_service,
  }
  return instance:needles()
end

function NeedleGenerator:deduplicate_needles(fresh_needles, existing_by_locator, material)
  local deduplicated_needles = {}

  for _, fresh_needle in ipairs(fresh_needles) do
    local needle = self:resolve_needle(fresh_needle, existing_by_locator)
    self:ensure_navigation_path(needle, material)
    -- Content-derived, so recomputed on every generation (a config
    -- change may swap the line column under the same locator)
    needle.matchability = Matchability.classify(needle.content)
    table.insert(deduplicated_needles, needle)
  end

  return deduplicated_needles
end

function NeedleGenerator:resolve_needle(fresh_needle, existing_by_locator)
  local existing = fresh_needle.locator and existing_by_locator[fresh_needle.locator]

  if existing then
    -- Preserve the needle's identity (its GUID anchors editorial
    -- decisions), but take the freshly generated content, metadata and
    -- navigation - configuration changes (tags, line column) must
    -- propagate to existing needles on regeneration
    self:log("Reusing existing needle GUID for locator: " .. fresh_needle.locator)
    fresh_needle.guid = existing.guid
    return fresh_needle
  end

  -- Create new needle with fresh GUID
  fresh_needle.guid = fresh_needle.guid or reaper.genGuid('')
  self:log("Created new needle with GUID: " .. fresh_needle.guid)
  return fresh_needle
end

function NeedleGenerator:ensure_navigation_path(needle, material)
  needle.navigation = needle.navigation or {}
  if not needle.navigation[1] or needle.navigation[1] ~= material.name then
    table.insert(needle.navigation, 1, material.name)
  end
end

function NeedleGenerator:persist_material_needles(material_guid, deduplicated_needles, existing_count)
  local material_storage = self:get_material_storage(material_guid)
  material_storage:set(deduplicated_needles)

  self:update_session_index(material_guid, #deduplicated_needles)

  self:log(string.format("Material %s: %d needles (%d existing, %d new)",
    material_guid, #deduplicated_needles,
    existing_count, #deduplicated_needles - existing_count))
end

function NeedleGenerator:update_session_index(material_guid, needle_count)
  local index = self.needles_index:get()

  index[material_guid] = {
    needle_count = needle_count,
    last_updated = os.time(),
  }

  self.needles_index:set(index)
end

function NeedleGenerator:session_storage_location()
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function NeedleGenerator:get_storage()
  local json_file = self:session_storage_location() .. '/needles.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  })
end

function NeedleGenerator:material_storage_location(material_guid)
  assert(material_guid, 'NeedleGenerator:material_storage_location: material_guid is required')

  return ('%s/needles/%s.json'):format(self:session_storage_location(), material_guid)
end

function NeedleGenerator:get_material_storage(material_guid)
  assert(material_guid, 'NeedleGenerator:get_material_storage: material_guid is required')

  local storage_location = self:material_storage_location(material_guid)

  return Storage.ProjectJSON(storage_location, {
    schema_version = 1,
    migrations = {}
  }):table('needles', {})
end