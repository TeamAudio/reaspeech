--[[

  WhisperModels.lua - A list of models supported by the Whisper API

]]--

WhisperModels = {
  MODELS = {
    { name = 'tiny', label = 'Tiny' },
    { name = 'tiny.en', label = 'Tiny', lang = 'en' },
    { name = 'base', label = 'Base' },
    { name = 'base.en', label = 'Base', lang = 'en' },
    { name = 'small', label = 'Small' },
    { name = 'small.en', label = 'Small', lang = 'en' },
    { name = 'medium', label = 'Medium' },
    { name = 'medium.en', label = 'Medium', lang = 'en' },
    { name = 'large', label = 'Large' },
    { name = 'large-v1', label = 'Large v1' },
    { name = 'large-v2', label = 'Large v2' },
    { name = 'large-v3', label = 'Large v3', engine = 'faster_whisper' },
    { name = 'distil-small.en', label = 'Distil Small', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-medium.en', label = 'Distil Medium', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-large-v2', label = 'Distil Large v2', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-large-v3', label = 'Distil Large v3', lang = 'en', engine = 'faster_whisper' },
  },
}

function WhisperModels.get_model_by_name(name)
  for _, model in pairs(WhisperModels.MODELS) do
    if model.name == name then
      return model
    end
  end
end

function WhisperModels.get_model_names(engine)
  local names = {}

  for _, model in pairs(WhisperModels.MODELS) do
    if model.engine then
      if model.engine == engine then
        table.insert(names, model.name)
      end
    else
      table.insert(names, model.name)
    end
  end

  return names
end
