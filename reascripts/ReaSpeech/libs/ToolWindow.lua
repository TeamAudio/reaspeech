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

  ToolWindow._wrap_method(o, 'open', function()
    ImGui.OpenPopup(o.ctx, o._tool_window.title)
  end)

  ToolWindow._wrap_method(o, 'close', function()
    ImGui.CloseCurrentPopup(o.ctx)
  end)

   ToolWindow.init(o, config)
end

ToolWindow.init = function(o, config)
  Logging.init(o, 'ToolWindow')
  config = config or {}

  o.ctx = config.ctx or ctx

  local state = ToolWindow._make_config(o, config)
  o._tool_window = state

  ToolWindow._wrap_method(o, 'open', function()
    state.is_open = true
  end)

  ToolWindow._wrap_method(o, 'close', function()
    state.is_open = false
  end)

  o.is_open = ToolWindow.is_open

  o.render = ToolWindow.render

  o.render_separator = ToolWindow.render_separator
end

function ToolWindow._make_config(o, config)
  config = config or {}
  return {
    guard = config.guard or function() return o:is_open() end,
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
end

function ToolWindow._wrap_method(o, method_name, f)
  local original = o[method_name]
  o[method_name] = function()
    f()
    if original then
      original(o)
    end
  end
end

function ToolWindow.is_open(o)
  return o._tool_window.is_open
end

function ToolWindow.render(o)
  local state = o._tool_window

  if not state.guard() then
    return
  end

  local opening = not o:is_open()
  if opening then
    o:open()
  end

  if state.position == ToolWindow.POSITION_CENTER then
    local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(o.ctx))}
    ImGui.SetNextWindowPos(o.ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
  elseif type(state.position) == 'table' and #state.position == 2 then
    local position = state.position
    ImGui.SetNextWindowPos(o.ctx, position[1], position[2], ImGui.Cond_Appearing())
  end

  ImGui.SetNextWindowSize(o.ctx, state.width, state.height, ImGui.Cond_FirstUseEver())

  state.theme:wrap(o.ctx, function()
    local visible, open = state.begin_f(o.ctx, state.title, true, state.window_flags)
    if visible then
      app:trap(function ()
        if o.render_content then
          o:render_content()
        end
      end)
      state.end_f(o.ctx)
    else
      if not (state.window_flags & ImGui.WindowFlags_NoCollapse()) then
        o:close()
      end
    end

    if not open then
      o:close()
    end
  end, function(f) return app:trap(f) end)
end

function ToolWindow.render_separator(o)
  ImGui.Dummy(o.ctx, 0, 0)
  ImGui.Separator(o.ctx)
  ImGui.Dummy(o.ctx, 0, 0)
end
