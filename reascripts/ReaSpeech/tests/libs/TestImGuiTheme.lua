package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('libs/ImGuiTheme')

--

TestImGuiTheme = {
    overrides = {
        f_color_push = function() end,
        f_color_pop = function() end,
        f_style_push = function() end,
        f_style_pop = function() end
    }
}

function TestImGuiTheme:setUp()
  self.overrides.f_color_push = ImGuiTheme.f_color_push
  self.overrides.f_color_pop = ImGuiTheme.f_color_pop
  self.overrides.f_style_push = ImGuiTheme.f_style_push
  self.overrides.f_style_pop = ImGuiTheme.f_style_pop
end

function TestImGuiTheme:tearDown()
  ImGuiTheme.f_color_push = self.overrides.f_color_push
  ImGuiTheme.f_color_pop = self.overrides.f_color_pop
  ImGuiTheme.f_style_push = self.overrides.f_style_push
  ImGuiTheme.f_style_pop = self.overrides.f_style_pop
end

function TestImGuiTheme:testColorInit()
  local theme = ImGuiTheme.new {
    colors = {
        { function() return "some key" end, 0xFF0000FF },
        { "just a key", 0x00FF0000 }
    }
  }

  lu.assertEquals(theme.colors[1][1], "some key")
  lu.assertEquals(theme.colors[1][2], 0xFF0000FF)
  lu.assertEquals(theme.colors[2][1], "just a key")
  lu.assertEquals(theme.colors[2][2], 0x00FF0000)
end

function TestImGuiTheme:testColors()
  local theme = ImGuiTheme.new {
    colors = {
        { function() return "some key" end, 0xFF0000FF },
        { "just a key", 0x00FF0000 }
    }
  }

  local expectations = {
    { "some key", 0xFF0000FF },
    { "just a key", 0x00FF0000 }
  }

  local i = 1

  ImGuiTheme.f_color_push = function(_ctx, key, value)
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(value, expectations[i][2])
    i = i + 1
  end

  ImGuiTheme.f_color_pop = function(_ctx, count)
    lu.assertEquals(count, 2)
  end

  theme:push("context")
  theme:pop("context")
end

function TestImGuiTheme:testStyleInit()
  local theme = ImGuiTheme.new {
    styles = {
        { function() return "single argument" end, 1.0 },
        { "multiple arguments", 2.0, 3.0 }
    }
  }

  lu.assertEquals(theme.styles[1][1], "single argument")
  lu.assertEquals(theme.styles[1][2], 1.0)
  lu.assertEquals(theme.styles[2][1], "multiple arguments")
  lu.assertEquals(theme.styles[2][2], 2.0)
  lu.assertEquals(theme.styles[2][3], 3.0)
end

function TestImGuiTheme:testStyles()
  local theme = ImGuiTheme.new {
    styles = {
      { function() return "single argument" end, 1.0 },
      { "multiple arguments", 2.0, 3.0 },
      { "function argument", function() return { 4.0, 5.0 } end }
  }
}

  local expectations = {
    { "single argument", 1.0 },
    { "multiple arguments", 2.0, 3.0 },
    { "function argument", 4.0, 5.0 }
  }

  local i = 1

  ImGuiTheme.f_style_push = function(_ctx, key, ...)
    local values = ...
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(values, table.unpack(expectations[i], 2))
    i = i + 1
  end

  ImGuiTheme.f_style_pop = function(_ctx, count)
    lu.assertEquals(count, 3)
  end

  theme:push("context")
  theme:pop("context")
end

function TestImGuiTheme:testWrap()
  local theme = ImGuiTheme.new()

  local push_called = false
  local pop_called = false
  function theme:push(ctx)
    lu.assertEquals(ctx, "context")
    push_called = true
  end
  function theme:pop(ctx)
    lu.assertEquals(ctx, "context")
    pop_called = true
  end

  local function_called = false
  theme:wrap("context", function()
    function_called = true
  end)

  lu.assertEquals(push_called, true)
  lu.assertEquals(pop_called, true)
  lu.assertEquals(function_called, true)
end

function TestImGuiTheme:testGetStyle()
  local theme = ImGuiTheme.new {
    styles = {
      { function() return "single argument" end, 1.0 },
      { "multiple arguments", 2.0, 3.0 },
      { "function argument", function() return { 4.0, 5.0 } end }
    }
  }

  lu.assertEquals(theme:get_style("single argument"), 1.0)
  lu.assertEquals(theme:get_style("multiple arguments"), { 2.0, 3.0 })
  lu.assertEquals(theme:get_style("function argument"), { 4.0, 5.0 })
end

function TestImGuiTheme:testGetColor()
  local theme = ImGuiTheme.new {
    colors = {
      { function() return "single argument" end, 0x00FF0000 },
      { "key", 0x00FF0001 }
    }
  }

  lu.assertEquals(theme:get_color("single argument"), 0x00FF0000)
  lu.assertEquals(theme:get_color("key"), 0x00FF0001)
end

function TestImGuiTheme:testSetStyle()
  local theme = ImGuiTheme.new {
    styles = {
      { function() return "single argument" end, 1.0 },
      { "multiple arguments", 2.0, 3.0 },
      { "function argument", function() return { 4.0, 5.0 } end }
    }
  }

  local expectations = {
    { "single argument", 1.0 },
    { "multiple arguments", 2.0, 3.0 },
    { "function argument", 4.0, 5.0 },
  }
  local i = 1
  ImGuiTheme.f_style_push = function(_ctx, key, ...)
    local values = ...
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(values, table.unpack(expectations[i], 2))
    i = i + 1
  end

  ImGuiTheme.f_style_pop = function(_ctx, count)
    lu.assertEquals(count, 3)
  end

  theme:push("context")
  theme:pop("context")

  theme:set_style("new style", 2.0)
  expectations[4] = { "new style", 2.0 }

  ImGuiTheme.f_style_pop = function(_ctx, count)
    lu.assertEquals(count, 4)
  end

  theme:push("context")
  theme:pop("context")

  theme:set_style("new style", 3.0)
  expectations[4] = { "new style", 3.0 }

  ImGuiTheme.f_style_pop = function(_ctx, count)
    lu.assertEquals(count, 4)
  end

  theme:push("context")
  theme:pop("context")
end

function TestImGuiTheme:testSetColor()
  local theme = ImGuiTheme.new {
    colors = {
        { function() return "some key" end, 0xFF0000FF },
        { "just a key", 0x00FF0000 }
    }
  }

  local expectations = {
    { "some key", 0xFF0000FF },
    { "just a key", 0x00FF0000 }
  }

  local i = 1
  ImGuiTheme.f_color_push = function(_ctx, key, ...)
    local values = ...
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(values, table.unpack(expectations[i], 2))
    i = i + 1
  end

  ImGuiTheme.f_color_pop = function(_ctx, count)
    lu.assertEquals(count, 2)
  end

  theme:push("context")
  theme:pop("context")

  theme:set_color("new color", 0x00FFFF00)
  expectations[3] = { "new color", 0x00FFFF00 }

  ImGuiTheme.f_color_pop = function(_ctx, count)
    lu.assertEquals(count, 3)
  end

  theme:push("context")
  theme:pop("context")

  theme:set_color("new color", 0x00FFFF01)
  expectations[3] = { "new color", 0x00FFFF01 }

  ImGuiTheme.f_color_pop = function(_ctx, count)
    lu.assertEquals(count, 3)
  end

  theme:push("context")
  theme:pop("context")
end

--

os.exit(lu.LuaUnit.run())
