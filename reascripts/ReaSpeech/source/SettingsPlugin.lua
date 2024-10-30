--[[

  SettingsPlugin.lua - plugin to manage basic ReaSpeech settings

]]--

SettingsPlugin = Plugin {}

function SettingsPlugin:init()
  assert(self.app, 'SettingsPlugin: plugin host app is required')
  Logging.init(self, 'SettingsPlugin')
  self._controls = SettingsControls.new(self)
  self._actions = SettingsActions.new(self)
end
