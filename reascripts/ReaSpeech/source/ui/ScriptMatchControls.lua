--[[

  ScriptMatchControls.lua - UI controls for script matching plugin

  Manages session-based script matching interface including:
  - Session creation and management
  - Transcript source selection
  - Script material loading
  - Match results display

]]--

ScriptMatchControls = PluginControls {
  DEFAULT_TAB = 'script-match',

  tabs = function(self)
    self:log('ScriptMatchControls: tabs called')

    local overview_tab = ReaSpeechPlugins.tab('script-matching-overview', 'Script Matching', {
      render = function() self.overview:render() end,
      render_bg = function() end
    }, {
      will_close = function() return false end,  -- Always allow closing overview tab
      on_close = function() self:log('Overview tab closed') end
    })

    return { overview_tab}
  end
}

function ScriptMatchControls:init()
  assert(self.plugin, 'ScriptMatchControls: plugin is required')

  Logging().init(self, 'ScriptMatchControls')

  self.sessions = ScriptMatchSessions.new {}

  self.overview = ScriptMatchOverview.new {
    app = self.plugin.app,
    plugin = self.plugin,
    controls = self,
    sessions = self.sessions,
  }
end

function ScriptMatchControls:new_tab_menu()
  return {
    {
      label = 'New Script Match Session',
      on_click = function() self:create_new_session() end
    }
  }
end

function ScriptMatchControls:create_new_session()
  local session = ScriptMatchSession.create_session()

  self.sessions:add_session(session)

  local plugin = ScriptMatchSessionUI.new {
    app = self.plugin.app,
    session = session,
  }

  self.plugin.app.plugins:add_plugin(plugin)

  self:log('Created new script match session: ' .. session.id)
end

function ScriptMatchControls:open_session(session_id)
  local session = self.sessions:get_session(session_id)
  if not session then
    self:log('Failed to open script match session: ' .. session_id)
  end

  local plugin = ScriptMatchSessionUI.new {
    app = self.plugin.app,
    session = session,
  }

  self.plugin.app.plugins:add_plugin(plugin)
  self:log('Opened script match session: ' .. session.id)
end

function ScriptMatchControls:load_sessions()
  self.loaded_sessions = {}

  for _, session in ipairs(self.sessions:get_sessions()) do
    local session_ui = ScriptMatchSessionUI.new {
      app = self.plugin.app,
      session = session,
    }

    self.loaded_sessions[session.id] = session_ui
  end
end
