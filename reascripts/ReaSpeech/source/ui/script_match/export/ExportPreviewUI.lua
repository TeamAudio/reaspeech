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

  -- File export runs deferred under a per-frame tick budget: the
  -- Export card doubles as the progress bar and cancel button. The
  -- queue holds the same file tables the tree renders, so statuses
  -- land live as items complete.
  self.export_runner = ExportRunner.new {
    process_item = function(item)
      return self:extract_audio_file(item)
    end,
    on_item_done = function(item, status)
      item.status = status
      if item.export_id then
        self.data_service:set_export_status(item.export_id, status)
      end
    end,
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

-- Above this many files the tree opens with directories collapsed,
-- leaning on the per-directory counts instead of a wall of rows
ExportPreviewUI.COLLAPSE_THRESHOLD = 50

-- One pass over the tree: global totals for the summary and action
-- labels, per-directory subtree counts for the "(n files)" suffixes
function ExportPreviewUI:tally(export_directories)
  local stats = { files = 0, size = 0, exported = 0, failed = 0 }

  local function visit(nodes)
    local count = 0
    for _, node in ipairs(nodes) do
      for _, file in ipairs(node.files) do
        stats.size = stats.size + (file.file_size_estimate or 0)
        if file.status == 'completed' then
          stats.exported = stats.exported + 1
        elseif file.status == 'failed' then
          stats.failed = stats.failed + 1
        end
      end
      node.subtree_file_count = #node.files + visit(node.children)
      count = count + node.subtree_file_count
    end
    return count
  end

  stats.files = visit(export_directories)
  return stats
end

-- A filtered shadow of the tree: directories keep only matching files
-- (and children that kept something); the original nodes stay untouched
function ExportPreviewUI.filter_tree(nodes, needle)
  local out = {}
  for _, node in ipairs(nodes) do
    local files = {}
    for _, file in ipairs(node.files) do
      if tostring(file.display_name or ''):lower():find(needle, 1, true) then
        table.insert(files, file)
      end
    end
    local children = ExportPreviewUI.filter_tree(node.children, needle)
    if #files > 0 or #children > 0 then
      table.insert(out, setmetatable({ files = files, children = children },
        { __index = node }))
    end
  end
  return out
end

function ExportPreviewUI:render(_width)
  -- While a run is going the tree renders from the snapshot the run
  -- was started with: mid-run template edits and per-item dirty flags
  -- can't reshape the thing the progress is landing on
  local export_directories
  if self.export_runner:is_running() then
    export_directories = self._running_tree or {}
  else
    local current_template = self._live_template or self.settings:get_template()
    -- Timing shapes the slice ranges the size/duration figures describe
    export_directories = self.data_service:generate_export_items(current_template, self.settings:get_timing())
  end

  local stats = self:tally(export_directories)

  -- The display tree narrows under the filter box; the action cards
  -- and summary always speak for the full set
  local display_tree = export_directories
  local filter = (self._tree_filter or ''):lower():match('^%s*(.-)%s*$')
  if filter ~= '' then
    display_tree = ExportPreviewUI.filter_tree(export_directories, filter)
    self:tally(display_tree)
  end

  -- Summary strip
  local formatted_size = self.data_service:format_file_size(stats.size)
  local summary_text = string.format("%d files • %s estimated • %d exported",
    stats.files, formatted_size, stats.exported)
  ImGui.TextColored(Ctx(), 0x4CAF50FF, summary_text)
  ImGui.TextColored(Ctx(), 0x888888FF, "-> " .. self:get_export_root_directory())

  if self._last_export then
    local last = self._last_export
    local color = last.success == last.total and 0x4CAF50FF or 0xFFB74DFF
    ImGui.TextColored(Ctx(), color,
      string.format("Last export: %d/%d files at %s", last.success, last.total, last.when))
  end

  ImGui.Spacing(Ctx())
  self:render_tree_filter(stats, display_tree)

  -- The preview scrolls in its own region; the action band below is
  -- pinned and never scrolls out of reach
  if ImGui.BeginChild(Ctx(), 'export-tree-region', 0, -self:action_band_height()) then
    Trap(function()
      if stats.files == 0 then
        ImGui.TextColored(Ctx(), 0xFFFF80FF,
          "No accepted suggestions found. Complete curation phase first.")
      else
        self:render_export_tree(display_tree, {
          default_open = stats.files <= ExportPreviewUI.COLLAPSE_THRESHOLD,
          force_open = filter ~= '',
        })
      end
    end)
    ImGui.EndChild(Ctx())
  end

  self:render_action_band(stats)
end

function ExportPreviewUI:render_tree_filter(stats, display_tree)
  if stats.files == 0 then return end

  ImGui.SetNextItemWidth(Ctx(), 220)
  local rv, value = ImGui.InputTextWithHint(Ctx(), '##export-tree-filter',
    'Filter files...', self._tree_filter or '')
  if rv then
    self._tree_filter = value
  end

  if (self._tree_filter or '') ~= '' then
    ImGui.SameLine(Ctx())
    if ImGui.SmallButton(Ctx(), 'Clear') then
      self._tree_filter = ''
    end
    ImGui.SameLine(Ctx())
    local shown = 0
    for _, node in ipairs(display_tree) do
      shown = shown + (node.subtree_file_count or 0)
    end
    ImGui.TextColored(Ctx(), 0x888888FF, ('%d of %d match'):format(shown, stats.files))
  end
end

ExportPreviewUI.CARD = {
  HEIGHT = 46,
  ROUNDING = 6,
  PADDING = 12,
  GAP = 10,
  PRESS_NUDGE = 1,
  ICON_SIZE = 24,
}

-- Everything below the tree region: three big pressable cards (Files
-- / Tracks / Regions - each an honest, independent press; tracks AND
-- regions is two presses, safe because both landings replace their
-- own previous run) over a quiet row of secondary controls. Fixed
-- height so the tree child can reserve exactly this much.
function ExportPreviewUI:action_band_height()
  local h = 6 + ExportPreviewUI.CARD.HEIGHT + 6 + ImGui.GetFrameHeightWithSpacing(Ctx())
  if self._last_track_export then
    h = h + ImGui.GetTextLineHeightWithSpacing(Ctx())
  end
  return h
end

function ExportPreviewUI:render_action_band(stats)
  local c = ExportPreviewUI.CARD
  local runner = self.export_runner

  -- A finished run finalizes on the next frame: counts read, statuses
  -- already persisted per item, tree rebuilt fresh
  if runner.state == 'done' then
    self:finish_export_run()
  end

  -- Drive the run before any drawing: a render error below (trapped
  -- or not) must never be able to stall an in-flight export
  if runner:is_running() then
    runner:tick()
  end

  ImGui.Dummy(Ctx(), 0, 4)
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local avail = ImGui.GetContentRegionAvail(Ctx())
  local card_w = math.floor((avail - c.GAP * 2) / 3)

  local running = runner:is_running()
  local remaining = stats.files - stats.exported

  -- Files card: idle it begs to be pressed; running it IS the
  -- progress bar and the cancel button
  local files_opts
  if running then
    files_opts = {
      width = card_w, icon = 'wav',
      progress = runner.total > 0 and (runner.completed / runner.total) or 0,
      title = ('Exporting… %d/%d'):format(runner.completed, runner.total),
      tagline = 'Click to cancel',
    }
  else
    files_opts = {
      width = card_w, icon = 'wav',
      halo = remaining > 0,
      disabled = remaining == 0,
      title = stats.failed > 0
        and ('Export Files (%d, %d failed)'):format(remaining, stats.failed)
        or ('Export Files (%d)'):format(remaining),
      tagline = remaining == 0
        and (stats.files > 0 and 'Everything is exported' or 'Nothing to export yet')
        or 'Slice accepted takes to disk',
      tooltip = 'Slice each accepted take out of its source WAV, into the output folder. '
        .. 'Failures count as remaining - exporting again retries them.',
    }
  end

  ImGui.SetCursorScreenPos(Ctx(), x, y)
  if self:render_action_card('##export-files-card', files_opts) then
    if running then
      runner:cancel()
    elseif remaining > 0 then
      self:start_export(true)
    end
  end

  local project_disabled = running or stats.files == 0

  ImGui.SetCursorScreenPos(Ctx(), x + card_w + c.GAP, y)
  if self:render_action_card('##export-tracks-card', {
    width = card_w, icon = 'headphone',
    disabled = project_disabled,
    title = ('Export Tracks (%d)'):format(stats.files),
    tagline = 'Muted child tracks to audition',
    tooltip = 'A muted child track per source: matched sections as items '
      .. 'referencing the original audio, colored by confidence. Solo to '
      .. 'audition. Re-exports refill the same tracks.',
  }) then
    self:start_project_export({ tracks = true })
  end

  ImGui.SetCursorScreenPos(Ctx(), x + (card_w + c.GAP) * 2, y)
  if self:render_action_card('##export-regions-card', {
    width = avail - (card_w + c.GAP) * 2, icon = 'pin',
    disabled = project_disabled,
    title = ('Export Regions (%d)'):format(stats.files),
    tagline = 'The ruler becomes the heatmap',
    tooltip = 'Named, confidence-colored regions at each matched span; the '
      .. 'region render matrix can batch-render matches. Re-exports replace '
      .. 'this session\'s regions. Want tracks too? Press both cards.',
  }) then
    self:start_project_export({ regions = true })
  end

  ImGui.SetCursorScreenPos(Ctx(), x, y + c.HEIGHT + 6)
  -- The quiet row may render nothing; the cursor move must not be the
  -- band's last submission (same EndChild assertion as the cards)
  ImGui.Dummy(Ctx(), 0, 0)
  ImGui.SameLine(Ctx(), 0, 0)

  -- Quiet row: the less-juicy actions
  local quiet_row_used = false
  if stats.exported > 0 and not running then
    if ImGui.SmallButton(Ctx(), ('Re-export All (%d)'):format(stats.files)) then
      self:start_export(false)
    end
    quiet_row_used = true
  end

  -- Stat the root only when it changes (or after an export run), not
  -- every frame
  local output_root = self:get_export_root_directory()
  if self._folder_check_path ~= output_root then
    self._folder_check_path = output_root
    self._folder_exists = reaper.file_exists(output_root)
  end
  if self._folder_exists then
    if quiet_row_used then
      ImGui.SameLine(Ctx(), 0, 18)
    end
    if ImGui.SmallButton(Ctx(), 'Open Output Folder') then
      self:open_output_folder()
    end
  end

  if self._last_track_export then
    local last = self._last_track_export
    local parts = {}
    if last.placed > 0 then
      table.insert(parts, ('%d items on %d tracks'):format(last.placed, last.tracks))
    end
    if (last.regions or 0) > 0 then
      table.insert(parts, ('%d regions'):format(last.regions))
    end
    if last.skipped > 0 then
      table.insert(parts, ('%d skipped'):format(last.skipped))
    end
    ImGui.TextColored(Ctx(), 0x888888FF,
      'Last: ' .. table.concat(parts, ', ') .. ' at ' .. last.when)
  end

end

-- One pressable action card in the phase-selector language:
-- InvisibleButton hit area, DrawList body, halo when begging, progress
-- fill while running. Returns true on click. The body runs under its
-- own Trap: a card that errors renders as nothing, and its siblings
-- (and the band around them) keep working.
function ExportPreviewUI:render_action_card(id, opts)
  local clicked = false
  Trap(function()
    clicked = self:render_action_card_body(id, opts)
  end)
  return clicked
end

function ExportPreviewUI:render_action_card_body(id, opts)
  local c = ExportPreviewUI.CARD
  local x, y = ImGui.GetCursorScreenPos(Ctx())
  local w = opts.width

  local clicked = ImGui.InvisibleButton(Ctx(), id, w, c.HEIGHT)
  local hovered = ImGui.IsItemHovered(Ctx())
  local held = ImGui.IsItemActive(Ctx()) and not opts.disabled

  if hovered and not opts.disabled then
    ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
  end
  if opts.tooltip then
    Widgets.tooltip(opts.tooltip)
  end

  local dl = ImGui.GetWindowDrawList(Ctx())

  -- Halo with a slow pulse; hover holds it at full glow
  if opts.halo and not opts.disabled then
    local pulse = hovered and 1 or (0.5 + 0.5 * math.sin(reaper.time_precise() * 2.2))
    local accent = Theme.COLORS.pink_opaque
    for i, alpha in ipairs({ 0x99, 0x55, 0x26 }) do
      local halo = math.floor(alpha * (0.45 + 0.55 * pulse))
      ImGui.DrawList_AddRect(dl,
        x - i, y - i, x + w + i, y + c.HEIGHT + i,
        (accent & 0xFFFFFF00) | halo, c.ROUNDING + i)
    end
  end

  local bg = Theme.COLORS.dark_gray_translucent
  if not opts.disabled then
    if held then
      bg = Theme.COLORS.dark_gray_opaque
    elseif hovered then
      bg = Theme.COLORS.dark_gray_semi_transparent
    end
  end
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + c.HEIGHT, bg, c.ROUNDING)

  -- The card doubles as its own progress bar
  if opts.progress then
    local fill = math.max(0, math.min(1, opts.progress))
    if fill > 0 then
      ImGui.DrawList_AddRectFilled(dl, x, y, x + w * fill, y + c.HEIGHT,
        (Theme.COLORS.pink_opaque & 0xFFFFFF00) | 0x55, c.ROUNDING)
    end
  end

  local press = held and c.PRESS_NUDGE or 0
  local cursor_x = x + c.PADDING

  if opts.icon then
    ImGui.SetCursorScreenPos(Ctx(), cursor_x, y + (c.HEIGHT - c.ICON_SIZE) / 2 + press)
    EmojiText.icon(opts.icon, c.ICON_SIZE)
    cursor_x = cursor_x + c.ICON_SIZE + 10
  end

  local line_h = ImGui.GetTextLineHeight(Ctx())
  local has_tagline = opts.tagline and opts.tagline ~= ''
  local text_h = has_tagline and (line_h * 2 + 2) or line_h
  local text_y = y + (c.HEIGHT - text_h) / 2 + press

  ImGui.SetCursorScreenPos(Ctx(), cursor_x, text_y)
  ImGui.TextColored(Ctx(), opts.disabled and 0x777777FF or 0xFFFFFFFF, opts.title)
  if has_tagline then
    ImGui.SetCursorScreenPos(Ctx(), cursor_x, text_y + line_h + 2)
    ImGui.TextColored(Ctx(), 0x999999FF, opts.tagline)
  end

  -- Restore the cursor past the card AND submit an item there:
  -- SetCursorScreenPos as the last act before an EndChild is an ImGui
  -- assertion ("submit an item e.g. Dummy() to grow boundaries")
  ImGui.SetCursorScreenPos(Ctx(), x, y + c.HEIGHT)
  ImGui.Dummy(Ctx(), 0, 0)

  return clicked and not opts.disabled
