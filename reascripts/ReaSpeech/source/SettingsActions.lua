--[[

  SettingsActions - action definitions for SettingsPlugin

]]--

SettingsActions = Polo {
  new = function(plugin)
    return {
      plugin = plugin
    }
  end,
}

function SettingsActions:init()
  assert(self.plugin, 'SettingsActions: plugin is required')
  Logging.init(self, 'SettingsActions')
end

function SettingsActions:actions()
  return {}
end