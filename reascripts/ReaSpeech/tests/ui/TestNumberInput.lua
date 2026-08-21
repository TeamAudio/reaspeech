package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('include/globals')

require('libs/Ctx')
require('libs/Trap')
require('ui/Widgets')
require('ui/widgets/NumberInput')

--

TestNumberInput = {}

local function fake_widget(options, committed)
  return {
    options = options,
    render_label = function() end,
    value = function() return options.default or 0 end,
    set = function(_, value) table.insert(committed, value) end,
  }
end

function TestNumberInput:testCommitsTypedValue()
  ImGui.InputDouble = function() return true, 15.5 end

  local committed = {}
  Widgets.NumberInput.renderer(fake_widget({ label = 'n' }, committed))

  lu.assertEquals(committed, { 15.5 })
end

function TestNumberInput:testWholeRoundsTypedValue()
  -- InputDouble accepts fractional typed input regardless of step and
  -- format; whole = true must commit an integer
  ImGui.InputDouble = function() return true, 15.5 end

  local committed = {}
  Widgets.NumberInput.renderer(
    fake_widget({ label = 'n', whole = true }, committed))

  lu.assertEquals(committed, { 16 })
end

function TestNumberInput:testWholeRoundsNegativeValueAwayFromZero()
  ImGui.InputDouble = function() return true, -15.5 end

  local committed = {}
  Widgets.NumberInput.renderer(
    fake_widget({ label = 'n', whole = true }, committed))

  lu.assertEquals(committed, { -16 })
end

function TestNumberInput:testRejectsOutOfBoundsValue()
  ImGui.InputDouble = function() return true, 30 end

  local committed = {}
  Widgets.NumberInput.renderer(
    fake_widget({ label = 'n', min = 8, max = 24 }, committed))

  lu.assertEquals(committed, {})
end

os.exit(lu.LuaUnit.run())
