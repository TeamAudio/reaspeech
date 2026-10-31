--[[

  WhisperModels.lua - A list of models supported by the Whisper API

]]--

WhisperModels = {
  MODELS = {
    { name = 'small', label = 'Small' },
    { name = 'medium', label = 'Medium' },
    { name = 'large-v3', label = 'Large v3' },
    { name = 'large-v3-turbo', label = 'Large v3 Turbo' },
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
