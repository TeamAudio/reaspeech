--[[

  SettingsPlugin.lua - plugin to manage basic ReaSpeech settings

]]--

SettingsPlugin = Polo {
  new = function(app)
    return {
      app = app
    }
  end,
}

function SettingsPlugin:init()
  assert(self.app, 'SettingsPlugin: plugin host app is required')
  Logging.init(self, 'SettingsPlugin')
  self._controls = SettingsControls.new(self)
  self._actions = SettingsActions.new(self)
end

function SettingsPlugin:tabs()
  return self._controls:tabs()
end

function SettingsPlugin:actions()
  return self._actions:actions()
end
