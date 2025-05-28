--[[

  SettingsControls.lua - control definitions for SettingsPlugin

]]--

SettingsControls = PluginControls {
  tabs = function(self)
    return {
      ReaSpeechPlugins.tab(
        SettingsPlugin.PLUGIN_KEY,
        'Settings',
        function() self.layout:render() end,
        {
          will_close = function()
            return true
          end,
          on_close = function()
            app.plugins:remove_plugin(self.plugin)
          end
        }
      ),
    }
  end
}

function SettingsControls:init()
  assert(self.plugin, 'SettingsControls: plugin is required')
  Logging().init(self, 'SettingsControls')

  self.font_size = Widgets.NumberInput.new {
    state = Fonts.size,
    label = 'Font Size',
  }

  self:init_logging()
  self:init_layout()
end

function SettingsControls:init_layout()
  local renderers = { self.render_font_size, self.render_logging }

  self.layout = ColumnLayout.new {
    column_padding = ReaSpeechControlsUI.COLUMN_PADDING,
    margin_bottom = ReaSpeechControlsUI.MARGIN_BOTTOM,
    margin_left = ReaSpeechControlsUI.MARGIN_LEFT,
    margin_right = ReaSpeechControlsUI.MARGIN_RIGHT,
    num_columns = 5,

    render_column = function (column)
      if renderers[column.num] then
        ImGui.PushItemWidth(Ctx(), column.width)
        Trap(function () renderers[column.num](self, column) end)
        ImGui.PopItemWidth(Ctx())
      end
    end
  }
end

function SettingsControls:init_logging()
  self.log_enable = Widgets.Checkbox.new {
    state = Logging().show_logs,
    label_long = 'Enable',
    label_short = 'Enable',
  }

  self.log_debug = Widgets.Checkbox.new {
    state = Logging().show_debug_logs,
    label_long = 'Debug',
    label_short = 'Debug',
  }
end

function SettingsControls:render_font_size()
  self.font_size:render()
end

function SettingsControls:render_logging()
  ReaSpeechControlsUI:render_input_label('Logging')

  self.log_enable:render()
  ImGui.SameLine(Ctx())

  Widgets.disable_if(not self.log_enable:value(), function ()
    self.log_debug:render()
  end)
end
