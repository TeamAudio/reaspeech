--[[

ExportTemplateEngine.lua - Template parsing, validation, and filename generation

Handles template processing with ${variable:processor} syntax for intelligent filename generation.
Provides template validation, autocomplete suggestions, and filename preview generation.

Template Syntax:
- ${variable} - Simple variable replacement
- ${variable:processor} - Variable with processor function
- Processors: basename, dirname, uppercase, lowercase, slugify, timecode, pe    -- Fall back to mock data
    sample_data = {
      text = 'Sample transcribed dialogue',
      character_name = 'Hero',
      emotion = 'angry',
      scene_number = '3',
      line_number = '42',
      start_time = '23.5',
      end_time = '26.8',
      duration = '3.3',
      confidence = '0.92',
      track_name = 'Actor_Male',
      file_name = 'character_angry_01.wav',

      -- Uses OS-specific path separator
      navigation = 'Script_Spreadsheet.xlsx/Sheeet1',
      segment_id = '15',
    } Variables:
- Script materials: asset_filename, character, context, custom columns
- Source info: script_filename, track_name, needle_index
- Match metadata: confidence, start_time, end_time, duration

]]--

ExportTemplateEngine = Polo {}

function ExportTemplateEngine:init()
  Logging().init(self, 'ExportTemplateEngine')

  assert(self.needle_metadata_service, 'ExportTemplateEngine: needle_metadata_service is required')

  -- Initialize available processors
  self.processors = self:init_processors()

  -- Initialize available variables (will be populated from metadata service)
  self.available_variables = self:init_default_variables()

  -- Store reference to metadata service instead of session storage
  self.metadata_service = self.needle_metadata_service

  -- Cache for expensive operations (cleared when metadata changes)
  self.cached_variables_by_type = nil
  self.cached_variables_for_editor = nil
  self.cache_timestamp = 0

  self:log('Initialized ExportTemplateEngine with NeedleMetadataService')
end

function ExportTemplateEngine:init_processors()
  return {
    basename = function(value)
      if not value then return '' end
      local name = string.match(value, "([^/\\]+)$") or value
      return string.match(name, "(.+)%..+$") or name
    end,

    dirname = function(value)
      if not value then return '' end
      return string.match(value, "(.+)[/\\][^/\\]+$") or ''
    end,

    uppercase = function(value)
      if not value then return '' end
      return string.upper(value)
    end,

    lowercase = function(value)
      if not value then return '' end
      return string.lower(value)
    end,

    slugify = function(value)
      if not value then return '' end
      local result = string.lower(value)
      result = string.gsub(result, "[^%w%s%-_]", "")
      result = string.gsub(result, "%s+", "_")
      result = string.gsub(result, "_+", "_")
      result = string.gsub(result, "^_+", "")
      result = string.gsub(result, "_+$", "")
      return result
    end,

    timecode = function(value)
      if not value then return '00_00_0' end
      local num = tonumber(value) or 0
      local minutes = math.floor(num / 60)
      local seconds = math.floor(num % 60)
      local fraction = math.floor((num % 1) * 10)
      return string.format("%02d_%02d_%d", minutes, seconds, fraction)
    end,

    percent = function(value)
      if not value then return '0pct' end
      local num = tonumber(value) or 0
      return string.format("%dpct", math.floor(num * 100))
    end,

    padded = function(value)
      if not value then return '001' end
      local num = tonumber(value) or 1
      return string.format("%03d", num)
    end
  }
end

function ExportTemplateEngine:init_default_variables()
  return {
    -- Script materials (will be populated from session)
    script_materials = {
      'asset_filename',
      'character',
      'context'
    },

    -- Source information
    source_info = {
      'navigation',
      'script_filename',
      'track_name',
      'needle_index'
    },

    -- Match metadata
    match_metadata = {
      'confidence',
      'start_time',
      'end_time',
      'duration'
    },

    -- Export settings
    export_settings = {
      'output_format'
    }
  }
end

