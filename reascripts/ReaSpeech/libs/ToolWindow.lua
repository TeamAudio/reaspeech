--[[

  ToolWindow.lua - extend an object with ImGui window functionality

]]--

ToolWindow = {}

ToolWindow.init = function(o)
  o._tool_window = {
    is_open = false,
  }

  local original_open = o.open
  function o:open()
    self._tool_window.is_open = true
    if original_open then
      original_open(self)
    end
  end

  function o:close()
    self._tool_window.is_open = false
  end

  function o:render()
    if not self._tool_window.is_open then
      return
    end

    local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
    ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
    ImGui.SetNextWindowSize(ctx, self.WIDTH, self.HEIGHT, ImGui.Cond_FirstUseEver())

    local flags = (
      0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
    )

    local visible, open = ImGui.Begin(ctx, self.TITLE, true, flags)
    if visible then
      app:trap(function ()
        self:render_content()
      end)
      ImGui.End(ctx)
    end
    if not open then
      self:close()
    end

  end

  function o:render_separator()
    ImGui.Dummy(ctx, 0, 0)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 0)
  end
end