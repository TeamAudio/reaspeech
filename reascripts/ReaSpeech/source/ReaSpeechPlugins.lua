--[[

  ReaSpeechPlugins.lua - ReaSpeech plugin manager

]]--

ReaSpeechPlugins = Polo {
  plugins = {},
  new = function(app, plugins)
    return {
      app = app,
      plugins = plugins,
    }
  end
}

function ReaSpeechPlugins:init()
  assert(self.app, 'ReaSpeechPlugins: plugin host app is required')
  assert(self.plugins, 'ReaSpeechPlugins: plugins is required')

  Logging.init(self, 'ReaSpeechPlugins')

  self:init_plugins()
end

function ReaSpeechPlugins:init_plugins()
  self._plugins = {}
  for _, plugin in ipairs(self.plugins) do
    local p = plugin.new(self.app)
    table.insert(self._plugins, p)
  end
end

function ReaSpeechPlugins:tabs()
  local tabs = {}

  for _, plugin in ipairs(self._plugins) do
    for _, tab in ipairs(plugin:tabs()) do
      table.insert(tabs, tab)
    end
  end

  return tabs
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