--[[

  WhisperModels.lua - A list of models supported by the Whisper API

]]--

WhisperModels = {
  MODELS = {
    { name = 'tiny', label = 'Tiny', not_engine = 'mlx_whisper' },
    { name = 'tiny.en', label = 'Tiny', lang = 'en', not_engine = 'mlx_whisper' },
    { name = 'base', label = 'Base', not_engine = 'mlx_whisper' },
    { name = 'base.en', label = 'Base', lang = 'en', not_engine = 'mlx_whisper' },
    { name = 'small', label = 'Small', not_engine = 'mlx_whisper' },
    { name = 'small.en', label = 'Small', lang = 'en', not_engine = 'mlx_whisper' },
    { name = 'medium', label = 'Medium', not_engine = 'mlx_whisper' },
    { name = 'medium.en', label = 'Medium', lang = 'en', not_engine = 'mlx_whisper' },
    { name = 'large', label = 'Large', not_engine = 'mlx_whisper' },
    { name = 'large-v1', label = 'Large v1', not_engine = 'mlx_whisper' },
    { name = 'large-v2', label = 'Large v2', not_engine = 'mlx_whisper' },
    { name = 'large-v3', label = 'Large v3', not_engine = 'mlx_whisper' },
    { name = 'large-v3-turbo', label = 'Large v3 Turbo', not_engine = 'mlx_whisper' },
    { name = 'distil-small.en', label = 'Distil Small', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-medium.en', label = 'Distil Medium', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-large-v2', label = 'Distil Large v2', lang = 'en', engine = 'faster_whisper' },
    { name = 'distil-large-v3', label = 'Distil Large v3', lang = 'en', engine = 'faster_whisper' },
    { name = 'mlx-community/whisper-small-mlx', label = 'MLX Small', lang = 'en', engine = 'mlx_whisper' },
    { name = 'mlx-community/whisper-medium-mlx', label = 'MLX Medium', lang = 'en', engine = 'mlx_whisper' },
    { name = 'mlx-community/whisper-large-mlx', label = 'MLX Large', lang = 'en', engine = 'mlx_whisper' },
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
      if model.not_engine ~= engine then
        table.insert(names, model.name)
      end
    end
  end

  return names
end
