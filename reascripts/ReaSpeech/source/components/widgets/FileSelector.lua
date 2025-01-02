--[[

  FileSelector - File selector ReaSpeechWidget

]]--

Widgets.FileSelector = (function()

local FileSelector = {
  JSREASCRIPT_URL = 'https://forum.cockos.com/showthread.php?t=212174',
  has_js_ReaScriptAPI = function()
    return reaper.JS_Dialog_BrowseForSaveFile
  end
}

FileSelector.new = function(options)
  options = options or {}
  options.default = options.default or ''
  local title = options.title or 'Save file'
  local folder = options.folder or ''
  local file = options.file or ''
  local ext = options.ext or ''
  local save = options.save or false
  local multi = options.multi or false

  local dialog_function
  if save then
    dialog_function = function()
      return reaper.JS_Dialog_BrowseForSaveFile(title, folder, file, ext)
    end
  else
    dialog_function = function()
      return reaper.JS_Dialog_BrowseForOpenFiles(title, folder, file, ext, multi)
    end
  end

  local o = ReaSpeechWidget.new({
    default = options.default,
    renderer = FileSelector.renderer,
    options = options,
  })

  options.button = Widgets.Button.new({
    label = options.button_label or 'Choose File',
    disabled = not FileSelector.has_js_ReaScriptAPI(),
    width = options.button_width,
    on_click = function()
      local rv, selected_file = dialog_function()
      if rv == 1 then
        o:set(selected_file)
      end
    end
  })

  return o
end

-- Display a text input for the output filename, with a Browse button if
-- the js_ReaScriptAPI extension is available.
FileSelector.renderer = function(self)
  local options = self.options

  ImGui.Text(ctx, options.label)

  FileSelector.render_jsapi_notice(self)

  options.button:render()
  ImGui.SameLine(ctx)

  local w, _
  if not options.input_width then
    w, _ = ImGui.GetContentRegionAvail(ctx)
  else
    w = options.input_width
  end

  ImGui.SetNextItemWidth(ctx, w)
  local hint = '...or type one here.'
  local file_changed, file = ImGui.InputTextWithHint(ctx, '##file', hint, self:value())
  if file_changed then
    self:set(file)
  end
end

FileSelector.render_jsapi_notice = function(self)
  if FileSelector.has_js_ReaScriptAPI() then
    return
  end

  local _, spacing_v = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing())
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, spacing_v)
  ImGui.Text(ctx, "To enable file selector, ")
  ImGui.SameLine(ctx)
  Widgets.link('install js_ReaScriptAPI', ReaUtil.url_opener(FileSelector.JSREASCRIPT_URL))
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, ".")
  ImGui.PopStyleVar(ctx)
end

return FileSelector

end)()