-- Parse template string and return list of variables and their processors
function ExportTemplateEngine:parse_template(template)
  if not template then return {} end

  local variables = {}

  -- Find all ${variable:processor} or ${variable} patterns, with an
  -- optional conditional prefix: ${"-":variable} renders the dash only
  -- when the variable resolves non-blank (tested after processors)
  for match in string.gmatch(template, "${([^}]+)}") do
    local content = match

    local prefix = nil
    local quoted, rest = content:match('^"([^"]*)":(.*)$')
    if quoted then
      prefix = quoted
      content = rest
    end

    local variable, processor = string.match(content, "([^:]+):?(.*)")

    table.insert(variables, {
      variable = variable,
      processor = processor ~= '' and processor or nil,
      prefix = prefix,
      full_match = '${' .. match .. '}'
    })
  end

  return variables
end

-- Validate template syntax and return errors
function ExportTemplateEngine:validate_template(template)
  local errors = {}

  if not template or template == '' then
    table.insert(errors, 'Template cannot be empty')
    return errors
  end

  local variables = self:parse_template(template)

  for _, var_info in ipairs(variables) do
    -- Check if variable is known
    local is_known = self:is_variable_available(var_info.variable)
    if not is_known then
      table.insert(errors, string.format("Unknown variable: %s", var_info.variable))
    end

    -- Check if processor is valid
    if var_info.processor and not self.processors[var_info.processor] then
      table.insert(errors, string.format("Unknown processor: %s", var_info.processor))
    end

    -- Conditional prefixes end up in filenames; hold them to the same
    -- character rules as static parts
    if var_info.prefix and string.match(var_info.prefix, '[<>:"|\\*%?]') then
      table.insert(errors, string.format('Invalid filename characters in prefix: %s', var_info.prefix))
    end
  end

  -- Check for invalid characters in static parts
  local static_parts = self:get_static_parts(template)
  for _, part in ipairs(static_parts) do
    if string.match(part, '[<>:"|\\*%?]') then
      table.insert(errors, string.format("Invalid filename characters in: %s", part))
    end
  end

  return errors
end

-- Check if a variable is available in current session
function ExportTemplateEngine:is_variable_available(variable)
  -- Check all categories in the legacy format (for backward compatibility)
  for _, vars in pairs(self.available_variables) do
    for _, var in ipairs(vars) do
      if var == variable then return true end
    end
  end

  -- Check the new format variables with real session data
  local new_format_vars = self:get_available_variables_for_editor()
  for _, var in ipairs(new_format_vars) do
    if var.name == variable then return true end
  end

  return false
end

-- Get static (non-variable) parts of template
function ExportTemplateEngine:get_static_parts(template)
  if not template then return {} end

  local parts = {}
  local current_pos = 1

  while true do
    local var_start = string.find(template, "${", current_pos)
    if not var_start then
      -- Add remaining static part
      local remaining = string.sub(template, current_pos)
      if remaining ~= '' then
        table.insert(parts, remaining)
      end
      break
    end

    -- Add static part before variable
    if var_start > current_pos then
      local static_part = string.sub(template, current_pos, var_start - 1)
      table.insert(parts, static_part)
    end

    -- Find end of variable
    local var_end = string.find(template, "}", var_start)
    if not var_end then
      -- Malformed template, treat rest as static
      local remaining = string.sub(template, var_start)
      table.insert(parts, remaining)
      break
    end

    current_pos = var_end + 1
  end

  return parts
end

-- Generate filename from template using provided data
-- defer_batch_variables leaves ${incrementing_number} placeholders
-- intact for finalize_filenames, which numbers them across the whole
-- export set; without it the variable resolves to '1' (previews)
function ExportTemplateEngine:generate_filename(template, data, defer_batch_variables)
  if not template or not data then return '' end

  local result = template
  local variables = self:parse_template(template)

  for _, var_info in ipairs(variables) do
    local skip = defer_batch_variables and var_info.variable == 'incrementing_number'

    if not skip then
      local value

      -- Use get_variable_value for proper variable resolution
      -- This handles special cases like navigation, system variables, etc.
      if self.get_variable_value then
        value = self:get_variable_value(var_info.variable, data)
      else
        -- Fallback to direct access if get_variable_value not available
        value = data[var_info.variable]
      end

      -- Apply processor if specified
      if value and var_info.processor then
        local processor_func = self.processors[var_info.processor]
        if processor_func then
          value = processor_func(value)
        end
      end

      -- Replace in result (convert nil to empty string); a conditional
      -- prefix renders only when the value survives non-blank
      value = value or ''
      if var_info.prefix and value ~= '' then
        value = var_info.prefix .. value
      end
      result = string.gsub(result, var_info.full_match:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), value)
    end
  end

  return result
