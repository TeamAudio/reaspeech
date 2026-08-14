--[[

NeedleMetadataService.lua - Extract metadata from needle data for template variables and filters

Provides metadata extraction from processed needle data for:
- Export template variable lists (available variables and their values)
- Future curation navigation filters (filter options by metadata tag)

Works with needle data structure:
{
  "guid": "{5FC19351-FFF4-1F4C-892F-F61C91093DE3}",
  "metadata": [
    {
      "value": "Character One",
      "type": "tags",
      "tag": "character"
    }
  ],
  "content": "This is me testing my microphone.",
  "navigation": ["Script Matching Test Spreadsheet.xlsx", "Sheet1"]
}

]]--

NeedleMetadataService = Polo {}

function NeedleMetadataService:init()
  Logging().init(self, 'NeedleMetadataService')

  assert(self.session_id, 'NeedleMetadataService: session_id is required')
  assert(self.workflow, 'NeedleMetadataService: workflow is required for event emission')

  -- In-memory needle data (injected by phases via refresh_from_needles)
  self.needles = {}

  -- Cache for performance (cleared when needles update)
  self.cached_variables = nil
  self.cached_formatted_variables = nil
  self.cached_variable_values = {}
  self.cache_timestamp = 0

  self:log('Initialized NeedleMetadataService for session: ' .. self.session_id)
end

