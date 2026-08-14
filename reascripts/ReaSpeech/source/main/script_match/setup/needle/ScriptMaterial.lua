
ScriptMaterial = Polo {}

function ScriptMaterial:init()
  Logging().init(self, 'ScriptMaterial')

  assert(self.session_id, 'ScriptMaterial: session_id is required')
  assert(self.material, 'ScriptMaterial: material is required')
  assert(self.materials, 'ScriptMaterial: materials is required')

  self:log("Initialized ScriptMaterial")
end

function ScriptMaterial:needles()
  self:log("Generating needles for material: " .. dump(self.material))

  local handler = self.materials:find_handler(self.material.type)

  if not handler then
    self:log("No handler found for material: " .. dump(self.material))
    return {}
  end

  local instance = handler.new {
    session_id = self.session_id,
    config = self.materials:get_material_storage(self.material.guid):get(),
  }

  return instance:needles()
end