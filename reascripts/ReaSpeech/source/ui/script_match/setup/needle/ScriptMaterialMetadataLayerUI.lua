
ScriptMaterialMetadataLayerUI = Polo {}

function ScriptMaterialMetadataLayerUI:init()
  Logging().init(self, 'ScriptMaterialMetadataLayerUI')

  assert(self.session_id, 'ScriptMaterialMetadataLayerUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialMetadataLayerUI: workflow is required')
  assert(self.layer, 'ScriptMaterialMetadataLayerUI: layer is required')

  self.handler = self:get_handler()

  self:log("Initialized ScriptMaterialMetadataLayerUI for layer: " .. dump(self.layer))
end

function ScriptMaterialMetadataLayerUI:available_handlers()
  if self.layer_handlers then
    return self.layer_handlers
  end

  self.layer_handlers = {
    [TagsMetadataLayer.key] = ScriptMaterialTagsMetadataLayerUI,
  }

  return self.layer_handlers
end

function ScriptMaterialMetadataLayerUI:metadata_name()
  return self.handler:name()
end

function ScriptMaterialMetadataLayerUI:get_handler()
  local handler = self:available_handlers()[self.layer.key]
  if not handler then
    self:log("No handler found for layer: " .. dump(self.layer))
    return {key = "unknown", render = function() end, name = function() return "Unknown" end}
  end

  return handler.new {
    session_id = self.session_id,
    workflow = self.workflow,
    layer = self.layer,
    material = self.material,
    sheet_config = self.sheet_config,
    material_configuration_ui = self.material_configuration_ui,
    column_labels = self.column_labels,
    on_remove = self.on_remove,
  }
end

-- The section headers in the worksheet UI carry the layer vocabulary
-- now; the wrapper just delegates
function ScriptMaterialMetadataLayerUI:render()
  self.handler:render()
end