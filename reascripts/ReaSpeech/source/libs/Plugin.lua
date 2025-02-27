--[[

  Plugin.lua - Plugin class for declaring new plugins

]]--

function Plugin(definition)
  definition.new = function(plugin_host)
    return {
      app = plugin_host
    }
  end

  local plugin = Polo(definition)

  function plugin:key()
    assert('Plugin:key() must be overridden and return a string')
  end

  function plugin:tabs()
    if not self._controls then return {} end

    return self._controls:tabs()
  end

  function plugin:new_tab_menu()
    if not self._controls then return {} end

    if not self._controls.new_tab_menu then return {} end

    return self._controls:new_tab_menu()
  end

  function plugin:drop_zones(files)
    if not self._controls then return {} end

    if not self._controls.drop_zones then return {} end

    return self._controls:drop_zones(files)
  end

  function plugin:actions()
    if not self._actions then return {} end

    return self._actions:actions()
  end

  return plugin
end

function PluginAccessory(definition)
  definition.new = function(plugin)
    return {
      plugin = plugin
    }
  end

  return Polo(definition)
end

function PluginActions(definition)
  local actions = PluginAccessory(definition)

  if not actions.actions then
    function actions:actions() return {} end
  end

  return actions
end

function PluginControls(definition)
  local controls = PluginAccessory(definition)

  if not controls.tabs then
    function controls:tabs() return {} end
  end

  return controls
end
