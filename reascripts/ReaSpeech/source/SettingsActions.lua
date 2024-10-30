--[[

  SettingsActions - action definitions for SettingsPlugin

]]--

SettingsActions = PluginActions {}

function SettingsActions:init()
  assert(self.plugin, 'SettingsActions: plugin is required')
  Logging.init(self, 'SettingsActions')
end
