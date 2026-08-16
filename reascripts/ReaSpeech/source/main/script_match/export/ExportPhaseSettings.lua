--[[

ExportPhaseSettings.lua - Export phase settings data model and persistence

]]--

ExportPhaseSettings = Polo {}

function ExportPhaseSettings:init()
  Logging().init(self, 'ExportPhaseSettings')

  assert(self.session_id, 'ExportPhaseSettings: session_id is required')

  self.storage = self:get_storage()

  -- Template settings
  -- Default template uses only variables every session has (a fresh
  -- sheet may not carry an asset_filename column) and numbers takes
  -- so two accepted takes of one line can't render to one filename
  self.template = self.storage:string('template', '${navigation}/line${needle_index:padded}_take${incrementing_number}.wav')

  -- Audio format settings

  -- Timing settings
  self.pre_roll_seconds = self.storage:number('pre_roll_seconds', 0.5)
  self.post_roll_seconds = self.storage:number('post_roll_seconds', 1.0)
  self.min_duration_seconds = self.storage:number('min_duration_seconds', 1.0)

  -- Export options
  self.overwrite_existing = self.storage:boolean('overwrite_existing', true)
  self.skip_on_error = self.storage:boolean('skip_on_error', false)
  self.open_folder_when_done = self.storage:boolean('open_folder_when_done', false)

  -- Project target: matched child tracks and/or heatmap regions -
  -- each landable on its own - plus the ledger of region ids we
  -- created (so re-exports replace instead of stack)
  self.tracks_tracks = self.storage:boolean('tracks_tracks', true)
  self.tracks_regions = self.storage:boolean('tracks_regions', false)
  self.tracks_region_ledger = self.storage:table('tracks_region_ledger', {})

  self:log('Initialized ExportPhaseSettings for session: ' .. self.session_id)
end

function ExportPhaseSettings:session_storage_location()
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function ExportPhaseSettings:get_storage()
  local json_file = self:session_storage_location() .. '/export_settings.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  })
end

-- Get current template value
function ExportPhaseSettings:get_template()
  return self.template:get()
end

-- Set template value
function ExportPhaseSettings:set_template(value)
  self.template:set(value)
end

-- Get timing settings as a table
function ExportPhaseSettings:get_timing()
  return {
    pre_roll_seconds = self.pre_roll_seconds:get(),
    post_roll_seconds = self.post_roll_seconds:get(),
    min_duration_seconds = self.min_duration_seconds:get()
  }
end

-- Get export options as a table
function ExportPhaseSettings:get_options()
  return {
    overwrite_existing = self.overwrite_existing:get(),
    skip_on_error = self.skip_on_error:get(),
    open_folder_when_done = self.open_folder_when_done:get()
  }
end
