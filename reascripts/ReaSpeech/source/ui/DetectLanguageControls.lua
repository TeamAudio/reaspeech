--[[

  DetectLanguageControls.lua - DetectLanguage controls definitions

]]--

DetectLanguageControls = PluginControls {}

function DetectLanguageControls:init()
  assert(self.plugin, 'DetectLanguageControls: plugin is required')
  Logging().init(self, 'DetectLanguageControls')
end
