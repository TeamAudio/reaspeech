--[[

  ToolWindow.lua - extend an object with ImGui window functionality

]]--

ToolWindow = {}

ToolWindow.modal = function(o, config)
  config = config or {}
  config.is_modal = true

  local original_open = o.open
  function o:open()
    ImGui.OpenPopup(ctx, self.TITLE)

    if original_open then
      original_open(self)
    end
  end

  local original_close = o.close
  function o:close()
    if original_close then
      original_close(self)
    end

    ImGui.CloseCurrentPopup(ctx)
 end

 ToolWindow.init(o, config)
end

ToolWindow.init = function(o, config)
  Logging.init(o, 'ToolWindow')
  config = config or {}

  o.ctx = config.ctx or ctx

  o._tool_window = {
    guard = config.guard or function() return o._tool_window.is_open end,
    is_open = false,
    title = config.title or 'Tool Window',
    window_flags = config.window_flags or 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking(),
    width = config.width or 300,
    height = config.height or 200,
    is_modal = config.is_modal and true,
    begin_f = config.is_modal and ImGui.BeginPopupModal or ImGui.Begin,
    end_f = config.is_modal and ImGui.EndPopup or ImGui.End,
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
    if not self._tool_window.guard() then
      return
    end

    local opening = not self._tool_window.is_open
    if opening then
      self:open()
    end

    local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(o.ctx))}
    ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
    ImGui.SetNextWindowSize(ctx, o._tool_window.width, o._tool_window.height, ImGui.Cond_FirstUseEver())

    local visible, _ = o._tool_window.begin_f(o.ctx, o._tool_window.title, true, o._tool_window.window_flags)
    if visible then
      app:trap(function ()
        self:render_content()
      end)
      o._tool_window.end_f(o.ctx)
    else
      self:close()
    end

  end

  function o:render_separator()
    ImGui.Dummy(ctx, 0, 0)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 0)
  end
end