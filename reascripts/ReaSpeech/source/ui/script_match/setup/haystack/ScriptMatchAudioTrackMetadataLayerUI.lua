
ScriptMatchAudioTrackMetadataLayerUI = Polo {}

function ScriptMatchAudioTrackMetadataLayerUI:init()
  Logging().init(self, 'ScriptMatchAudioTrackMetadataLayerUI')

  assert(self.session_id, 'ScriptMatchAudioTrackMetadataLayerUI: session_id is required')
  assert(self.workflow, 'ScriptMatchAudioTrackMetadataLayerUI: workflow is required')
  assert(self.layer, 'ScriptMatchAudioTrackMetadataLayerUI: layer is required')
  assert(self.track, 'ScriptMatchAudioTrackMetadataLayerUI: track is required')
  assert(self.track_configuration_ui, 'ScriptMatchAudioTrackMetadataLayerUI: track_configuration_ui is required')

  self.layer_handlers = {
    [TranscriptMetadataLayer.key] = AudioTrackTranscriptMetadataLayerUI,
    [TagsMetadataLayer.key] = AudioTrackTagsMetadataLayerUI,
  }

  self.handler = self:get_handler()

  self:log("Initialized ScriptMatchAudioTrackMetadataLayerUI")
end

function ScriptMatchAudioTrackMetadataLayerUI:metadata_name()
  return self.handler:name()
end

function ScriptMatchAudioTrackMetadataLayerUI:get_handler()
  local handler = self.layer_handlers[self.layer.key]
  if not handler then
    self:log("No handler found for layer: " .. dump(self.layer))
    return {key = "unknown", render = function() end, name = function() return "Unknown" end}
  end

  return handler.new {
    session_id = self.session_id,
    workflow = self.workflow,
    layer = self.layer,
    track = self.track,
    track_configuration_ui = self.track_configuration_ui,
  }
end

-- The section headers in the configuration dialog carry the layer
-- vocabulary now; the wrapper just delegates
function ScriptMatchAudioTrackMetadataLayerUI:render()
  self.handler:render()
end