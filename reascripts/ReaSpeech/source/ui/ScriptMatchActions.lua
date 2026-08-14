--[[

  ScriptMatchActions.lua - Actions for script matching plugin

  Provides action buttons and menu items for script matching operations.

]]--

ScriptMatchActions = PluginActions {
  actions = function(self)
    return {}
  end
}

function ScriptMatchActions:init()
  assert(self.plugin, 'ScriptMatchActions: plugin is required')

  Logging().init(self, 'ScriptMatchActions')
end
