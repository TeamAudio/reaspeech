--[[

ExportConfigurationUI.lua - Left panel container for template editor and settings

]]--

ExportConfigurationUI = Polo {}

function ExportConfigurationUI:init()
  Logging().init(self, 'ExportConfigurationUI')

  assert(self.settings, 'ExportConfigurationUI: settings is required')
  assert(self.needle_metadata_service, 'ExportConfigurationUI: needle_metadata_service is required')

  -- Create enhanced template editor component with metadata service
  self.template_editor = ExportTemplateEditorUI.new {
    settings = self.settings,
    needle_metadata_service = self.needle_metadata_service
  }

  -- Create settings UI component
  self.settings_ui = ExportSettingsUI.new {
    settings = self.settings
  }

  self:log("Initialized ExportConfigurationUI")
end

function ExportConfigurationUI:render(width)
  ImGui.PushItemWidth(Ctx(), width - 20) -- Leave some margin

  Trap(function()
    -- Template editor section (the editor labels its own input, so
    -- the header is the section name only)
    Fonts.wrap(Ctx(), Fonts.big, function()
      ImGui.Text(Ctx(), "Filename Template")
    end, Trap)
    ImGui.Separator(Ctx())
    ImGui.Dummy(Ctx(), 0, 4)

    self.template_editor:render(width - 20)

    ImGui.Spacing(Ctx())
    ImGui.Spacing(Ctx())

    -- Audio format and timing settings (always visible)
    self.settings_ui:render(width - 20)
  end)

  ImGui.PopItemWidth(Ctx())
end
