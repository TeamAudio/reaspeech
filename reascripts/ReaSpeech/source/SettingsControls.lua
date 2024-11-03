--[[

  SettingsControls.lua - control definitions for SettingsPlugin

]]--

SettingsControls = PluginControls {
  tabs = function(self)
    return {
      ReaSpeechPlugins.tab('settings-general', 'ReaSpeech Settings',
        function() self.layout:render() end),
    }
  end
}

function SettingsControls:init()
  assert(self.plugin, 'SettingsControls: plugin is required')
  Logging.init(self, 'SettingsControls')

  self.log_enable = ReaSpeechCheckbox.simple(false, 'Enable', function(current)
    Logging.show_logs:set(current)
  end)

  self.log_debug = ReaSpeechCheckbox.simple(false, 'Debug', function(current)
    Logging.show_debug_logs:set(current)
  end)

  self:init_layout()
end

function SettingsControls:init_layout()
  local renderers = { self.render_logging }

  self.layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = #renderers,

    render_column = function (column)
      ImGui.PushItemWidth(ctx, column.width)
      app:trap(function () renderers[column.num](self, column) end)
      ImGui.PopItemWidth(ctx)
    end
  }
end

function SettingsControls:render_logging()
  ReaSpeechControlsUI:render_input_label('Logging')

  self.log_enable:render()

  if self.log_enable:value() then
    ImGui.SameLine(ctx)
    self.log_debug:render()
  end
end