end

-- Batch resolution for ${incrementing_number}: filenames that are
-- otherwise identical number 1..N in batch order (unique names get 1),
-- so multiple accepted takes of one line can't render to one file.
-- Afterwards, any collisions that remain (template without the
-- variable) get a _N suffix before the extension - an export must
-- never silently overwrite its own output.
function ExportTemplateEngine:finalize_filenames(filenames)
  local group_counts = {}
  local finals = {}

  for i, name in ipairs(filenames) do
    local group_key = name:gsub('%${"[^"]*":incrementing_number[^}]*}', '')
    group_key = group_key:gsub('%${incrementing_number[^}]*}', '')
    group_counts[group_key] = (group_counts[group_key] or 0) + 1
    local number = tostring(group_counts[group_key])

    -- The number always resolves non-blank, so a conditional prefix
    -- always renders here
    local resolved = name:gsub('%${incrementing_number}', number)
    resolved = resolved:gsub('%${incrementing_number:([^}]*)}', function(processor_name)
      local processor = self.processors[processor_name]
      return processor and processor(number) or number
    end)
    resolved = resolved:gsub('%${"([^"]*)":incrementing_number}', function(prefix)
      return prefix .. number
    end)
    resolved = resolved:gsub('%${"([^"]*)":incrementing_number:([^}]*)}', function(prefix, processor_name)
      local processor = self.processors[processor_name]
      return prefix .. (processor and processor(number) or number)
    end)

    finals[i] = resolved
  end

  local used = {}
  for i, name in ipairs(finals) do
    if used[name] then
      local base, ext = name:match('^(.*)(%.[^%./\\]+)$')
      base = base or name
      ext = ext or ''

      local n = 2
      local candidate = ('%s_%d%s'):format(base, n, ext)
      while used[candidate] do
        n = n + 1
        candidate = ('%s_%d%s'):format(base, n, ext)
      end

      finals[i] = candidate
    end

    used[finals[i]] = true
  end

  return finals
end

-- Get autocomplete suggestions for partial variable input
function ExportTemplateEngine:get_autocomplete_suggestions(partial_variable)
  if not partial_variable then return {} end

  local suggestions = {}
  local lower_partial = string.lower(partial_variable)

  -- Search all available variables
  for category, vars in pairs(self.available_variables) do
    for _, var in ipairs(vars) do
      if string.find(string.lower(var), lower_partial, 1, true) == 1 then
        table.insert(suggestions, {
          variable = var,
          category = category,
          display_text = var,
          insert_text = '${' .. var .. '}'
        })
      end
    end
  end

  -- Sort by relevance (exact prefix matches first, then alphabetical)
  table.sort(suggestions, function(a, b)
    local a_exact = string.find(string.lower(a.variable), lower_partial, 1, true) == 1
    local b_exact = string.find(string.lower(b.variable), lower_partial, 1, true) == 1

    if a_exact and not b_exact then return true end
    if b_exact and not a_exact then return false end

    return a.variable < b.variable
  end)

  return suggestions
end

-- Generate sample filename for preview using mock data
function ExportTemplateEngine:generate_preview(template)
  return self:generate_filename(template, self:build_preview_data(nil))
end

-- Get all available variables organized by category
function ExportTemplateEngine:get_all_variables()
  return self.available_variables
end

