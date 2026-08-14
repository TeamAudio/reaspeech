

TagsMetadataLayer = Polo {
  name = 'Tags',
  key = 'tags',
  description = 'Layer for managing tags metadata',

  PREDEFINED_TAGS = {
    character = 'Character',
    location = 'Location',
    emotion = 'Emotion',
    custom = 'Custom Tag',
  },

  -- Auto-match candidates in assist order ('custom' has no fixed label
  -- to match against)
  AUTO_MATCH_TAGS = { 'character', 'location', 'emotion' },
}

-- Case-insensitive, trimmed match of a predefined tag's label against
-- the sheet's column headers; returns the column index or nil
function TagsMetadataLayer.find_matching_column(tag_key, column_labels)
  local label = TagsMetadataLayer.PREDEFINED_TAGS[tag_key]
  if not label or tag_key == 'custom' then return nil end

  local wanted = label:lower()
  for i, header in ipairs(column_labels or {}) do
    if type(header) == 'string' and header:match('^%s*(.-)%s*$'):lower() == wanted then
      return i
    end
  end

  return nil
end

function TagsMetadataLayer:init()
  Logging().init(self, 'TagsMetadataLayer')

  assert(self.track, 'TagsMetadataLayer: track is required')
end
