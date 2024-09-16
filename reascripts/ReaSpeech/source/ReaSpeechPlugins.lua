--[[

  ReaSpeechPlugins.lua - ReaSpeech plugin manager

]]--

ReaSpeechPlugins = Polo {
  plugins = {},
}

function ReaSpeechPlugins:init()
  assert(self.plugins, 'ReaSpeechPlugins: plugins is required')

  Logging.init(self, 'ReaSpeechPlugins')

  self:init_plugins()
end

function ReaSpeechPlugins:init_plugins()
  self._plugins = {}
  for _, plugin in ipairs(self.plugins) do
    local p = plugin.new()
    table.insert(self._plugins, p)
  end
end

function ReaSpeechPlugins:actions()
  local actions = {}

  for _, plugin in ipairs(self._plugins) do
    for _, action in ipairs(plugin:actions()) do
      table.insert(actions, action)
    end
  end

  return actions
end