-- Get variables with descriptions for the template editor, including real session data
function ExportTemplateEngine:get_available_variables_for_editor()
  -- Return cached result if available
  if self.cached_variables_for_editor then
    return self.cached_variables_for_editor
  end

  local variables = {}

  -- Add system/built-in variables (always available)
  local system_variables = self:_get_system_variables()
  for _, var in ipairs(system_variables) do
    table.insert(variables, var)
  end

  -- Add dynamic variables from session data
  local dynamic_variables = self:_get_script_material_variables()
  for _, var in ipairs(dynamic_variables) do
    table.insert(variables, var)
  end

  -- Cache the result
  self.cached_variables_for_editor = variables
  self.cache_timestamp = os.time()

  self:log('Built variables cache: ' .. #variables .. ' total variables for editor')

  return variables
end

-- Get system/built-in variables that are always available
function ExportTemplateEngine:_get_system_variables()
  return {
    { name = 'output_format', description = 'Output file format (wav, mp3, etc.)', type = 'system' },
    { name = 'date', description = 'Current date (YYYY-MM-DD)', type = 'system' },
    { name = 'timestamp', description = 'Current timestamp', type = 'system' },
    { name = 'incrementing_number', description = 'Auto-incrementing number for duplicates', type = 'system' },
    { name = 'track_name', description = 'Source audio track name', type = 'system' },
    { name = 'project_name', description = 'REAPER project name', type = 'system' },
    { name = 'navigation', description = 'Navigation path for the script', type = 'system' },
  }
end

-- Get variables by type for UI rendering
function ExportTemplateEngine:get_variables_by_type()
  -- Return cached result if available
  if self.cached_variables_by_type then
    return self.cached_variables_by_type
  end

  local all_variables = self:get_available_variables_for_editor()
  local by_type = {
    system = {},
    dynamic = {}
  }

  for _, variable in ipairs(all_variables) do
    local var_type = variable.type or 'dynamic'
    table.insert(by_type[var_type], variable)
  end

  -- Cache the result
  self.cached_variables_by_type = by_type

  self:log('Built variables by type cache: ' .. #by_type.system .. ' system, ' .. #by_type.dynamic .. ' dynamic')

  return by_type
end

-- Get actual data for a given variable from curated matches
function ExportTemplateEngine:get_variable_value(variable_name, curated_match_data)
  if not curated_match_data then return nil end

  -- Single-item resolution (previews); real exports number this
  -- across the whole set via finalize_filenames
  if variable_name == 'incrementing_number' then
    return '1'
  end

  -- Use metadata service to get variable value from the needle data
  local variable_value = self.metadata_service:get_variable_value(variable_name, curated_match_data)

  if variable_value ~= nil then
    return variable_value
  end

  -- Fallback for direct variable access if not handled by metadata service
  -- Try transcript segment data first
  local transcript_vars = {
    text = curated_match_data.transcript_text,
    start_time = curated_match_data.start_time,
    end_time = curated_match_data.end_time,
    duration = curated_match_data.duration,
    confidence = curated_match_data.confidence,
    segment_id = curated_match_data.segment_id,
    word_count = curated_match_data.word_count
  }

  if transcript_vars[variable_name] then
    return transcript_vars[variable_name]
  end

  -- Special handling for navigation variable
  if variable_name == 'navigation' then
    local navigation_path = nil

    -- Try different possible data structures
    if curated_match_data.navigation then
      self:log("Found navigation at curated_match_data.navigation: " .. self:safe_inspect_table(curated_match_data.navigation))
      navigation_path = curated_match_data.navigation
    elseif curated_match_data.match and curated_match_data.match.needle and curated_match_data.match.needle.navigation then
      self:log("Found navigation at curated_match_data.match.needle.navigation: " .. self:safe_inspect_table(curated_match_data.match.needle.navigation))
      navigation_path = curated_match_data.match.needle.navigation
    elseif curated_match_data.needle and curated_match_data.needle.navigation then
      self:log("Found navigation at curated_match_data.needle.navigation: " .. self:safe_inspect_table(curated_match_data.needle.navigation))
      navigation_path = curated_match_data.needle.navigation
    else
      self:log("Navigation not found in any expected location")
      if curated_match_data.match then
        self:log("match structure: " .. self:safe_inspect_table(curated_match_data.match, 2))
        self:log("match keys: " .. table.concat(self:get_keys(curated_match_data.match), ", "))
        if curated_match_data.match.needle then
          self:log("match.needle structure: " .. self:safe_inspect_table(curated_match_data.match.needle, 2))
          self:log("match.needle keys: " .. table.concat(self:get_keys(curated_match_data.match.needle), ", "))
        end
      end
      if curated_match_data.needle then
        self:log("needle structure: " .. self:safe_inspect_table(curated_match_data.needle, 2))
        self:log("needle keys: " .. table.concat(self:get_keys(curated_match_data.needle), ", "))
      end
    end

    if navigation_path and type(navigation_path) == 'table' and #navigation_path > 0 then
      -- Use PathUtil safely, with fallback to simple separator
      local separator = '/'
      if PathUtil and PathUtil._path_separator then
        separator = PathUtil._path_separator()
      end
      local result = table.concat(navigation_path, separator)
      self:log("Returning navigation: " .. result)
      return result
    else
      -- Fallback: derive from other available data
      local fallback = curated_match_data.project_name or curated_match_data.file_name or 'Unknown'
      self:log("Using fallback navigation: " .. fallback)
      return fallback
    end
  end

  -- Try media metadata
  local media_vars = {
    track_name = curated_match_data.track_name,
    file_name = curated_match_data.file_name,
    file_path = curated_match_data.file_path,
    take_number = curated_match_data.take_number,
    item_position = curated_match_data.item_position,
    project_name = curated_match_data.project_name,
    -- Export variables that are enriched at the top level
    target_filename = curated_match_data.target_filename,
    output_format = curated_match_data.output_format,
  }

  if media_vars[variable_name] then
    return media_vars[variable_name]
  end

  return nil
end

-- Assemble the data table backing template previews: the first sample
-- needle/curated match when available, mock data otherwise
function ExportTemplateEngine:build_preview_data(curated_matches)
  local sample_data

  if curated_matches and #curated_matches > 0 then
    local match = curated_matches[1]
    sample_data = {
      text = match.transcript_text or match.content or 'Sample transcribed text',
      start_time = match.start_time or '23.5',
      end_time = match.end_time or '26.8',
      duration = match.duration or '3.3',
      confidence = match.confidence or '0.92',
      track_name = match.track_name or 'Actor_Male',
      file_name = match.file_name or 'character_angry_01.wav',
      segment_id = match.segment_id or '15',
    }

    -- Add navigation using the same logic as get_variable_value
    local navigation_path = nil
    if match.navigation then
      navigation_path = match.navigation
    elseif match.match and match.match.needle and match.match.needle.navigation then
      navigation_path = match.match.needle.navigation
    elseif match.needle and match.needle.navigation then
      navigation_path = match.needle.navigation
    end

    -- Sample needles carry navigation as source_file/source_sheet in
    -- their extracted-metadata map
    if not navigation_path and match.metadata and (match.metadata.source_file or '') ~= '' then
      navigation_path = { match.metadata.source_file }
      if (match.metadata.source_sheet or '') ~= '' then
        table.insert(navigation_path, match.metadata.source_sheet)
      end
    end

    if navigation_path and type(navigation_path) == 'table' and #navigation_path > 0 then
      local separator = '/'
      if PathUtil and PathUtil._path_separator then
        separator = PathUtil._path_separator()
      end
      sample_data.navigation = table.concat(navigation_path, separator)
    else
      sample_data.navigation = match.project_name or match.file_name or 'GameScript_Episode1.xlsx/Sheet1'
    end

    -- Add script material data if available
    if match.script_material_data then
      for _, material in pairs(match.script_material_data) do
        for key, value in pairs(material) do
          local normalized_key = self:normalize_column_name(key)
          if normalized_key and normalized_key ~= '' then
            sample_data[normalized_key] = value
          end
        end
      end
    end

    -- Sample needles keep their sheet columns (already keyed by
    -- template variable name) in a flat metadata map - the source of
    -- asset_filename, character, etc. for the preview
    if match.metadata then
      for key, value in pairs(match.metadata) do
        if sample_data[key] == nil then
          sample_data[key] = value
        end
      end
    end
  else
    -- Fall back to mock data
    sample_data = {
      text = 'Sample transcribed dialogue',
      asset_filename = 'character_angry_01.wav',
      character = 'Male',
      context = 'angry',
      script_filename = 'GameScript_Episode1.xlsx',
      needle_index = '15',
      start_time = '23.5',
      end_time = '26.8',
      duration = '3.3',
      confidence = '0.92',
      track_name = 'Actor_Male',
      file_name = 'character_angry_01.wav',
      navigation = 'GameScript_Episode1.xlsx/Sheet1',
      segment_id = '15',
      output_format = 'wav',
    }
  end

  return sample_data
end

-- Generate realistic filename using actual curated match data
function ExportTemplateEngine:generate_realistic_preview(template, curated_matches)
  return self:generate_filename(template, self:build_preview_data(curated_matches))
end

-- Preview split into segments, with the spans the template substituted
-- marked so the UI can color them apart from the literal text.
-- Each ${...} block resolves through generate_filename, so processors
-- and preview quirks (incrementing_number -> '1') behave identically.
function ExportTemplateEngine:generate_preview_segments(template, curated_matches)
  if not template then return {} end

  local data = self:build_preview_data(curated_matches)
  local segments = {}
  local pos = 1

  while true do
    local block_start, block_end = template:find('%${[^}]*}', pos)
    if not block_start then break end

    if block_start > pos then
      table.insert(segments, { text = template:sub(pos, block_start - 1) })
    end

    local value = self:generate_filename(template:sub(block_start, block_end), data)
    if value ~= '' then
      table.insert(segments, { text = value, from_template = true })
    end

    pos = block_end + 1
  end

  if pos <= #template then
    table.insert(segments, { text = template:sub(pos) })
  end

  return segments
end

function ExportTemplateEngine:_get_transcript_variables()
  -- Standard transcript segment properties
  return {
    { name = 'text', description = 'Transcribed text from audio segment' },
    { name = 'start_time', description = 'Start time of audio segment' },
    { name = 'end_time', description = 'End time of audio segment' },
    { name = 'duration', description = 'Duration of audio segment' },
    { name = 'confidence', description = 'Transcription confidence score' },
    { name = 'segment_id', description = 'Unique segment identifier' },
    { name = 'word_count', description = 'Number of words in segment' },
  }
end

function ExportTemplateEngine:_get_script_material_variables()
  -- Get properly formatted variables from metadata service
  local variables = self.metadata_service:get_variables_for_template_editor()

  -- Only log when rebuilding cache to avoid per-frame noise
  if not self.cached_variables_for_editor then
    self:log('Retrieved ' .. #variables .. ' script material variables from metadata service')
  end

  return variables
end

function ExportTemplateEngine:_extract_session_script_columns()
  -- Implementation: Extract actual script material columns from session data
  -- This involves:
  -- 1. Accessing session storage for the current session_id
  -- 2. Finding configured script materials with their spreadsheet data
  -- 3. Extracting column headers from the spreadsheet data
  -- 4. Creating variable definitions with proper descriptions

  local variables = {}

  -- Get session configuration data
  local session_config = self.session_storage:table('session_config', {}):get()
  if not session_config or not session_config.script_materials then
    self:log('No script materials configuration found in session')
    return variables
  end

  -- Extract column information from configured script materials
  for material_guid, material_config in pairs(session_config.script_materials) do
    if material_config.metadata_layers then
      for _, layer in ipairs(material_config.metadata_layers) do
        -- Check if this is a spreadsheet-based metadata layer
        if layer.type == 'spreadsheet' and layer.data and layer.data.columns then
          -- Extract column headers and create variable definitions
          for column_name, column_info in pairs(layer.data.columns) do
            -- Skip internal/system columns
            if not column_name:match('^_') and column_name ~= 'id' then
              local description = column_info.description or ('Data from script material column: ' .. column_name)
              table.insert(variables, {
                name = self:normalize_column_name(column_name),
                description = description,
                source = 'script_material',
                material_guid = material_guid,
                original_column = column_name
              })
            end
          end
        end
      end
    end
  end

  -- Also try to extract from CSV data if available
  if session_config.script_materials then
    for material_guid, material_config in pairs(session_config.script_materials) do
      if material_config.csv_data and material_config.csv_headers then
        for i, header in ipairs(material_config.csv_headers) do
          -- Skip empty headers and system columns
          if header and header ~= '' and not header:match('^_') then
            table.insert(variables, {
              name = self:normalize_column_name(header),
              description = 'Column from script material: ' .. header,
              source = 'csv_data',
              material_guid = material_guid,
              original_column = header,
              column_index = i
            })
          end
        end
      end
    end
  end

  if #variables > 0 then
    self:log('Extracted ' .. #variables .. ' script material columns from session data')
  else
    self:log('No script material columns found in session data')
  end

  return variables
end

-- Helper function to normalize column names for template variable use
function ExportTemplateEngine:normalize_column_name(column_name)
  if not column_name then return '' end

  -- Convert to lowercase and replace spaces/special chars with underscores
  local normalized = string.lower(column_name)
  normalized = string.gsub(normalized, '[^%w_]', '_')
  normalized = string.gsub(normalized, '_+', '_')  -- Collapse multiple underscores
  normalized = string.gsub(normalized, '^_', '')   -- Remove leading underscore
  normalized = string.gsub(normalized, '_$', '')   -- Remove trailing underscore

  return normalized
end

-- Demo function to show real data integration with sample session data
function ExportTemplateEngine:demo_real_data_integration()
  self:log('Demo: Testing real data integration with sample session data')

  -- Sample session data structure (what would be stored in session JSON)
  local sample_session_data = {
    script_materials = {
      ['material-guid-1'] = {
        name = 'Game Script - Episode 1',
        metadata_layers = {
          {
            type = 'spreadsheet',
            data = {
              columns = {
                character_name = { description = 'Character speaking the line' },
                emotion_tag = { description = 'Emotional direction for delivery' },
                scene_location = { description = 'Scene location or setting' },
                line_priority = { description = 'Priority level for voice acting' }
              }
            }
          }
        },
        csv_headers = { 'Character', 'Scene', 'Line', 'Notes', 'Emotion' },
        csv_data = {
          { 'Hero', 'Forest', 'We need to find the ancient artifact', 'Urgent tone', 'determined' },
          { 'Villain', 'Castle', 'You will never stop me!', 'Menacing laugh', 'angry' }
        }
      }
    }
  }

  -- Temporarily set sample data for demo
  local original_session_data = self.session_storage:table('session_config', {}):get()
  self.session_storage:table('session_config', {}):set(sample_session_data)

  -- Extract variables using real data integration
  local extracted_variables = self:_extract_session_script_columns()

  self:log('Extracted ' .. #extracted_variables .. ' variables from sample session data:')
  for _, var in ipairs(extracted_variables) do
    self:log('  - ' .. var.name .. ': ' .. var.description .. ' (source: ' .. var.source .. ')')
  end

  -- Test template generation with sample curated match data
  local sample_match = {
    transcript_text = 'We need to find the ancient artifact',
    start_time = '45.2',
    end_time = '48.7',
    duration = '3.5',
    confidence = '0.94',
    track_name = 'Hero_Voice_Actor',
    file_name = 'episode1_forest.wav',
    segment_id = '12',
    script_material_data = {
      {
        character_name = 'Hero',
        emotion_tag = 'determined',
        scene_location = 'Forest',
        line_priority = 'High'
      }
    }
  }

  local test_template = '${character_name}_${emotion_tag}_${segment_id:padded}.wav'
  local generated_filename = self:generate_realistic_preview(test_template, { sample_match })

  self:log('Template: ' .. test_template)
  self:log('Generated filename: ' .. generated_filename)

  -- Restore original session data
  self.session_storage:table('session_config', {}):set(original_session_data)

  return {
    variables_extracted = #extracted_variables,
    sample_filename = generated_filename,
    demo_successful = true
  }
end

function ExportTemplateEngine:_get_media_variables()
  return {
    { name = 'track_name', description = 'REAPER track name' },
    { name = 'file_name', description = 'Source audio file name' },
    { name = 'file_path', description = 'Full path to source audio file' },
    { name = 'take_number', description = 'Take number within item' },
    { name = 'item_position', description = 'Media item position in timeline' },
    { name = 'project_name', description = 'REAPER project name' },
  }
end

-- Get available processors with descriptions
function ExportTemplateEngine:get_available_processors()
  return {
    { name = 'basename', description = 'Remove file extension' },
    { name = 'dirname', description = 'Extract directory path' },
    { name = 'uppercase', description = 'Convert to uppercase' },
    { name = 'lowercase', description = 'Convert to lowercase' },
    { name = 'slugify', description = 'Create filename-safe version' },
    { name = 'timecode', description = 'Format time as timecode' },
    { name = 'percent', description = 'Format as percentage' },
    { name = 'padded', description = 'Zero-pad numbers (001, 002, etc.)' }
  }
end

-- Safe table inspection function for debugging
function ExportTemplateEngine:safe_inspect_table(t, max_depth)
    max_depth = max_depth or 2
    if type(t) ~= "table" then
        return tostring(t)
    end

    local function inspect_recursive(table_ref, depth, seen)
        if depth > max_depth then
            return "{...}"
        end

        seen = seen or {}
        if seen[table_ref] then
            return "{circular}"
        end
        seen[table_ref] = true

        local parts = {}
        for k, v in pairs(table_ref) do
            local key_str = tostring(k)
            local value_str
            if type(v) == "table" then
                value_str = inspect_recursive(v, depth + 1, seen)
            else
                value_str = tostring(v)
            end
            table.insert(parts, key_str .. "=" .. value_str)
        end

        return "{" .. table.concat(parts, ", ") .. "}"
    end

    return inspect_recursive(t, 0, {})
end


-- Helper function for debugging - get all keys from a table
function ExportTemplateEngine:get_keys(t)
  if type(t) ~= 'table' then
    return {"(not a table)"}
  end

  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, tostring(k))
  end

  if #keys == 0 then
    return {"(empty table)"}
  end

  table.sort(keys)
  return keys
end

-- Invalidate cache when metadata changes (called by UI when metadata updates)
function ExportTemplateEngine:invalidate_cache()
  self.cached_variables_by_type = nil
  self.cached_variables_for_editor = nil
  self.cache_timestamp = 0
  self:log('Cache invalidated - variables will be refreshed on next access')
end

-- Get the static prefix of a template (everything before the first variable)
-- This is used to determine the export root directory for proper tree display
function ExportTemplateEngine:get_template_static_prefix(template)
  if not template then return '' end

  -- Find the position of the first variable
  local first_var_pos = string.find(template, "${")
  if not first_var_pos then
    -- No variables found, entire template is static
    return template
  end

  -- Return everything before the first variable
  local static_prefix = string.sub(template, 1, first_var_pos - 1)

  return static_prefix
end

-- Get the relative path portion of a generated filename. Only an
-- absolute static prefix is stripped (it acts as a custom export root);
-- a relative prefix is directory structure that belongs to the tree.
function ExportTemplateEngine:get_relative_path_from_filename(template, generated_filename)
  if not template or not generated_filename then return generated_filename or '' end

  local static_prefix = self:get_template_static_prefix(template)

  -- No absolute prefix: the entire filename is relative
  if not static_prefix or static_prefix == '' or not PathUtil.is_full_path(static_prefix) then
    return generated_filename
  end

  -- Check if the generated filename starts with the static prefix
  if string.sub(generated_filename, 1, #static_prefix) == static_prefix then
    return string.sub(generated_filename, #static_prefix + 1)
  else
    -- Filename doesn't start with expected prefix, return as-is
    self:log(string.format("Warning: Generated filename doesn't start with expected prefix. Filename: '%s', Expected prefix: '%s'",
             generated_filename, static_prefix))
    return generated_filename
  end
end


