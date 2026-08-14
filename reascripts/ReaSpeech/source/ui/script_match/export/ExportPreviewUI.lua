--[[

ExportPreviewUI.lua - Right panel container for export preview tree and actions

]]--

ExportPreviewUI = Polo {}

function ExportPreviewUI:init()
  Logging().init(self, 'ExportPreviewUI')

  assert(self.settings, 'ExportPreviewUI: settings is required')
  assert(self.session_id, 'ExportPreviewUI: session_id is required')
  assert(self.template_engine, 'ExportPreviewUI: template_engine is required')
  assert(self.workflow, 'ExportPreviewUI: workflow is required for event emission')

  -- Initialize data service for loading real export data
  self.data_service = ExportDataService.new {
    session_id = self.session_id,
    template_engine = self.template_engine,
    workflow = self.workflow,
  }

  -- The second export target: accepted takes landed in the project
  -- as sibling tracks
  self.track_exporter = TrackExporter.new {
    session_id = self.session_id,
  }

  self:log("Initialized ExportPreviewUI with real data service")
end

-- Track the template as typed, ahead of it being committed to settings,
-- so the tree preview reacts per keystroke
function ExportPreviewUI:set_live_template(value)
  if value == self._live_template then return end

  self._live_template = value
  -- Only the filename/tree half needs rebuilding; enriched matches are
  -- template-independent and stay cached
  self.data_service:invalidate_items()
end

