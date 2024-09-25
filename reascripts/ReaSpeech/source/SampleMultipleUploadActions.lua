--[[

  SampleMultipleUploadActions.lua - Action definitions for SampleMultipleUploadPlugin

]]--

SampleMultipleUploadActions = PluginActions {
  actions = function(self)
    return {
      self._button,
    }
  end
}

function SampleMultipleUploadActions:init()
  assert(self.plugin, 'SampleMultipleUploadActions: plugin is required')
  Logging.init(self, 'SampleMultipleUploadActions')

  self._button = ReaSpeechButton.new({
    label = 'Upload files',
    on_click = function()
      self.plugin:upload_files()
    end
  })
end
