--[[

  SettingsControls.lua - control definitions for SettingsPlugin

]]--

SettingsControls = PluginControls {
  tabs = function(self)
    return {
      ReaSpeechPlugins.tab('settings-general', 'Settings',
        function() self.layout:render() end),
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
        ImGui.PushItemWidth(ctx, column.width)
        Trap(function () renderers[column.num](self, column) end)
        ImGui.PopItemWidth(ctx)
      end
    end
  }
end

function SettingsControls:init_logging()
  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.Logging',
    persist = true,
  }

  Logging().show_logs = storage:boolean('show_logs', false)
  Logging().show_debug_logs = storage:boolean('show_debug_logs', false)

  self.log_enable = Widgets.Checkbox.new {
    state = Logging.show_logs,
    label_long = 'Enable',
    label_short = 'Enable',
  }

  self.log_debug = Widgets.Checkbox.new {
    state = Logging.show_debug_logs,
    label_long = 'Debug',
    label_short = 'Debug',
  }
end

function SettingsControls:render_font_size()
  self.font_size:render()
end

function SettingsControls:render_logging()
  local disable_if = ReaUtil.disabler(ctx)

  ReaSpeechControlsUI:render_input_label('Logging')

  self.log_enable:render()
  ImGui.SameLine(ctx)

  disable_if(not self.log_enable:value(), function ()
    self.log_debug:render()
  end)
end
