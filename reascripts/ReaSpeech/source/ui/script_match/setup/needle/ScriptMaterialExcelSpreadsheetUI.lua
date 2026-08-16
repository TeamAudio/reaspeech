ScriptMaterialExcelSpreadsheetUI = Polo {
  API_ENDPOINT = '/script_match/parse_spreadsheet'
}

function ScriptMaterialExcelSpreadsheetUI:init()
  Logging().init(self, 'ScriptMaterialExcelSpreadsheetUI')

  assert(self.session_id, 'ScriptMaterialExcelSpreadsheetUI: session_id is required')
  assert(self.workflow, 'ScriptMaterialExcelSpreadsheetUI: workflow is required')
  assert(self.material, 'ScriptMaterialExcelSpreadsheetUI: material is required')
  assert(self.material.type == ScriptMaterialExcelSpreadsheet.key, 'ScriptMaterialExcelSpreadsheetUI: material must be of type excel_spreadsheet')
  assert(self.materials, 'ScriptMaterialExcelSpreadsheetUI: materials is required')

  self.script_materials = self.materials:get_material_storage(self.material.guid)

  self.material_config = self.script_materials:get()

  self.worksheet_uis = self:init_worksheet_uis()

  self.workflow:listen_for_event('script_material_updated', function(event)
    if event.material and event.material.guid == self.material.guid then
      self:mark_dirty()
    end
  end)

  self:log("Initialized ScriptMaterialExcelSpreadsheetUI")
end

function ScriptMaterialExcelSpreadsheetUI:render()
  self:save_if_dirty()

  -- An in-flight parse shows its status even when parsed data exists
  -- (re-parse refreshes over a configured material)
  if self.parse_request then
    if self.parse_interval then
      self.parse_interval:react(reaper.time_precise())
    end

    self:render_parse_status()
    return
  end

  if self.parse_error then
    self:render_parse_error()
    return
  end

  if self.material_config.is_parsed then
    self:render_configuration()
    return
  end

  self:parse_spreadsheet()
end

function ScriptMaterialExcelSpreadsheetUI:render_configuration()
  Fonts.wrap(Ctx(), Fonts.big, function()
    ImGui.Text(Ctx(), 'Worksheets')
  end, Trap)

  -- Re-parse, right-anchored on the header row: fresh data from disk,
  -- worksheet settings kept
  ImGui.SameLine(Ctx())
  local reparse_label = 'Re-parse'
  local button_w = (ImGui.CalcTextSize(Ctx(), reparse_label)) + 20
  ImGui.SetCursorPosX(Ctx(),
    ImGui.GetCursorPosX(Ctx()) + ImGui.GetContentRegionAvail(Ctx()) - button_w)
  if ImGui.Button(Ctx(), reparse_label) then
    self:parse_spreadsheet()
  end
  Widgets.tooltip('Reload the spreadsheet from disk. Worksheet settings are kept; needles regenerate from the fresh data.')

  ImGui.Separator(Ctx())
  ImGui.Dummy(Ctx(), 0, 4)

  self:render_worksheet_chips()
  ImGui.Dummy(Ctx(), 0, 6)
  self:render_config_actions()
  ImGui.Dummy(Ctx(), 0, 6)

  -- One worksheet visible at a time; the chips select which
  local active_ui = self.worksheet_uis[self:active_worksheet_index()]
  if active_ui then
    active_ui:render()
  end
end

