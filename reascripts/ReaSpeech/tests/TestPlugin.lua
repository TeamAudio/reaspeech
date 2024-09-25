package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('Polo')
require('libs/Plugin')

--

TestPlugin = {}

function TestPlugin:testPluginInit()
  local TestPluginClass = Plugin {}

  lu.assertEquals(type(TestPluginClass.new), 'function')
  lu.assertEquals(type(TestPluginClass.tabs), 'function')
  lu.assertEquals(type(TestPluginClass.actions), 'function')
end

function TestPlugin:testPluginHostArgument()
  local plugin = (Plugin {}).new('plugin host')

  lu.assertEquals(plugin.app, 'plugin host')
end

function TestPlugin:testTabsDefault()
  local plugin = (Plugin {}).new()

  lu.assertEquals(plugin:tabs(), {})
end

function TestPlugin:testTabsCallsControlsTabs()
  local plugin = (Plugin {
    _controls = { tabs = function() return 'yay!' end }
  }).new()

  lu.assertEquals(plugin:tabs(), 'yay!')
end

function TestPlugin:testActionsDefault()
  local plugin = (Plugin {}).new()

  lu.assertEquals(plugin:actions(), {})
end

-- yo, dawg, I heard you like actions
function TestPlugin:testActionsCallsActionsActions()
  local plugin = (Plugin {
    _actions = { actions = function() return 'yay!' end }
  }).new()

  lu.assertEquals(plugin:actions(), 'yay!')
end

TestPluginAccessory = {}

function TestPluginAccessory:testPluginAccessoryInit()
  local TestPluginAccessoryClass = PluginAccessory {}

  lu.assertEquals(type(TestPluginAccessoryClass.new), 'function')
end

function TestPluginAccessory:testPluginAccessoryPluginArgument()
  local plugin = (PluginAccessory {}).new('plugin')

  lu.assertEquals(plugin.plugin, 'plugin')
end

TestPluginActions = {}

function TestPluginActions:testPluginActionsActionsDefault()
  local actions = (PluginActions {}).new()

  lu.assertEquals(actions:actions(), {})
end

function TestPluginActions:testOverrideActions()
  local actions = (PluginActions {
    actions = function() return 'yay!' end
  }).new()

  lu.assertEquals(actions:actions(), 'yay!')
end

TestPluginControls = {}

function TestPluginControls:testPluginControlsTabsDefault()
  local controls = (PluginControls {}).new()

  lu.assertEquals(controls:tabs(), {})
end

function TestPluginControls:testOverrideTabs()
  local controls = (PluginControls {
    tabs = function() return 'yay!' end
  }).new()

  lu.assertEquals(controls:tabs(), 'yay!')
end

--

os.exit(lu.LuaUnit.run())