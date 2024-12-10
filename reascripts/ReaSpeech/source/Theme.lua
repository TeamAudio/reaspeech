--[[

  Theme.lua - Theme configuration

]]--

Theme = {
  COLORS = {
    black_near_transparent = 0x000000E8,
    dark_blue_gray_opaque = 0x4A5459FF,
    dark_gray_opaque = 0x404040FF,
    dark_gray_semi_opaque = 0x404040FB,
    dark_gray_semi_transparent = 0x4040408A,
    dark_gray_translucent = 0x2B2B2B8A,
    medium_gray_opaque = 0x5C5C5CFF,
    pink_opaque = 0xE24097FF,
    very_dark_gray_semi_opaque = 0x1A1A1AFB,
  }
}

function Theme:init()
  self.main = ImGuiTheme.new {
    colors = {
      { ImGui.Col_Border, self.COLORS.black_near_transparent },
      { ImGui.Col_Button, self.COLORS.medium_gray_opaque },
      { ImGui.Col_ButtonActive, self.COLORS.dark_gray_opaque },
      { ImGui.Col_ButtonHovered, self.COLORS.dark_gray_translucent },
      { ImGui.Col_CheckMark, self.COLORS.pink_opaque },
      { ImGui.Col_FrameBg, self.COLORS.dark_gray_translucent },
      { ImGui.Col_FrameBgActive, self.COLORS.pink_opaque },
      { ImGui.Col_FrameBgHovered, self.COLORS.dark_gray_translucent },
      { ImGui.Col_Header, self.COLORS.dark_gray_semi_opaque },
      { ImGui.Col_HeaderActive, self.COLORS.dark_gray_semi_transparent },
      { ImGui.Col_HeaderHovered, self.COLORS.dark_gray_semi_opaque },
      { ImGui.Col_Tab, self.COLORS.dark_gray_opaque },
      { ImGui.Col_TabActive, self.COLORS.medium_gray_opaque },
      { ImGui.Col_TabHovered, self.COLORS.dark_gray_translucent },
      { ImGui.Col_TabSelected, self.COLORS.medium_gray_opaque },
      { ImGui.Col_TitleBg, self.COLORS.dark_gray_semi_opaque },
      { ImGui.Col_TitleBgActive, self.COLORS.dark_blue_gray_opaque },
      { ImGui.Col_WindowBg, self.COLORS.dark_gray_semi_opaque },
    },

    styles = {
      { ImGui.StyleVar_FrameBorderSize, 1.0 },
      { ImGui.StyleVar_FramePadding, 10.0, 6.0 },
      { ImGui.StyleVar_FrameRounding, 12.0 },
      { ImGui.StyleVar_GrabRounding, 4.0 },
      { ImGui.StyleVar_PopupBorderSize, 1.0 },
      { ImGui.StyleVar_WindowBorderSize, 1.0 },
    }
  }

  self.popup = ImGuiTheme.new {
    colors = {
      { ImGui.Col_WindowBg, self.COLORS.very_dark_gray_semi_opaque },
    },

    styles = {
      { ImGui.StyleVar_Alpha, 1.0 },
    }
  }
end