-- Config-level actions on the active sheet: propagate to siblings,
-- share via clipboard. (Data-level Re-parse lives in the header.)
function ScriptMaterialExcelSpreadsheetUI:render_config_actions()
  local worksheets = self.material_config.worksheets or {}

  if #worksheets > 1 then
    if ImGui.Button(Ctx(), 'Apply to All Sheets') then
      self:apply_config_to_all_worksheets()
    end
    Widgets.tooltip("Copy this sheet's settings (header row, line finder, tags) onto every other sheet. Enabled/disabled stays per sheet; sheets with too few columns are skipped.")
    ImGui.SameLine(Ctx())
  end

  if ImGui.Button(Ctx(), 'Copy Config') then
    local sheet = self.worksheet_uis[self:active_worksheet_index()].sheet
    ImGui.SetClipboardText(Ctx(), ScriptMaterialExcelSpreadsheet.export_config_blob(sheet))
    self._assist_status = 'Config copied - paste onto another sheet, session, or designer'
  end
  Widgets.tooltip("Copy this sheet's settings to the clipboard as a shareable blob.")
  ImGui.SameLine(Ctx())

  if ImGui.Button(Ctx(), 'Paste Config') then
    local sheet = self.worksheet_uis[self:active_worksheet_index()].sheet
    local ok, message = ScriptMaterialExcelSpreadsheet.import_config_blob(
      ImGui.GetClipboardText(Ctx()), sheet)

    if ok then
      self.worksheet_uis = self:init_worksheet_uis()
      self.workflow:emit_event('script_material_updated', { material = self.material })
    end
    self._assist_status = message
  end
  Widgets.tooltip("Apply a copied config blob to this sheet. Checks the blob's version and column references first.")

  if self._assist_status then
    ImGui.SameLine(Ctx())
    ImGui.PushStyleColor(Ctx(), reaper.ImGui_Col_Text(), 0x888888FF)
    Trap(function()
      ImGui.Text(Ctx(), self._assist_status)
    end)
    ImGui.PopStyleColor(Ctx())
  end
end