end

-- Land every accepted take in the project: which.tracks places the
-- matched child tracks, which.regions the heatmap regions. Always the
-- full set: the project targets have no per-file completion to skip -
-- a re-export replaces the previous landing wholesale.
function ExportPreviewUI:start_project_export(which)
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

  local opts = { tracks = which.tracks or false }
  if which.regions then
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

function ExportPreviewUI:render_export_tree(export_directories, opts)
  opts = opts or {}

  -- An empty "(Root)" wrapper around subdirectories is pure noise:
  -- render its children as the top level instead
  local top = export_directories
  if #top == 1 and top[1].path == "" and #top[1].files == 0 and #top[1].children > 0 then
    top = top[1].children
  end

  -- Always open at least enough directories to show SOME files: the
  -- first-directory spine down to the first row of real files opens
  -- by default, however deep the template nests (spreadsheet ->
  -- worksheet -> files was landing as one closed row). Siblings stay
  -- collapsed; the counts speak for them.
  if not opts.default_open and not opts.force_open then
    opts.spine = {}
    local level = top
    while #level > 0 do
      local first = level[1]
      opts.spine[first] = true
      if #first.files > 0 then break end
      level = first.children
    end
  end

  for _, directory in ipairs(top) do
    self:render_directory_node(directory, opts)
  end