-- Refresh metadata service with new needle data from generator
function NeedleMetadataService:refresh_from_needles(needles)
  self.needles = needles or {}
  self:invalidate_cache()

  self:log('Refreshed with ' .. #self.needles .. ' needles from generator')

  -- Emit metadata variables changed event for consumers
  self.workflow:emit_event("metadata_variables_changed", {
    session_id = self.session_id,
    available_variables = self:get_available_template_variables()
  })
end

function NeedleMetadataService:invalidate_cache()
  self.cached_variables = nil
  self.cached_formatted_variables = nil
  self.cached_variable_values = {}
  self.cache_timestamp = 0
end

-- Get list of available template variable names across all needles
function NeedleMetadataService:get_available_template_variables()
  if self.cached_variables then
    return self.cached_variables
  end

  local variables = {}

  for _, needle in ipairs(self.needles) do
    if needle.metadata then
      for _, metadata in ipairs(needle.metadata) do
        if metadata.tag and metadata.tag ~= '' then
          variables[metadata.tag] = true
        end
      end
    end
  end

  -- Convert to array and sort
  local variable_list = {}
  for tag, _ in pairs(variables) do
    table.insert(variable_list, tag)
  end
  table.sort(variable_list)

  -- Cache result
  self.cached_variables = variable_list
  self.cache_timestamp = os.time()

  self:log('Extracted ' .. #variable_list .. ' template variables: ' .. table.concat(variable_list, ', '))

  return variable_list
end

-- Get unique values for a specific template variable/tag
function NeedleMetadataService:get_template_variable_values(tag_name)
  if not tag_name or tag_name == '' then
    return {}
  end

  -- Check cache first
  if self.cached_variable_values[tag_name] then
    return self.cached_variable_values[tag_name]
  end

  local values = {}

  for _, needle in ipairs(self.needles) do
    if needle.metadata then
      for _, metadata in ipairs(needle.metadata) do
        if metadata.tag == tag_name and metadata.value and metadata.value ~= '' then
          values[metadata.value] = true
        end
      end
    end
  end

  -- Convert to array and sort
  local value_list = {}
  for value, _ in pairs(values) do
    table.insert(value_list, value)
  end
  table.sort(value_list)

  -- Cache result
  self.cached_variable_values[tag_name] = value_list

  self:log('Extracted ' .. #value_list .. ' values for tag "' .. tag_name .. '": ' .. table.concat(value_list, ', '))

  return value_list
end

-- Get available metadata for export (for a specific needle or all needles)
function NeedleMetadataService:get_needle_metadata_for_export(needle_guid)
  if needle_guid then
    -- Return metadata for specific needle
    for _, needle in ipairs(self.needles) do
      if needle.guid == needle_guid then
        return self:extract_needle_metadata(needle)
      end
    end
    return {}
  else
    -- Return metadata for all needles
    local all_metadata = {}
    for _, needle in ipairs(self.needles) do
      all_metadata[needle.guid] = self:extract_needle_metadata(needle)
    end
    return all_metadata
  end
end

-- Get variable value for a specific needle (used by ExportTemplateEngine)
function NeedleMetadataService:get_variable_value(variable_name, needle_data)
  if not needle_data then return nil end

  -- First, try direct property access for curated match data
  -- This handles variables that are already extracted at the top level
  if needle_data[variable_name] then
    return needle_data[variable_name]
  end

  -- If this is curated match data with nested needle, try extracting from needle metadata
  if needle_data.needle and needle_data.needle.metadata then
    for _, meta in ipairs(needle_data.needle.metadata) do
      if meta.tag == variable_name and meta.value then
        return meta.value
      end
    end
  end

  -- If this is pure needle data with a guid, use standard extraction
  if needle_data.guid and needle_data.metadata then
    local metadata = self:extract_needle_metadata(needle_data)
    return metadata[variable_name]
  end

  -- Legacy: try to extract from script_material_data format
  if needle_data.script_material_data then
    for _, material in pairs(needle_data.script_material_data) do
      if material[variable_name] then
        return material[variable_name]
      end
    end
  end

  return nil
end

-- Get sample needles for template preview
function NeedleMetadataService:get_sample_needles_for_preview(max_samples)
  max_samples = max_samples or 3

  local samples = {}

  -- Take first few needles as samples
  for i = 1, math.min(max_samples, #self.needles) do
    local needle = self.needles[i]
    local sample_data = {
      guid = needle.guid,
      content = needle.content,
      metadata = self:extract_needle_metadata(needle)
    }
    table.insert(samples, sample_data)
  end

  self:log('Returning ' .. #samples .. ' sample needles for preview')
  return samples
end

-- Get metadata summary for navigation filters
function NeedleMetadataService:get_metadata_summary_for_filters()
  local summary = {}

  for _, needle in ipairs(self.needles) do
    if needle.metadata then
      for _, meta in ipairs(needle.metadata) do
        if meta.tag and meta.value then
          if not summary[meta.tag] then
            summary[meta.tag] = {}
          end

          -- Count unique values for each tag
          if not summary[meta.tag][meta.value] then
            summary[meta.tag][meta.value] = 0
          end
          summary[meta.tag][meta.value] = summary[meta.tag][meta.value] + 1
        end
      end
    end
  end

  local filter_count = 0
  for _ in pairs(summary) do
    filter_count = filter_count + 1
  end

  self:log('Generated metadata summary for ' .. filter_count .. ' filter categories')
  return summary
end

-- Get all metadata for a specific needle (for export filename generation)
-- Get metadata summary for all variables (useful for curation filters)
function NeedleMetadataService:get_metadata_summary()
  local variables = self:get_available_template_variables()
  local summary = {}

  for _, tag in ipairs(variables) do
    local values = self:get_template_variable_values(tag)
    summary[tag] = {
      tag = tag,
      value_count = #values,
      values = values
    }
  end

  self:log('Generated metadata summary for ' .. #variables .. ' variables')

  return summary
end

-- Get variables formatted for export template editor UI
function NeedleMetadataService:get_variables_for_template_editor()
  -- Return cached result if available
  if self.cached_formatted_variables then
    return self.cached_formatted_variables
  end

  local variables = self:get_available_template_variables()
  local formatted_variables = {}

  for _, tag in ipairs(variables) do
    local values = self:get_template_variable_values(tag)
    local sample_value = values[1] or 'sample_value'

    table.insert(formatted_variables, {
      name = tag,
      description = 'Session data: ' .. tag .. ' (e.g., "' .. sample_value .. '")',
      source = 'session_data',
      sample_value = sample_value,
      type = 'dynamic'  -- These are all dynamic variables from session data
    })
  end

  -- Cache the result
  self.cached_formatted_variables = formatted_variables

  -- Only log when cache is rebuilt to avoid per-frame noise
  self:log('Built formatted variables cache: ' .. #formatted_variables .. ' dynamic variables for template editor')

  return formatted_variables
end

-- Helper method to extract metadata from needle data structure
function NeedleMetadataService:extract_needle_metadata(needle)
  local metadata_map = {}

  if not needle then return metadata_map end

  -- Extract metadata from needle.metadata array
  if needle.metadata then
    for _, meta in ipairs(needle.metadata) do
      if meta.tag and meta.value then
        metadata_map[meta.tag] = meta.value
      end
    end
  end

  -- Add standard needle properties as metadata
  metadata_map.needle_content = needle.content or ''
  metadata_map.needle_guid = needle.guid or ''

  -- Add navigation information if available
  if needle.navigation then
    metadata_map.source_file = needle.navigation[1] or ''
    metadata_map.source_sheet = needle.navigation[2] or ''
  end

  return metadata_map
end

-- Emit event when metadata variables change (for workflow coordination)
function NeedleMetadataService:emit_variables_changed_event()
  local variables = self:get_available_template_variables()

  self.workflow:emit_event("metadata_variables_changed", {
    session_id = self.session_id,
    available_variables = variables,
    variable_count = #variables
  })

  self:log('Emitted metadata_variables_changed event with ' .. #variables .. ' variables')
end
