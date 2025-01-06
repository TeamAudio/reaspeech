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
  end,
  __call = function(self, key)
    return self:get_plugin(key)
  end,
}

function ReaSpeechPlugins:init()
  assert(self.app, 'ReaSpeechPlugins: plugin host app is required')
  assert(self.plugins, 'ReaSpeechPlugins: plugins is required')

  Logging().init(self, 'ReaSpeechPlugins')

  self:init_plugins()
  self:init_tabs()
end

function ReaSpeechPlugins:init_plugins()
  self._plugins = {}
  for _, plugin in ipairs(self.plugins) do
    table.insert(self._plugins, plugin.new(self.app))
  end
end

function ReaSpeechPlugins:get_plugin(key)
  for _, plugin in ipairs(self._plugins) do
    if plugin:key() == key then
      return plugin
    end
  end
end

function ReaSpeechPlugins:add_plugin(plugin)
  local new_plugin
  if type(plugin) == 'function' then
    new_plugin = plugin(self.app)
  else
    new_plugin = plugin
  end
  table.insert(self._plugins, new_plugin)

  self:init_tabs()
end

function ReaSpeechPlugins:remove_plugin(plugin)
  for i, p in ipairs(self._plugins) do
    if p == plugin then
      table.remove(self._plugins, i)
      break
    end
  end

  self:init_tabs()
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

function ReaSpeechPlugins.tab(key, label, renderer, tab_config)
  local tab = Widgets.TabBar.tab(key, label)

  for k, v in pairs(tab_config or {}) do
    tab[k] = v
  end

  return {
    tab = tab,
    render = renderer,
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