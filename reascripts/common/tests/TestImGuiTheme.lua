package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('mock_reaper')
require('ImGuiTheme')

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
  lu.assertEquals(theme.color_count, 2)
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

  ImGuiTheme.f_color_push = function(ctx, key, value)
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(value, expectations[i][2])
    i = i + 1
  end

  ImGuiTheme.f_color_pop = function(ctx, count)
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
  lu.assertEquals(theme.style_count, 2)
end

function TestImGuiTheme:testStyles()
  local theme = ImGuiTheme.new {
    styles = {
      { function() return "single argument" end, 1.0 },
      { "multiple arguments", 2.0, 3.0 }
  }
}

  local expectations = {
    { "single argument", 1.0 },
    { "multiple arguments", 2.0, 3.0 }
  }

  local i = 1

  ImGuiTheme.f_style_push = function(ctx, key, ...)
    local values = ...
    lu.assertEquals(key, expectations[i][1])
    lu.assertEquals(values, table.unpack(expectations[i], 2))
    i = i + 1
  end

  ImGuiTheme.f_style_pop = function(ctx, count)
    lu.assertEquals(count, 2)
  end

  theme:push("context")
  theme:pop("context")
end

--

os.exit(lu.LuaUnit.run())
