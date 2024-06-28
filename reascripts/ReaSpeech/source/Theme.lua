Theme = {
  theme = nil,
  colors = {
    dark_gray_semi_transparent = 0x404040FB,
    black_near_transparent = 0x000000E8,
    medium_gray_opaque = 0x5C5C5CFF,
    dark_gray_translucent = 0x2B2B2B8A,
    dark_gray_opaque = 0x404040FF,
    dark_blue_gray_opaque = 0x4A5459FF,
    pink_opaque = 0xE24097FF,
    dark_gray_semi_opaque = 0x404040FB,
  }
}
setmetatable(Theme, { __call = function () return Theme.init() end })

function Theme.init()
  if Theme.theme ~= nil then
    return Theme.theme
  end

  Theme.theme = ImGuiTheme.new({
    colors = {
      { ImGui.Col_WindowBg(), Theme.colors.dark_gray_semi_transparent },
      { ImGui.Col_Border(), Theme.colors.black_near_transparent },
      { ImGui.Col_Button(), Theme.colors.medium_gray_opaque },
      { ImGui.Col_ButtonHovered(), Theme.colors.dark_gray_translucent },
      { ImGui.Col_ButtonActive(), Theme.colors.dark_gray_opaque },
      { ImGui.Col_TitleBg(), Theme.colors.dark_gray_semi_transparent },
      { ImGui.Col_TitleBgActive(), Theme.colors.dark_blue_gray_opaque },
      { ImGui.Col_FrameBg(), Theme.colors.dark_gray_translucent },
      { ImGui.Col_FrameBgHovered(), Theme.colors.dark_gray_translucent },
      { ImGui.Col_FrameBgActive(), Theme.colors.pink_opaque },
      { ImGui.Col_CheckMark(), Theme.colors.pink_opaque },
      { ImGui.Col_HeaderHovered(), Theme.colors.dark_gray_semi_opaque },
      { ImGui.Col_HeaderActive(), Theme.colors.dark_gray_semi_transparent },
      { ImGui.Col_Header(), Theme.colors.dark_gray_semi_opaque },
      { ImGui.Col_Tab(), Theme.colors.dark_gray_opaque },
      { ImGui.Col_TabActive(), Theme.colors.medium_gray_opaque },
      { ImGui.Col_TabHovered(), Theme.colors.dark_gray_translucent },
    },

    styles = {
      { ImGui.StyleVar_FramePadding(), 10.0, 6.0 },
      { ImGui.StyleVar_FrameRounding(), 12.0 },
      { ImGui.StyleVar_GrabRounding(), 4.0 },
      { ImGui.StyleVar_FrameBorderSize(), 1.0 },
      { ImGui.StyleVar_WindowBorderSize(), 1.0 },
      { ImGui.StyleVar_PopupBorderSize(), 1.0 }
    }
  })

  return Theme.theme
end
