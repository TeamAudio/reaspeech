
ScriptMatchSession = Polo {}

function ScriptMatchSession:init()

end

-- Session Management
function ScriptMatchSession.create_session(config)
  config = config or {}
  local now = os.time()
  local session_id = reaper.genGuid('')
  local session = {
    id = session_id,
    name = config.name or ScriptMatchSession.new_session_name(),
    created_at = now,
    updated_at = now,
  }

  -- self.sessions[session_id] = session
  -- self:save_sessions()

  -- self:log('Created new script match session: ' .. session_id)
  -- return session_id
  return session
end

ScriptMatchSession.new_session_name = function()
  local time = os.time()
  local date_start = os.date('%b %d, %Y @ %I:%M', time)
  ---@diagnostic disable-next-line: param-type-mismatch
  local am_pm = string.lower(os.date('%p', time))

  return date_start .. am_pm
end

