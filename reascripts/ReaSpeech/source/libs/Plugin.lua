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

  function plugin:tabs()
    if not self._controls then return {} end

    return self._controls:tabs()
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
