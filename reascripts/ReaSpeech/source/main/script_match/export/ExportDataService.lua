--[[

ExportDataService.lua - Data integration service for export phase

Responsibilities:
- Load all accepted suggestions across all needles in session
- Generate file tree structure from template + suggestion data
- Provide export status tracking per file
- Calculate size estimates and metadata per export item

]]--

ExportDataService = Polo {}

function ExportDataService:init()
  Logging().init(self, 'ExportDataService')

  assert(self.session_id, 'ExportDataService: session_id is required')
  assert(self.template_engine, 'ExportDataService: template_engine is required')
  assert(self.workflow, 'ExportDataService: workflow is required')

  -- The workflow-owned suggestion store: the same instance curation
  -- writes decisions through
  self.suggestion_manager = self.workflow:get_suggestion_state_manager()

  -- Use the workflow-owned needle metadata service: that is the instance
  -- refreshed with regenerated needles when phases expand. A private
  -- instance would never be refreshed and would resolve no metadata.
  self.needle_metadata = self.workflow:get_needle_metadata_service()

  -- Cache for export items to avoid regenerating on every render
  self.export_items = nil
  self.export_items_dirty = true

  -- Source WAV header info per path (headers don't change under us);
  -- false remembers an unreadable file
  self.wav_info_cache = {}

  self:log("Initialized ExportDataService for session: " .. self.session_id)
end

function ExportDataService:session_storage_location()
  -- Project-relative, like every other session store; Storage.ProjectJSON
  -- prepends the project path itself
  return ('reaspeech/script_match/sessions/%s'):format(self.session_id)
end

function ExportDataService:get_export_status_storage()
  local json_file = self:session_storage_location() .. '/export_status.json'

  return Storage.ProjectJSON(json_file, {
    schema_version = 1,
    migrations = {}
  }):table('file_statuses', {})
end

-- Core Data Loading

function ExportDataService:get_all_accepted_matches()
  local success, result = pcall(function()
    local all_accepted_matches = {}

    for _, entry in ipairs(self.suggestion_manager:get_needles_with_suggestions()) do
      local accepted_suggestions = self.suggestion_manager:load_accepted_suggestions(entry.needle_guid)

      if #accepted_suggestions > 0 then
        local needle_data = self.needle_metadata:get_needle_metadata_for_export(entry.needle_guid)

        for _, suggestion in ipairs(accepted_suggestions) do
          table.insert(all_accepted_matches,
            self:enrich_suggestion_with_context(suggestion, needle_data, entry.needle_guid))
        end
      end
    end

    self:log(string.format("Loaded %d accepted matches", #all_accepted_matches))
    return all_accepted_matches
  end)

  if not success then
    self:log("ERROR in get_all_accepted_matches: " .. tostring(result))
    return {}
  end

  return result
end

function ExportDataService:enrich_suggestion_with_context(suggestion, needle_data, needle_guid)
  -- Create enriched copy with additional metadata for template generation
  local enriched = {}

  -- Copy original suggestion fields
  for k, v in pairs(suggestion) do
    enriched[k] = v
  end

  -- Add needle context for template variables
  enriched.needle_guid = needle_guid
  enriched.needle_index = needle_data and needle_data.index or 0
  enriched.needle_content = needle_data and needle_data.content or ""

  -- Extract script materials metadata from needle in suggestion
  -- The suggestion already contains the needle with metadata
  if suggestion.needle and suggestion.needle.metadata then
    for _, metadata_item in ipairs(suggestion.needle.metadata) do
      if metadata_item.tag and metadata_item.value then
        enriched[metadata_item.tag] = metadata_item.value
        self:log(string.format("Extracted metadata: %s = %s", metadata_item.tag, metadata_item.value))
      end
    end
  end

  -- Overlay the needle's *current* metadata: needle_data is the flat
  -- tag -> value map from NeedleMetadataService (plus needle_content /
  -- source_* extras). It reflects the present worksheet tag
  -- configuration, so it wins over the snapshot stored at accept time -
  -- tags added after a suggestion was accepted still resolve.
  if needle_data then
    for tag, value in pairs(needle_data) do
      enriched[tag] = value
    end
  end

  -- Calculate derived fields
  enriched.duration = enriched.end_time - enriched.start_time

  -- Add default format if not specified
  if not enriched.output_format then
    enriched.output_format = "wav"  -- Default audio format
  end

  -- Add unique identifier for export tracking
  if not enriched.export_id then
    enriched.export_id = string.format("%s_%s", needle_guid, suggestion.guid or tostring(suggestion.start_time))
  end

  self:log(string.format("Enriched match with variables: target_filename=%s, output_format=%s", enriched.target_filename or "nil", enriched.output_format or "nil"))

  return enriched
end

-- Export Item Generation

function ExportDataService:generate_export_items(template, timing)
  if not self.export_items_dirty and self.export_items then
    return self.export_items
  end

  self:log("Generating export items from template and accepted matches")

  local accepted_matches = self.cached_accepted_matches
  if not accepted_matches then
    accepted_matches = self:get_all_accepted_matches()
    self.cached_accepted_matches = accepted_matches
  end

  local export_items = {}

  -- Get current export statuses
  local status_storage = self:get_export_status_storage()
  local existing_statuses = status_storage:get()

  -- Filenames resolve in two passes: per-item variables first with
  -- ${incrementing_number} deferred, then batch numbering across the
  -- whole set so duplicate takes of one line can't clobber each other
  local raw_filenames = {}
  for i, match in ipairs(accepted_matches) do
    raw_filenames[i] = self.template_engine:generate_filename(template, match, true)
  end
  local filenames = self.template_engine:finalize_filenames(raw_filenames)

  for i, match in ipairs(accepted_matches) do
    local export_item = self:create_export_item_from_match(match, filenames[i], template, timing)

    -- Add current export status
    export_item.status = existing_statuses[export_item.export_id] or 'pending'

    table.insert(export_items, export_item)
  end

  -- Organize items into hierarchical directory tree structure for tree display
  local organized_items = self:build_directory_tree(export_items)

  self.export_items = organized_items
  self.export_items_dirty = false

  self:log(string.format("Generated %d export items organized into directory structure", #export_items))
  return organized_items
end

-- filename arrives pre-generated (batch-finalized by the caller so
-- incrementing_number reflects the whole export set)
function ExportDataService:create_export_item_from_match(match, filename, template, timing)
  self:log(string.format("Export item filename: '%s' (template '%s')", filename, template))

  -- Use template-aware relative path extraction for proper tree display
  local relative_path = self.template_engine:get_relative_path_from_filename(template, filename)
  local directory_path = self:extract_directory_path(relative_path)

  self:log(string.format("Template-aware relative path: '%s', directory: '%s'", relative_path, directory_path))

  -- File estimates from what will actually be written: the roll-padded
  -- slice range at the source file's real byte rate
  local duration = self:slice_duration(match, timing)
  local file_size_estimate = self:estimate_file_size(duration, self:source_byte_rate(match))

  return {
    export_id = match.export_id,
    filename = filename,
    display_name = self:extract_display_name(filename),
    directory_path = directory_path,

    -- Source match data
    match = match,
    start_time = match.start_time,
    end_time = match.end_time,
    duration = duration,
    confidence = match.confidence,
    track_guids = match.track_guids,
    file = match.file,

    -- Export metadata
    file_size_estimate = file_size_estimate,
    formatted_duration = self:format_duration(duration),
    formatted_size = self:format_file_size(file_size_estimate),

    -- Status tracking (will be set by caller)
    status = 'pending'
  }
end

function ExportDataService:build_directory_tree(export_items)
  -- Build hierarchical directory tree from flat export items
  local root_nodes = {}

  for _, item in ipairs(export_items) do
    local dir_path = item.directory_path or ""

    if dir_path == "" then
      -- Item goes directly in root
      local root_node = self:get_or_create_root_node(root_nodes, "(Root)")
      table.insert(root_node.files, item)
    else
      -- Split path into components and build tree
      local path_parts = self:split_directory_path(dir_path)
      self:insert_item_into_tree(root_nodes, path_parts, item)
    end
  end

  -- Sort all nodes recursively
  self:sort_directory_tree(root_nodes)

  return root_nodes
end

function ExportDataService:split_directory_path(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

function ExportDataService:insert_item_into_tree(current_level, path_parts, item)
  if #path_parts == 0 then
    -- Shouldn't happen, but handle gracefully
    return
  end

  local current_part = path_parts[1]
  local remaining_parts = {}
  for i = 2, #path_parts do
    table.insert(remaining_parts, path_parts[i])
  end

  -- Find or create directory node at current level
  local dir_node = self:get_or_create_directory_node(current_level, current_part, path_parts)

  if #remaining_parts == 0 then
    -- This is the final directory - add file here
    table.insert(dir_node.files, item)
  else
    -- Need to go deeper - recurse into children
    self:insert_item_into_tree(dir_node.children, remaining_parts, item)
  end
end

function ExportDataService:get_or_create_directory_node(nodes_list, dir_name, full_path_parts)
  -- Look for existing node
  for _, node in ipairs(nodes_list) do
    if node.name == dir_name then
      return node
    end
  end

  -- Create new node
  local full_path = table.concat(full_path_parts, "/")
  local new_node = {
    name = dir_name,
    path = full_path,
    display_name = dir_name,  -- Just the directory name, not full path
    files = {},
    children = {}
  }

  table.insert(nodes_list, new_node)
  return new_node
end

function ExportDataService:get_or_create_root_node(nodes_list, root_name)
  -- Look for existing root node
  for _, node in ipairs(nodes_list) do
    if node.name == root_name then
      return node
    end
  end

  -- Create new root node
  local new_node = {
    name = root_name,
    path = "",
    display_name = root_name,
    files = {},
    children = {}
  }

  table.insert(nodes_list, new_node)
  return new_node
end

function ExportDataService:sort_directory_tree(nodes_list)
  -- Sort directories by name
  table.sort(nodes_list, function(a, b) return a.name < b.name end)

  -- Sort files within each directory and recurse into children
  for _, node in ipairs(nodes_list) do
    table.sort(node.files, function(a, b) return a.display_name < b.display_name end)
    self:sort_directory_tree(node.children)
  end
end

-- Export Status Management

function ExportDataService:get_export_status(export_id)
  local status_storage = self:get_export_status_storage()
  local statuses = status_storage:get()
  return statuses[export_id] or 'pending'
end

function ExportDataService:set_export_status(export_id, status)
  local status_storage = self:get_export_status_storage()
  local statuses = status_storage:get()
  statuses[export_id] = status
  status_storage:set(statuses)

  -- Mark export items as dirty to refresh on next access
  self.export_items_dirty = true

  self.workflow:emit_event('export_status_changed', {
    export_id = export_id,
    status = status,
  })
end

-- File Estimation & Formatting

-- The written file spans the match plus pre/post-roll, tail-extended
-- to the minimum duration - the same range extract_audio_file slices
function ExportDataService:slice_duration(match, timing)
  timing = timing or {}

  local base = match.duration or 0
  if match.start_time and match.end_time then
    base = match.end_time - match.start_time
  end

  local duration = base + (timing.pre_roll_seconds or 0) + (timing.post_roll_seconds or 0)
  return math.max(duration, timing.min_duration_seconds or 0)
end

-- Byte rate straight from the source WAV's header, resolved through
-- the project the same way the slicer will. Cached per path (false
-- remembers an unreadable file).
function ExportDataService:source_byte_rate(match)
  local range = SuggestionTimeline.resolve(match)
  local source_path = range and range.source_path
  if not source_path or source_path == '' then return nil end

  local cached = self.wav_info_cache[source_path]
  if cached == nil then
    local info = WavFile.info(source_path)
    cached = info and info.byte_rate or false
    self.wav_info_cache[source_path] = cached
  end

  return cached or nil
end

-- Direct slicing copies source bytes verbatim: size is slice duration
-- x source byte rate plus the WAV header. The 16-bit/44.1k mono
-- fallback only applies when the source can't be read.
function ExportDataService:estimate_file_size(duration_seconds, byte_rate)
  byte_rate = byte_rate or 88200
  return math.floor(duration_seconds * byte_rate) + 44
end

function ExportDataService:format_file_size(bytes)
  if bytes < 1024 then
    return string.format("%dB", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1fKB", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then
    return string.format("%.1fMB", bytes / (1024 * 1024))
  else
    return string.format("%.1fGB", bytes / (1024 * 1024 * 1024))
  end
end

function ExportDataService:format_duration(seconds)
  local minutes = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  local millisecs = math.floor((seconds % 1) * 10)
  return string.format("%02d:%02d.%d", minutes, secs, millisecs)
end

-- Path Utilities

function ExportDataService:extract_display_name(filename)
  -- Extract just the filename without directory path
  local name = filename:match("([^/\\]+)$") or filename
  return name
end

function ExportDataService:extract_directory_path(filename)
  -- Extract directory path without filename
  local dir = filename:match("^(.+)[/\\][^/\\]+$") or ""
  return dir
end

function ExportDataService:extract_directory_name(dir_path)
  -- Extract just the last directory name
  local name = dir_path:match("([^/\\]+)$") or dir_path
  return name
end

-- Cache Management

-- Full invalidation: reload accepted matches (with enrichment) and
-- rebuild the item tree
function ExportDataService:invalidate_cache()
  self.cached_accepted_matches = nil
  self.export_items_dirty = true
  self:log("Export caches invalidated")
end

-- Light invalidation: rebuild only the filename/tree half against the
-- cached enriched matches (used for per-keystroke template edits)
function ExportDataService:invalidate_items()
  self.export_items_dirty = true
end

