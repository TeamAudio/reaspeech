--[[

  ScriptMatchPlugin.lua - Script matching plugin for ReaSpeech

  Integrates with the ScriptMaterial system for modular script material loading and matching.

]]--

ScriptMatchPlugin = Plugin {
  PLUGIN_KEY = 'script-match',
}

function ScriptMatchPlugin:init()
  assert(self.app, 'ScriptMatchPlugin: plugin host app is required')
  Logging().init(self, 'ScriptMatchPlugin')

  self._controls = ScriptMatchControls.new(self)
  self._actions = ScriptMatchActions.new(self)

  self.storage = Storage.ProjectJSON('reaspeech/script_match.json', {
    schema_version = 1,
    migrations = {}
  })

end

function ScriptMatchPlugin:key()
  return self.PLUGIN_KEY
end