function ExportPreviewUI:render(_width)
  -- Get current template and settings for data generation
  local current_template = self._live_template or self.settings:get_template()

  -- Generate export items from real data; timing shapes the slice
  -- ranges the size/duration figures describe
  local export_directories = self.data_service:generate_export_items(current_template, self.settings:get_timing())

  -- Calculate summary statistics from hierarchical tree
  local total_files = 0
  local total_size = 0
  local exported_count = 0
  local failed_count = 0

  local function count_files_recursive(nodes)
    for _, node in ipairs(nodes) do
      -- Count files in this directory
      for _, file in ipairs(node.files) do
        total_files = total_files + 1
        total_size = total_size + (file.file_size_estimate or 0)
        if file.status == 'completed' then
          exported_count = exported_count + 1
        elseif file.status == 'failed' then
          failed_count = failed_count + 1
        end
      end
      -- Recurse into children
      count_files_recursive(node.children)
    end
  end

  count_files_recursive(export_directories)

  -- Export summary header
  local formatted_size = self.data_service:format_file_size(total_size)
  local summary_text = string.format("%d files • %s estimated • %d exported",
    total_files, formatted_size, exported_count)
  ImGui.TextColored(Ctx(), 0x4CAF50FF, summary_text)
  ImGui.TextColored(Ctx(), 0x888888FF, "-> " .. self:get_export_root_directory())

  if self._last_export then
    local last = self._last_export
    local color = last.success == last.total and 0x4CAF50FF or 0xFFB74DFF
    ImGui.TextColored(Ctx(), color,
      string.format("Last export: %d/%d files at %s", last.success, last.total, last.when))
  end

  ImGui.Spacing(Ctx())

  -- Render file tree from real data
  self:render_export_tree(export_directories)

  ImGui.Spacing(Ctx())

  -- Action buttons: Export takes what isn't done yet (including
  -- failures - a retry IS an export of the remainder); Re-export All
  -- appears once something is done and runs the whole set again
  local remaining_count = total_files - exported_count
  local export_label = failed_count > 0
    and string.format("Export (%d, %d failed)", remaining_count, failed_count)
    or string.format("Export (%d)", remaining_count)

  Widgets.disable_if(remaining_count == 0, function()
    if ImGui.Button(Ctx(), export_label) then
      self:start_export(true)
    end
  end, total_files > 0 and 'Everything is exported' or nil)

  if exported_count > 0 then
    ImGui.SameLine(Ctx())
    if ImGui.Button(Ctx(), string.format("Re-export All (%d)", total_files)) then
      self:start_export(false)
    end
  end

  ImGui.SameLine(Ctx())
  -- Stat the root only when it changes (or after an export run), not
  -- every frame
  local output_root = self:get_export_root_directory()
  if self._folder_check_path ~= output_root then
    self._folder_check_path = output_root
    self._folder_exists = reaper.file_exists(output_root)
  end
  Widgets.disable_if(not self._folder_exists, function()
    if ImGui.Button(Ctx(), "Open Output Folder") then
      self:open_output_folder()
    end
  end, 'Nothing has been exported there yet')

  -- Tracks target: the same accepted takes, landed in the project as
  -- spotty muted child tracks whose items reference the original
  -- sources (solo to audition through the source's chain)
  ImGui.Spacing(Ctx())
  Widgets.disable_if(total_files == 0, function()
    if ImGui.Button(Ctx(), string.format("Export to Tracks (%d)", total_files)) then
      self:start_track_export()
    end
  end)
  Widgets.tooltip("A muted child track per source: matched sections as items "
    .. "referencing the original audio, colored by confidence. "
    .. "Solo to audition.")

  ImGui.SameLine(Ctx())
  local changed, regions_on = ImGui.Checkbox(Ctx(), "Also create regions",
    self.settings.tracks_regions:get())
  if changed then
    self.settings.tracks_regions:set(regions_on)
  end
  Widgets.tooltip("Named, confidence-colored regions at each matched span. "
    .. "The ruler becomes the heatmap, and the region render matrix can "
    .. "batch-render matches. Re-exports replace this session's regions.")

  if self._last_track_export then
    local last = self._last_track_export
    local text = string.format("Last: %d items on %d tracks",
      last.placed, last.tracks)
    if (last.regions or 0) > 0 then
      text = text .. string.format(", %d regions", last.regions)
    end
    if last.skipped > 0 then
      text = text .. string.format(", %d skipped", last.skipped)
    end
    ImGui.TextColored(Ctx(), 0x888888FF, text .. " at " .. last.when)
  end

  ImGui.Spacing(Ctx())
  if total_files == 0 then
    ImGui.TextColored(Ctx(), 0xFFFF80FF, "No accepted suggestions found. Complete curation phase first.")
  end
end

-- Land every accepted take on its source's matched child track.
-- Always the full set: the tracks target has no per-file completion
-- to skip - a re-export replaces the previous landing wholesale.
function ExportPreviewUI:start_track_export()
  local current_template = self._live_template or self.settings:get_template()
  local tree = self.data_service:generate_export_items(current_template, self.settings:get_timing())

  local queue = {}
  local function collect_files(nodes)
    for _, node in ipairs(nodes) do
      for _, file_item in ipairs(node.files) do
        table.insert(queue, file_item)
      end
      collect_files(node.children)
    end
  end
  collect_files(tree)

  local opts = {}
  if self.settings.tracks_regions:get() then
    opts.regions = true
    opts.region_ledger = self.settings.tracks_region_ledger:get()
  end

  local ok, result = pcall(self.track_exporter.export, self.track_exporter, queue, opts)
  if not ok then
    self:log("Track export failed: " .. tostring(result))
    return
  end

  -- Persist the new ledger so the NEXT run can replace these regions
  if result.region_ledger then
    self.settings.tracks_region_ledger:set(result.region_ledger)
  end

  self._last_track_export = {
    placed = result.placed,
    tracks = result.tracks,
    regions = result.regions,
    skipped = result.skipped,
    when = os.date('%H:%M:%S'),
  }
end

function ExportPreviewUI:render_export_tree(export_directories)
  for _, directory in ipairs(export_directories) do
    self:render_directory_node(directory)
  end
end

function ExportPreviewUI:render_directory_node(directory)
  local tree_label = directory.path == "" and "(Root)" or (directory.display_name .. "/")

  EmojiText.icon('folder')
  ImGui.SameLine(Ctx(), 0, 4)

  -- Set nodes to be expanded by default for better visual impact
  ImGui.SetNextItemOpen(Ctx(), true, ImGui.Cond_FirstUseEver())

  if ImGui.TreeNode(Ctx(), tree_label) then
    Trap(function()
      -- Render files in this directory
      for _, file in ipairs(directory.files) do
        self:render_file_node(file)
      end

      -- Render child directories recursively
      for _, child_directory in ipairs(directory.children) do
        self:render_directory_node(child_directory)
      end
    end)

    ImGui.TreePop(Ctx())
  end
end

function ExportPreviewUI:render_file_node(file)
  -- Tree node labels are label slots (no images), so the status icon
  -- renders as its own item ahead of the node
  EmojiText.icon(self:get_status_icon(file.status))
  ImGui.SameLine(Ctx(), 0, 4)
  EmojiText.icon('wav')
  ImGui.SameLine(Ctx(), 0, 4)

  local file_info = string.format("%s  %s", file.formatted_size, file.formatted_duration)

  -- Plain text, not a leaf TreeNode: leaves still reserve the
  -- collapsing-arrow slot, which read as a phantom gap after the icon
  local display_text = string.format("%s      %s", file.display_name, file_info)

  ImGui.Text(Ctx(), display_text)

  -- Add tooltip with additional info
  if ImGui.IsItemHovered(Ctx()) then
    ImGui.BeginTooltip(Ctx())
    ImGui.Text(Ctx(), "Confidence: " .. string.format("%.1f%%", (file.confidence or 0) * 100))
    ImGui.Text(Ctx(), "Duration: " .. string.format("%.2fs", file.duration))
    if file.status == 'failed' then
      ImGui.TextColored(Ctx(), 0xFF4444FF, "Status: Failed")
      -- TODO: Show error details when available
    elseif file.status == 'completed' then
      ImGui.TextColored(Ctx(), 0x44FF44FF, "Status: Exported successfully")
    elseif file.status == 'exporting' then
      ImGui.TextColored(Ctx(), 0xFFFF44FF, "Status: Currently exporting...")
    else
      ImGui.TextColored(Ctx(), 0x888888FF, "Status: Pending export")
    end
    ImGui.EndTooltip(Ctx())
  end

  -- Jump to this file's origin: the needle and suggestion it was
  -- sliced from, over in curation. (Rendered after the info tooltip's
  -- IsItemHovered so that still reads the text item, not this icon.)
  ImGui.SameLine(Ctx(), 0, 10)
  local jump_size = Fonts.size:get() - 3
  if Widgets.icon(Icons.jump, '##goto-' .. (file.export_id or tostring(file.display_name)),
    jump_size, jump_size, 'Go to this line in Curation', 0x666666FF, Theme.COLORS.pink_opaque)
  then
    self:jump_to_curation(file)
  end
end

-- From a file row back to its origin: activate curation, navigate to
-- the needle, focus the suggestion the file was sliced from
function ExportPreviewUI:jump_to_curation(file)
  local match = file.match
  if not match or not match.needle_guid then
    self:log("Jump requested but the file row carries no needle context")
    return
  end

  self.workflow:activate_phase('curation')
  self.workflow:emit_event('curation_jump_requested', {
    needle_id = match.needle_guid,
    suggestion_id = match.guid,
  })
end

function ExportPreviewUI:get_status_icon(status)
  if status == 'completed' then
    return 'check'
  elseif status == 'failed' then
    return 'error'
  elseif status == 'skipped' then
    return 'stopped'
  elseif status == 'exporting' then
    return 'progress'
  else
    return 'hourglass' -- pending
  end
end

function ExportPreviewUI:start_export(skip_completed)
  self:log("Starting production batch export...")

  -- Export what the preview shows: the tree renders from the live
  -- (in-flight) template value, so exporting the committed one could
  -- produce different filenames than the ones on screen mid-edit
  local current_template = self._live_template or self.settings:get_template()
  self:log("Current template: " .. current_template)

  -- Generate export items from real data
  local export_items = self.data_service:generate_export_items(current_template, self.settings:get_timing())

  local success_count, total_count = self:process_all_export_items(export_items, skip_completed)
  if total_count == 0 then
    self:log("Nothing to export")
    return
  end

  self:show_export_summary(success_count, total_count)

  -- The export may have just created the output root
  self._folder_check_path = nil

  if self.settings:get_options().open_folder_when_done and success_count > 0 then
    self:open_output_folder()
  end
end

function ExportPreviewUI:open_output_folder()
  ExecProcess.new(PathUtil.get_open_folder_command(self:get_export_root_directory())):no_wait()
end

-- Cache invalidation when template or settings change
function ExportPreviewUI:invalidate_cache()
  if self.data_service then
    self.data_service:invalidate_cache()
  end
end

function ExportPreviewUI:extract_audio_file(export_item)
  -- Export item times are relative to the source media file the match was
  -- transcribed from. Locate that file via the project (which item/take
  -- plays it), then slice the range directly out of the file on disk -
  -- no project mutation, no render engine, no undo.
  local range = SuggestionTimeline.resolve(export_item)
  if not range or not range.source_path or range.source_path == '' then
    return false, "Could not locate the matched audio in the project"
  end

  local timing = self.settings:get_timing()
  local start_seconds = (export_item.start_time or 0) - (timing.pre_roll_seconds or 0)
  local end_seconds = (export_item.end_time or 0) + (timing.post_roll_seconds or 0)

  -- Honor Minimum Duration: short clips extend at the tail
  local min_duration = timing.min_duration_seconds or 0
  if end_seconds - start_seconds < min_duration then
    end_seconds = start_seconds + min_duration
  end

  local output_path = self:get_output_full_path(export_item)

  -- Honor the Overwrite option: an existing file stays untouched and
  -- counts as done (it is on disk)
  if not self.settings:get_options().overwrite_existing and reaper.file_exists(output_path) then
    self:log("Exists and Overwrite is off - keeping: " .. output_path)
    return true
  end

  self:log(string.format("Slicing %.2fs-%.2fs of '%s' -> '%s'",
    start_seconds, end_seconds, range.source_path, output_path))

  local ok, err = WavFile.slice(range.source_path, output_path, start_seconds, end_seconds)
  if not ok then
    self:log("Extraction failed: " .. (err or "unknown"))
    return false, err
  end

  self:log("Extraction successful")
  return true
end

-- The export root: an absolute static template prefix (e.g.
-- "/Users/me/GameAudio/${...}") IS the root; anything else - including
-- relative prefixes like "session_export/${...}" - goes under
-- <project>/reaspeech_export, with the relative structure preserved.
function ExportPreviewUI:get_export_root_directory()
  local current_template = self.settings:get_template()

  if current_template and current_template ~= '' then
    local prefix = self.template_engine:get_template_static_prefix(current_template)
    if prefix and prefix ~= '' and PathUtil.is_full_path(prefix) then
      return (PathUtil.normalize(prefix):gsub("/+$", ""))
    end
  end

  return PathUtil.normalize(reaper.GetProjectPath() .. "/reaspeech_export")
end

function ExportPreviewUI:find_common_path(path1, path2)
  local parts1 = {}
  local parts2 = {}

  for part in path1:gmatch("[^/]+") do
    table.insert(parts1, part)
  end

  for part in path2:gmatch("[^/]+") do
    table.insert(parts2, part)
  end

  local common_parts = {}
  local min_length = math.min(#parts1, #parts2)

  for i = 1, min_length do
    if parts1[i] == parts2[i] then
      table.insert(common_parts, parts1[i])
    else
      break
    end
  end

  if #common_parts == 0 then
    return PathUtil.normalize(reaper.GetProjectPath() .. "/reaspeech_export")  -- Fallback
  end

  return "/" .. table.concat(common_parts, "/")
end

function ExportPreviewUI:get_output_full_path(export_item)
  local export_root = self:get_export_root_directory()
  local current_template = self.settings:get_template()

  -- Relative to the export root: an absolute template prefix is already
  -- accounted for by the root itself; relative structure is preserved
  local relative_filename =
    self.template_engine:get_relative_path_from_filename(current_template, export_item.filename)
  relative_filename = relative_filename:gsub("^/+", "")

  local full_path = export_root .. "/" .. relative_filename
  self:log(string.format("Output path: '%s'", full_path))

  -- Ensure directory exists
  local directory = full_path:match("(.+)/[^/]+$")
  if directory then
    reaper.RecursiveCreateDirectory(directory, 0)
  end

  return full_path
end

function ExportPreviewUI:process_all_export_items(export_items, skip_completed)
  -- Flatten the tree into the work queue, leaving completed files
  -- alone when asked (Export vs Re-export All)
  local queue = {}
  local function collect_files(nodes)
    for _, node in ipairs(nodes) do
      for _, file_item in ipairs(node.files) do
        if not (skip_completed and file_item.status == 'completed') then
          table.insert(queue, file_item)
        end
      end
      collect_files(node.children)
    end
  end
  collect_files(export_items)

  self:log(string.format("Processing %d files", #queue))

  local options = self.settings:get_options()
  local success_count = 0

  for i, file_item in ipairs(queue) do
    self:log(string.format("Processing file %d of %d: %s", i, #queue, file_item.display_name))

    -- Protected call: a crashing item must not abort the batch
    local ok, success, error_msg = pcall(self.extract_audio_file, self, file_item)
    if not ok then
      success, error_msg = false, tostring(success)
    end

    if success then
      success_count = success_count + 1
      self:log("✅ Exported successfully")
    else
      self:log(string.format("❌ Export failed: %s", error_msg or "unknown"))
    end

    -- Persist per-file status so the tree shows real outcomes
    if file_item.export_id then
      self.data_service:set_export_status(
        file_item.export_id, success and 'completed' or 'failed')
    end

    if not success and not options.skip_on_error then
      self:log("Stopping at first error (Skip errors and continue is off)")
      break
    end
  end

  return success_count, #queue
end

function ExportPreviewUI:show_export_summary(success_count, total_count)
  local failure_count = total_count - success_count
  local success_rate = math.floor((success_count / total_count) * 100)

  -- Surface the result in the panel, not just the log
  self._last_export = {
    success = success_count,
    total = total_count,
    when = os.date('%H:%M:%S'),
  }

  -- Rebuild the tree so per-file status icons reflect this run
  self.data_service:invalidate_items()

  self:log("=== EXPORT SUMMARY ===")
  self:log(string.format("✅ Exported: %d files", success_count))
  if failure_count > 0 then
    self:log(string.format("❌ Failed: %d files", failure_count))
  end
  self:log(string.format("📊 Success Rate: %d%% (%d of %d)", success_rate, success_count, total_count))

  if success_count == total_count then
    self:log("🎉 All files exported successfully!")
  elseif success_count > 0 then
    self:log("⚠️ Partial export completed - check failed files above")
  else
    self:log("🚨 Export failed - no files were exported")
  end
end
