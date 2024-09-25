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
  self:init_tabs()
end

function ReaSpeechPlugins:init_plugins()
  self._plugins = {}
  for _, plugin in ipairs(self.plugins) do
    table.insert(self._plugins, plugin.new(self.app))
  end
end

function ReaSpeechPlugins:tabs()
  return self._tabs
end

function ReaSpeechPlugins:init_tabs()
  self._tabs = {}

  for _, plugin in ipairs(self._plugins) do
    for _, tab in ipairs(plugin:tabs()) do
      table.insert(self._tabs, tab)
    end
  end
end

function ReaSpeechPlugins.tab(key, label, renderer)
  return {
    tab = ReaSpeechTabBar.tab(key, label),
    render = renderer,
    is_selected = function(_, selected_key) return key == selected_key end
  }
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