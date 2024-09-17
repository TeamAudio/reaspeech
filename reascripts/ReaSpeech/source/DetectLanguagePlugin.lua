--[[

  DetectLanguagePlugin.lua - Language detection and track labeling plugin

]]--

DetectLanguagePlugin = Polo {
  new = function(app)
    return {
      app = app
    }
  end,
}

function DetectLanguagePlugin:init()
  assert(self.app, 'DetectLanguagePlugin: plugin host app is required')
  Logging.init(self, 'DetectLanguagePlugin')
  self._controls = DetectLanguageControls.new(self)
  self._actions = DetectLanguageActions.new(self)
end

function DetectLanguagePlugin:tabs()
  return self._controls:tabs()
end

function DetectLanguagePlugin:actions()
  return self._actions:actions()
end

function DetectLanguagePlugin:detect_language(jobs)
  local request = {
    data = {},
    jobs = jobs,
    endpoint = '/detect_language',
    callback = self:handle_response()
  }

  self.app:submit_request(request)
end

function DetectLanguagePlugin:handle_response()
  -- seen[<track GUID> .. <language code>] = true
  local seen = {}
  local languages = {}
  local track_names = {}

  return function(response)
    local job = response._job
    local track = reaper.GetMediaItemTake_Track(job.take)
    local guid = reaper.GetTrackGUID(track)
    local language_code = response.language_code

    if not seen[guid] then
      seen[guid] = {}
      languages[guid] = {}
      local retval, track_name = reaper.GetTrackName(track)
      if retval then track_names[guid] = track_name end
    end

    if seen[guid][language_code] then return end

    seen[guid][language_code] = true
    table.insert(languages[guid], language_code)

    local track_name = ("%s - %s"):format(track_names[guid], table.concat(languages[guid], ', '))
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)
    reaper.Undo_EndBlock('Add Languages to Track Name', -1)
    reaper.PreventUIRefresh(-1)
  end
end