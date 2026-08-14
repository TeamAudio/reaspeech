
TranscriptMetadataLayer = Polo {
  name = 'Transcript',
  key = 'transcript',
  description = 'Layer for managing transcript metadata',
  maximum_layers = 1,

  TRANSCRIPT_SOURCES = {
    generated = 'Generated',
    imported = 'Imported',
  },
}

function TranscriptMetadataLayer:init()
  Logging().init(self, 'TranscriptMetadataLayer')

  assert(self.track, 'TranscriptMetadataLayer: track is required')
end

