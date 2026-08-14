
MetadataLayers = Polo {}

function MetadataLayers:init()
  Logging().init(self, 'MetadataLayers')

  self.registry = {
    TranscriptMetadataLayer,
    TagsMetadataLayer,
    -- MediaItemMetadataLayer,
  }

  -- self:init_registry()
end

function MetadataLayers:init_registry()
  local registered = {}
  for _, layer in ipairs(self.registry) do
    table.insert(registered, layer.new())
  end
  self.registry = registered
  self:log("Registry: " .. dump(self.registry))
end