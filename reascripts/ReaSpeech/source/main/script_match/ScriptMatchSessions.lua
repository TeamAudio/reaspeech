
ScriptMatchSessions = Polo {}

function ScriptMatchSessions:init()
  Logging().init(self, 'ScriptMatchSessions')

  -- Initialize a ProjectJSON Storage object
  self.storage = Storage.ProjectJSON('reaspeech/script_match/sessions.json', {
    schema_version = 1,
    migrations = {}
  })

  self.sessions = self.storage:table('sessions', {})
end

-- Return list of sessions { session_id = guid, name = string }
function ScriptMatchSessions:get_sessions()
  return self.sessions:get() or {}
end

function ScriptMatchSessions:get_session(session_id)
  local sessions = self:get_sessions()

  for _, session in ipairs(sessions) do
    self:log('Checking session: ' .. dump(session))
    if session.id == session_id then
      return session
    end
  end

  return nil
end

-- Add a new session to the persistent storage
function ScriptMatchSessions:add_session(session)
  local sessions = self:get_sessions()
  table.insert(sessions, session)
  self.sessions:set(sessions)
end

-- Write a changed session record through to storage. Session tables
-- are shared refs with the storage cache, so the record is usually
-- already updated in place; replacing by id also covers callers
-- holding an unshared copy.
function ScriptMatchSessions:update_session(session)
  local sessions = self:get_sessions()

  for i, existing in ipairs(sessions) do
    if existing.id == session.id then
      sessions[i] = session
      self.sessions:set(sessions)
      return true
    end
  end

  return false
end

-- Remove a session by ID
function ScriptMatchSessions:remove_session(session_id)
  local sessions = self:get_sessions()

  for i, session in ipairs(sessions) do
    if session.id == session_id then
      table.remove(sessions, i)
      self.sessions:set(sessions)
      return true
    end
  end

  return false
end