--[[

ImGuiTheme.lua - Simple theming for the ReaImGui API

Initialize a new ImGuiTheme via `new` with a table containing (both optional):

- `colors`->(list table of { `colorKeyValueOrFunction`, `colorValue` })
- `styles`->(list table of { `styleKeyValueOrFunction`, `styleValue1` [, ...`styleValueN`] })

The Returned object contains the following methods to be used where you would have originally
called ImGui functions directly:

- `push(ctx)`: calls `ImGui_PushStyleColor` and `ImGui_PushStyleVar` for each color and style defined
- `pop(ctx)`: calls `ImGui_PopStyleColor` and `ImGui_PopStyleVar` with the correct `count` argument
]]--

ImGuiTheme = {
  -- Override the calls to the associated REAPER API methods here
  -- ...if you want to
  f_color_push = nil,
  f_color_pop = nil,
  f_style_push = nil,
  f_style_pop = nil,
}

ImGuiTheme.get_function = function(key, default)
  return ImGuiTheme[key] or default
end

ImGuiTheme.__index = ImGuiTheme
function ImGuiTheme.new(theme_definition)
  local theme = {
    color_count = 0,
    colors = {},

    style_count = 0,
    styles = {}
  }

  setmetatable(theme, ImGuiTheme)

  if (theme_definition.colors ~= nil) then
    for _, v in ipairs(theme_definition.colors) do
      if (type(v[1]) == "function") then
        v[1] = v[1]()
      end

      table.insert(theme.colors, v)
    end
  end
  theme.color_count = #theme.colors

  if (theme_definition.styles ~= nil) then
    for _, v in ipairs(theme_definition.styles) do
      if (type(v[1]) == "function") then
        v[1] = v[1]()
      end

      table.insert(theme.styles, v)
    end
  end
  theme.style_count = #theme.styles

  return theme
end

function ImGuiTheme:push(ctx)
  local f_color_push = ImGuiTheme.get_function('f_color_push', reaper.ImGui_PushStyleColor)
  for i = 1, self.color_count do
    f_color_push(ctx, self.colors[i][1], table.unpack(self.colors[i], 2))
  end

  local f_style_push = ImGuiTheme.get_function('f_style_push', reaper.ImGui_PushStyleVar)
  for i = 1, self.style_count do
    f_style_push(ctx, self.styles[i][1], table.unpack(self.styles[i], 2))
  end
end

function ImGuiTheme:pop(ctx)
  ImGuiTheme.get_function("f_color_pop", reaper.ImGui_PopStyleColor)(ctx, self.color_count)
  ImGuiTheme.get_function("f_style_pop", reaper.ImGui_PopStyleVar)(ctx, self.style_count)
end