end

function ExportPreviewUI:render_directory_node(directory, opts)
  -- Chain compression: wrapper directories holding nothing but a
  -- single child collapse into one a/b/c/ row
  local node = directory
  local tree_label
  if directory.path == "" then
    tree_label = "(Root)"
  else
    local label_parts = { directory.display_name }
    while #node.files == 0 and #node.children == 1 do
      node = node.children[1]
      table.insert(label_parts, node.display_name)
    end
    tree_label = table.concat(label_parts, '/') .. "/"
  end

  EmojiText.icon('folder')
  ImGui.SameLine(Ctx(), 0, 4)

  if opts.force_open then
    -- Filtering: every surviving directory shows its matches
    ImGui.SetNextItemOpen(Ctx(), true, ImGui.Cond_Always())
  elseif opts.default_open or (opts.spine and opts.spine[directory]) then
    -- Small trees open expanded for visual impact; big ones open just
    -- the spine and lean on the counts
    ImGui.SetNextItemOpen(Ctx(), true, ImGui.Cond_FirstUseEver())
  end

  local open = ImGui.TreeNode(Ctx(), tree_label)

  -- The count rides the row whether open or closed, so a collapsed
  -- directory still says what it holds
  ImGui.SameLine(Ctx(), 0, 8)
  local count = directory.subtree_file_count or 0
  ImGui.TextColored(Ctx(), 0x666666FF,
    ('(%d file%s)'):format(count, count == 1 and '' or 's'))

  if open then
    Trap(function()
      -- Render files in this directory (the end of a compressed
      -- chain owns the contents)
      for _, file in ipairs(node.files) do
        self:render_file_node(file)
      end

      -- Render child directories recursively
      for _, child_directory in ipairs(node.children) do
        self:render_directory_node(child_directory, opts)
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

-- Queue up a deferred export run; the runner ticks it forward a
-- frame-budget at a time from the action band.
function ExportPreviewUI:start_export(skip_completed)
  if self.export_runner:is_running() then return end

  self:log("Starting production batch export...")

  -- Export what the preview shows: the tree renders from the live
  -- (in-flight) template value, so exporting the committed one could
  -- produce different filenames than the ones on screen mid-edit
  local current_template = self._live_template or self.settings:get_template()
  self:log("Current template: " .. current_template)

  local export_items = self.data_service:generate_export_items(current_template, self.settings:get_timing())

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

  if #queue == 0 then
    self:log("Nothing to export")
    return
  end

  -- The run renders against this snapshot until it finishes
  self._running_tree = export_items

  self.export_runner:start(queue, {
    stop_on_error = not self.settings:get_options().skip_on_error,
  })
end

-- The runner has finished (or was cancelled): read the counts, surface
-- the summary, rebuild the tree fresh
function ExportPreviewUI:finish_export_run()
  local runner = self.export_runner

  self:show_export_summary(runner.succeeded, runner.total)

  self._running_tree = nil

  -- The export may have just created the output root
  self._folder_check_path = nil

  if self.settings:get_options().open_folder_when_done
    and runner.succeeded > 0 and not runner.cancelled then
    self:open_output_folder()
  end

  runner:reset()
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
