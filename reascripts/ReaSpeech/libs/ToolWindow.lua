--[[

  ToolWindow.lua - extend an object with ImGui window functionality

]]--

ToolWindow = {
  DEFAULT_TITLE = 'Tool Window',

  DEFAULT_WIDTH = 300,
  DEFAULT_HEIGHT = 200,

  POSITION_CENTER = 'center',
  POSITION_AUTOMATIC = 'automatic',
  DEFAULT_POSITION = 'center',

  DEFAULT_WINDOW_FLAGS = function()
    return 0
      | ImGui.WindowFlags_AlwaysAutoResize()
      | ImGui.WindowFlags_NoCollapse()
      | ImGui.WindowFlags_NoDocking()
  end,

  DEFAULT_THEME = function()
    return ImGuiTheme.new()
  end,
}

ToolWindow.modal = function(o, config)
  config = config or {}
  config.is_modal = true

  local original_open = o.open
  function o:open()
    ImGui.OpenPopup(ctx, o._tool_window.title)

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
    title = config.title or ToolWindow.DEFAULT_TITLE,
    window_flags = config.window_flags or ToolWindow.DEFAULT_WINDOW_FLAGS(),
    width = config.width or ToolWindow.DEFAULT_WIDTH,
    height = config.height or ToolWindow.DEFAULT_HEIGHT,
    is_modal = config.is_modal and true,
    begin_f = config.is_modal and ImGui.BeginPopupModal or ImGui.Begin,
    end_f = config.is_modal and ImGui.EndPopup or ImGui.End,
    theme = config.theme or ToolWindow.DEFAULT_THEME(),
    position = config.position or ToolWindow.POSITION_CENTER,
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

    if self._tool_window.position == ToolWindow.POSITION_CENTER then
      local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(o.ctx))}
      ImGui.SetNextWindowPos(o.ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
    elseif type(self._tool_window.position) == 'table' and #self._tool_window.position == 2 then
      local position = self._tool_window.position
      ImGui.SetNextWindowPos(o.ctx, position[1], position[2], ImGui.Cond_Appearing())
    end

    ImGui.SetNextWindowSize(o.ctx, o._tool_window.width, o._tool_window.height, ImGui.Cond_FirstUseEver())

    o._tool_window.theme:wrap(o.ctx, function()
      local visible, open = o._tool_window.begin_f(o.ctx, o._tool_window.title, true, o._tool_window.window_flags)
      if visible then
        app:trap(function ()
          self:render_content()
        end)
        o._tool_window.end_f(o.ctx)
      else
        if not (o._tool_window.window_flags & ImGui.WindowFlags_NoCollapse()) then
          self:close()
        end
      end

      if not open then
        self:close()
      end
    end, function(f) return app:trap(f) end)
  end

  function o:render_separator()
    ImGui.Dummy(ctx, 0, 0)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 0)
  end
end