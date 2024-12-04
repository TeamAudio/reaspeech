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
  theme_definition = theme_definition or {}
  local theme = {
    colors = ImGuiTheme.get_attribute_values(theme_definition.colors or {}),
    styles = ImGuiTheme.get_attribute_values(theme_definition.styles or {}),
  }

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

function ImGuiTheme._attr_key(key)
  if type(key) == 'function' then
    return key()
  end

  return key
end

function ImGuiTheme._attr_row(key, value)
  key = ImGuiTheme._attr_key(key)

  if type(value) == 'table' then
    return { key, table.unpack(value) }
  end

  return { key, value }
end

function ImGuiTheme:get_color(key)
  return ImGuiTheme:_get_attr(self.colors, key)
end

function ImGuiTheme:get_style(key)
  return ImGuiTheme:_get_attr(self.styles, key)
end

function ImGuiTheme:_get_attr(attr_table, key)
  for _, v in ipairs(attr_table) do
    if v[1] == key then
      local result = { select(2, table.unpack(v)) }
      if #result == 1 then
        if type(result[1]) == 'function' then
          return result[1]()
        else
          return result[1]
        end
      else
        return result
      end
    end
  end
end

function ImGuiTheme:set_color(key, value)
  self.colors = ImGuiTheme._set_attr(self.colors, key, value)
end

function ImGuiTheme:set_style(key, value)
  self.styles = ImGuiTheme._set_attr(self.styles, key, value)
end

function ImGuiTheme._set_attr(attr_table, key, value)
  local row = ImGuiTheme._attr_row(key, value)

  local result = {}
  for _, v in ipairs(attr_table) do
    if v[1] == row[1] then
      table.insert(result, row)
    else
      table.insert(result, v)
    end
  end

  return result
end

function ImGuiTheme:push(ctx)
  self.color_count = 0
  for i = 1, #self.colors do
    if self.colors[i][1] then
      self.f_color_push(ctx, self.colors[i][1], table.unpack(self.colors[i], 2))
      self.color_count = self.color_count + 1
    end
  end

  self.style_count = 0
  for i = 1, #self.styles do
    if self.styles[i][1] then
      local args
      if type(self.styles[i][2]) == 'function' then
        args = self.styles[i][2]()
      else
        args = {table.unpack(self.styles[i], 2)}
      end
      self.f_style_push(ctx, self.styles[i][1], table.unpack(args))
      self.style_count = self.style_count + 1
    end
  end
end

function ImGuiTheme:pop(ctx)
  self.f_color_pop(ctx, self.color_count)
  self.f_style_pop(ctx, self.style_count)
end

function ImGuiTheme:wrap(ctx, f, trap_f)
  trap_f = trap_f or function(f_) return xpcall(f_, reaper.ShowConsoleMsg) end
  self:push(ctx)
  trap_f(function() f(ctx) end)
  self:pop(ctx)
end