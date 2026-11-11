--[[

  Theme.lua - Theme configuration

]]--

Theme = {
  COLORS = {
    body = 0x212529FF,
    surface = 0x2B3035FF,
    border = 0x495057FF,
    text = 0xDEE2E6FF,
    muted = 0xADB5BDFF,
    secondary = 0x6C757DFF,
    secondary_hover = 0x5C636AFF,
    secondary_active = 0x565E64FF,
    primary = 0x0D6EFDFF,
    primary_hover = 0x0B5ED7FF,
    primary_active = 0x0A58CAFF,
    link = 0x6EA8FEFF,
    bold_red = 0xEA868FFF,
    pink_opaque = 0xE24097FF,
  }
}

function Theme:init()
  local colors = self.COLORS

  self.main = ImGuiTheme.new {
    colors = {
      { ImGui.Col_Text, colors.text },
      { ImGui.Col_TextDisabled, colors.muted },
      { ImGui.Col_Border, colors.border },
      { ImGui.Col_Button, colors.secondary },
      { ImGui.Col_ButtonActive, colors.secondary_active },
      { ImGui.Col_ButtonHovered, colors.secondary_hover },
      { ImGui.Col_CheckMark, colors.pink_opaque },
      { ImGui.Col_FrameBg, colors.body },
      { ImGui.Col_FrameBgActive, colors.border },
      { ImGui.Col_FrameBgHovered, colors.surface },
      { ImGui.Col_Header, colors.surface },
      { ImGui.Col_HeaderActive, colors.primary_active },
      { ImGui.Col_HeaderHovered, colors.border },
      { ImGui.Col_Tab, colors.body },
      { ImGui.Col_TabActive, colors.border },
      { ImGui.Col_TabHovered, colors.secondary_hover },
      { ImGui.Col_TabSelected, colors.border },
      { ImGui.Col_TitleBg, colors.body },
      { ImGui.Col_TitleBgActive, colors.surface },
      { ImGui.Col_WindowBg, colors.surface },
      { ImGui.Col_PopupBg, colors.body },
      { ImGui.Col_Separator, colors.border },
      { ImGui.Col_ScrollbarBg, colors.body },
      { ImGui.Col_ScrollbarGrab, colors.border },
      { ImGui.Col_ScrollbarGrabHovered, colors.secondary },
      { ImGui.Col_ScrollbarGrabActive, colors.muted },
      { ImGui.Col_TableHeaderBg, colors.body },
      { ImGui.Col_TableBorderStrong, colors.border },
      { ImGui.Col_TableBorderLight, colors.border },
      { ImGui.Col_TableRowBg, colors.surface },
      { ImGui.Col_TableRowBgAlt, colors.body },
      { ImGui.Col_TextSelectedBg, colors.primary_active },
      { ImGui.Col_SliderGrab, colors.link },
      { ImGui.Col_SliderGrabActive, colors.primary },
    },

    styles = {
      { ImGui.StyleVar_Alpha, 1.0 },
      { ImGui.StyleVar_FrameBorderSize, 1.0 },
      { ImGui.StyleVar_FramePadding, 10.0, 6.0 },
      { ImGui.StyleVar_FrameRounding, 6.0 },
      { ImGui.StyleVar_CellPadding, 10.0, 5.0 },
      { ImGui.StyleVar_ChildRounding, 6.0 },
      { ImGui.StyleVar_PopupRounding, 6.0 },
      { ImGui.StyleVar_TabRounding, 6.0 },
      { ImGui.StyleVar_WindowRounding, 8.0 },
      { ImGui.StyleVar_GrabRounding, 4.0 },
      { ImGui.StyleVar_ItemSpacing, 8.0, 8.0 },
      { ImGui.StyleVar_PopupBorderSize, 1.0 },
      { ImGui.StyleVar_WindowPadding, 14.0, 12.0 },
      { ImGui.StyleVar_WindowBorderSize, 1.0 },
    }
  }

  self.primary_button = ImGuiTheme.new {
    colors = {
      { ImGui.Col_Text, 0xFFFFFFFF },
      { ImGui.Col_Button, colors.primary },
      { ImGui.Col_ButtonHovered, colors.primary_hover },
      { ImGui.Col_ButtonActive, colors.primary_active },
    }
  }

  self.popup = ImGuiTheme.new {
    colors = {
      { ImGui.Col_WindowBg, colors.body },
    },

    styles = {
      { ImGui.StyleVar_Alpha, 1.0 },
    }
  }
end
