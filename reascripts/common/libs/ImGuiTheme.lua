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

ImGuiTheme.__index = ImGuiTheme
ImGuiTheme.new = function(theme_definition)
  local theme = {
    colors = ImGuiTheme.get_attribute_values(theme_definition.colors),
    styles = ImGuiTheme.get_attribute_values(theme_definition.styles),
  }

  theme.color_count = #theme.colors
  theme.style_count = #theme.styles

  setmetatable(theme, ImGuiTheme)

  theme:init()

  return theme
end

function ImGuiTheme:init()
  self.f_color_push = ImGuiTheme.get_function('f_color_push', reaper.ImGui_PushStyleColor)
  self.f_color_pop = ImGuiTheme.get_function('f_color_pop', reaper.ImGui_PopStyleColor)
  self.f_style_push = ImGuiTheme.get_function('f_style_push', reaper.ImGui_PushStyleVar)
  self.f_style_pop = ImGuiTheme.get_function('f_style_pop', reaper.ImGui_PopStyleVar)
end

ImGuiTheme.get_attribute_values = function(raw_attributes)
  raw_attributes = raw_attributes or {}

  local attrs = {}

  for _, v in ipairs(raw_attributes) do
    if (type(v[1]) == "function") then
      v[1] = v[1]()
    end

    table.insert(attrs, v)
  end

  return attrs
end

ImGuiTheme.get_function = function(key, default)
  return ImGuiTheme[key] or default
end

function ImGuiTheme:push(ctx)
  for i = 1, self.color_count do
    self.f_color_push(ctx, self.colors[i][1], table.unpack(self.colors[i], 2))
  end

  for i = 1, self.style_count do
    self.f_style_push(ctx, self.styles[i][1], table.unpack(self.styles[i], 2))
  end
end

function ImGuiTheme:pop(ctx)
  self.f_color_pop(ctx, self.color_count)
  self.f_style_pop(ctx, self.style_count)
end
