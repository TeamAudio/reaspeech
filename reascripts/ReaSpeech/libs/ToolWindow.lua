--[[

  ToolWindow.lua - extend an object with ImGui window functionality

]]--

ToolWindow = {}

ToolWindow.init = function(o, config)
  config = config or {}

  o._tool_window = {
    is_open = false,
    title = config.title or 'Tool Window',
    window_flags = config.window_flags or 0,
    width = config.width or 300,
    height = config.height or 200,
  }

  local original_open = o.open
  function o:open()
    self._tool_window.is_open = true
    if original_open then
      original_open(self)
    end
  end

  local original_close = o.close
  function o:close()
    self._tool_window.is_open = false
    if original_close then
      original_close(self)
    end
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