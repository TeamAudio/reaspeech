--[[

  SampleMultipleUploadControls.lua - controls definition for SampleMultipleUploadPlugin

]]--

SampleMultipleUploadControls = PluginControls {
  tabs = function(self)
    return {
      ReaSpeechPlugins.tab('sample-multiple-uploader', 'Multiple Uploader',
      function() self._layout:render() end)
    }
  end
}

function SampleMultipleUploadControls:init()
  assert(self.plugin, 'SampleMultipleUploadControls: plugin is required')
  Logging().init(self, 'SampleMultipleUploadControls')

  self.upload_file1 = Widgets.FileSelector.new({ label = 'Upload File 1' })
  self.upload_file2 = Widgets.FileSelector.new({ label = 'Upload File 2' })

  self:init_layout()
end

function SampleMultipleUploadControls:init_layout()
  self._layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = 1,

    render_column = function (column)
      ImGui.PushItemWidth(ctx, column.width)
      Trap(function () self:render_controls() end)
      ImGui.PopItemWidth(ctx)
    end
  }

  function SampleMultipleUploadControls:render_controls()
    self.upload_file1:render()
    ImGui.Dummy(ctx, 0, 5)
    self.upload_file2:render()
  end
end