function ScriptMaterialExcelSpreadsheetUI:apply_config_to_all_worksheets()
  local source_sheet = self.worksheet_uis[self:active_worksheet_index()].sheet
  local applied, skipped = ScriptMaterialExcelSpreadsheet.propagate_worksheet_config(
    source_sheet, self.material_config.worksheets)

  -- The sibling UIs bind their config tables at construction; rebuild
  -- so they pick up the propagated copies
  self.worksheet_uis = self:init_worksheet_uis()
  self.workflow:emit_event('script_material_updated', { material = self.material })

  local message = ('Applied to %d sheet%s'):format(#applied, #applied == 1 and '' or 's')
  if #skipped > 0 then
    message = ('%s; skipped (too few columns): %s'):format(message, table.concat(skipped, ', '))
  end
  self._assist_status = message
end

function ScriptMaterialExcelSpreadsheetUI:active_worksheet_index()
  local index = self._active_worksheet_index

  if not index or not self.worksheet_uis[index] then
    -- Land on the first enabled sheet until the user picks one
    index = 1
    for i, worksheet_ui in ipairs(self.worksheet_uis) do
      if worksheet_ui.config.enabled then
        index = i
        break
      end
    end
    self._active_worksheet_index = index
  end

  return index
end

ScriptMaterialExcelSpreadsheetUI.CHIP = {
  PADDING_X = 10,
  PADDING_Y = 6,
  GAP = 6,
  ICON_GAP = 4,
  ROUNDING = 5,
}

-- One chip per worksheet: the phase-card language at tab scale -
-- pressable, active carries the accent border, disabled sheets dim,
-- enabled sheets wear a check. Chips wrap to further rows when the
-- workbook has more sheets than fit across the window.
function ScriptMaterialExcelSpreadsheetUI:render_worksheet_chips()
  local c = ScriptMaterialExcelSpreadsheetUI.CHIP
  local line_h = ImGui.GetTextLineHeight(Ctx())
  local chip_h = line_h + c.PADDING_Y * 2

  local start_x = ImGui.GetCursorScreenPos(Ctx())
  local row_right = start_x + ImGui.GetContentRegionAvail(Ctx())
  local pen_x = nil

  for i, worksheet_ui in ipairs(self.worksheet_uis) do
    local name = worksheet_ui.config.name or ('Sheet ' .. i)
    local enabled = worksheet_ui.config.enabled and true or false
    local icon = enabled and 'check' or nil

    local chip_w = c.PADDING_X * 2 + ImGui.CalcTextSize(Ctx(), name)
    if icon then
      chip_w = chip_w + line_h + c.ICON_GAP
    end

    if pen_x and pen_x + c.GAP + chip_w <= row_right then
      ImGui.SameLine(Ctx(), 0, c.GAP)
    end

    local x = ImGui.GetCursorScreenPos(Ctx())
    self:render_worksheet_chip(i, chip_w, chip_h, name, icon, enabled)
    pen_x = x + chip_w
  end
end

function ScriptMaterialExcelSpreadsheetUI:render_worksheet_chip(index, chip_w, chip_h, name, icon, enabled)
  local c = ScriptMaterialExcelSpreadsheetUI.CHIP

  ImGui.BeginGroup(Ctx())
  Trap(function()
    local x, y = ImGui.GetCursorScreenPos(Ctx())

    local clicked = ImGui.InvisibleButton(Ctx(), '##worksheet-chip-' .. index, chip_w, chip_h)
    local hovered = ImGui.IsItemHovered(Ctx())
    local held = ImGui.IsItemActive(Ctx())

    if hovered then
      ImGui.SetMouseCursor(Ctx(), ImGui.MouseCursor_Hand())
    end

    local active = index == self:active_worksheet_index()
    local bg = Theme.COLORS.dark_gray_translucent
    if held then
      bg = Theme.COLORS.dark_gray_opaque
    elseif active then
      bg = Theme.COLORS.medium_gray_opaque
    elseif hovered then
      bg = Theme.COLORS.dark_gray_semi_transparent
    end

    local dl = ImGui.GetWindowDrawList(Ctx())
    ImGui.DrawList_AddRectFilled(dl, x, y, x + chip_w, y + chip_h, bg, c.ROUNDING)
    if active then
      ImGui.DrawList_AddRect(dl, x, y, x + chip_w, y + chip_h, Theme.COLORS.pink_opaque, c.ROUNDING)
    end

    local press = held and 1 or 0
    ImGui.SetCursorScreenPos(Ctx(), x + c.PADDING_X, y + c.PADDING_Y + press)

    if icon then
      EmojiText.icon(icon)
      ImGui.SameLine(Ctx(), 0, c.ICON_GAP)
    end

    if enabled then
      ImGui.Text(Ctx(), name)
    else
      ImGui.TextDisabled(Ctx(), name)
    end

    if clicked then
      self._active_worksheet_index = index
    end
  end)
  ImGui.EndGroup(Ctx())
end

function ScriptMaterialExcelSpreadsheetUI:render_parse_status()
  ImGui.Text(Ctx(), "Parsing in progress...")
  -- Add logic to show parsing status
end

function ScriptMaterialExcelSpreadsheetUI:render_parse_error()
  ImGui.TextWrapped(Ctx(), 'Could not read the spreadsheet: ' .. self.parse_error)
  if ImGui.Button(Ctx(), 'Retry') then
    self.parse_error = nil
  end
end

function ScriptMaterialExcelSpreadsheetUI:parse_spreadsheet()
  self.parse_error = nil

  if reaper.DataSource_Parse then
    self:parse_with_datasource()
  else
    self:parse_with_backend()
  end
end

-- The reaper-datasource extension parses natively and synchronously:
-- no backend, no upload, no polling. Its JSON matches the backend's
-- parse_spreadsheet response shape, so both paths share
-- parse_backend_response.
function ScriptMaterialExcelSpreadsheetUI:parse_with_datasource()
  self:log("Parsing spreadsheet with reaper-datasource: " .. dump(self.material))

  local ok, result = reaper.DataSource_Parse(self.material.filepath, '')
  if not ok then
    self:fail_parse(result)
    return
  end

  local decoded, response = pcall(json.decode, result)
  if not decoded then
    self:fail_parse('Could not decode parser output: ' .. tostring(response))
    return
  end

  local success, error_msg = self:parse_backend_response(response)
  if success then
    self:handle_parse_success()
  else
    self:fail_parse(error_msg or 'Unknown error')
  end
end

function ScriptMaterialExcelSpreadsheetUI:parse_with_backend()
  self:log("Starting parse for spreadsheet: " .. dump(self.material))
  self.parse_request = ReaSpeechAPI:post_request(
    self.API_ENDPOINT,
    {},
    { spreadsheet = self.material.filepath }
  )

  self.parse_interval = IntervalFunction().new(0.3, function()
    if not self.parse_request or not self.parse_request:ready() then
      self:log('Waiting for parse request to be ready...')
      return
    end

    if self.parse_request:error() then
      self:fail_parse(self.parse_request:error())
      self.parse_request = nil
      self.parse_interval = nil
      return
    end

    local response = self.parse_request:result()
    local success, error_msg = self:parse_backend_response(response)

    self.parse_interval = nil
    self.parse_request = nil

    if success then
      self:handle_parse_success()
    else
      self:fail_parse(error_msg or 'Unknown error')
    end
  end)
end

function ScriptMaterialExcelSpreadsheetUI:handle_parse_success()
  self:log('Parse completed successfully')
  -- The worksheet UIs were built before the parse populated the
  -- config; rebuild them so the controls appear immediately.
  self.worksheet_uis = self:init_worksheet_uis()
  self.workflow:emit_event('script_material_updated', { material = self.material })
end

function ScriptMaterialExcelSpreadsheetUI:fail_parse(message)
  self:log('Parse error: ' .. message)
  self.parse_error = message
end

function ScriptMaterialExcelSpreadsheetUI:parse_backend_response(response)
  if not response then
    return false, 'Empty response from server'
  end

  if not response.sheets then
    return false, 'No worksheets found in Excel file'
  end

  local material = self.material_config

  -- Store worksheet data; a re-parse carries the user's per-sheet
  -- configuration over by name (fresh data, kept settings)
  material.worksheets = ScriptMaterialExcelSpreadsheet.merge_worksheet_configs(
    material.worksheets, response.sheets or {})
  material.config = response.config or {}

  -- Store metadata
  material.metadata = material.metadata or {}
  material.metadata.sheet_count = #material.worksheets
  material.metadata.total_rows = 0

  for _, sheet in ipairs(material.worksheets) do
    if sheet.config and sheet.config.row_count then
      material.metadata.total_rows = material.metadata.total_rows + sheet.config.row_count
    elseif sheet.data then
      material.metadata.total_rows = material.metadata.total_rows + #sheet.data
    end
  end

  material.is_parsed = true

  self.script_materials:set(material)
  self:log('Parsed Excel file: ' .. material.metadata.sheet_count .. ' sheets, ' .. material.metadata.total_rows .. ' total rows')

  return true
end

-- Build worksheet UIs over self.material_config's own sheet tables, so
-- widget edits mutate the same copy that save_if_dirty persists
function ScriptMaterialExcelSpreadsheetUI:init_worksheet_uis()
  local worksheet_uis = {}

  self:log(string.format("Initializing %d worksheet UIs", #(self.material_config.worksheets or {})))
  for _, sheet in ipairs(self.material_config.worksheets or {}) do
    local worksheet_ui = ScriptMaterialWorksheetUI.new {
      session_id = self.session_id,
      workflow = self.workflow,
      material = self.material,
      sheet = sheet,
    }
    table.insert(worksheet_uis, worksheet_ui)
  end

  return worksheet_uis
end

function ScriptMaterialExcelSpreadsheetUI:mark_dirty()
  self._dirty_flag = true
  self:log("Marked ScriptMaterialExcelSpreadsheetUI as dirty for material: " .. (self.material.name or "<no name>"))
end

function ScriptMaterialExcelSpreadsheetUI:save_if_dirty()
  if not self._dirty_flag then
    return
  end

  self:log("Saving ScriptMaterialExcelSpreadsheetUI for material: " .. (self.material.name or "<no name>"))
  self.script_materials:set(self.material_config)
  self._dirty_flag = false
end