--[[

  DetectLanguageControls.lua - DetectLanguage controls definitions

]]--

DetectLanguageControls = Polo {
  new = function(plugin)
    return {
      plugin = plugin
    }
  end,
}

function DetectLanguageControls:init()
  assert(self.plugin, 'DetectLanguageControls: plugin is required')
  Logging.init(self, 'DetectLanguageControls')
end

function DetectLanguageControls:tabs()
  return {}
end