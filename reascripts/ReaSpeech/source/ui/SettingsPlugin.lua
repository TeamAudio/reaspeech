--[[

  SettingsPlugin.lua - plugin to manage basic ReaSpeech settings

]]--

SettingsPlugin = Plugin {
  PLUGIN_KEY = 'settings',
}

function SettingsPlugin:init()
  assert(self.app, 'SettingsPlugin: plugin host app is required')
  Logging().init(self, 'SettingsPlugin')
  self._controls = SettingsControls.new(self)
  self._actions = SettingsActions.new(self)
end

---@diagnostic disable-next-line: duplicate-set-field
function SettingsPlugin:key()
  return self.PLUGIN_KEY
end