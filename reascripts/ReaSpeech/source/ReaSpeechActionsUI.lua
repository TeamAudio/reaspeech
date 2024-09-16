--[[

ReaSpeechActionsUI.lua - Main action bar UI in ReaSpeech

]]--

ReaSpeechActionsUI = Polo {}

function ReaSpeechActionsUI:init()
  self.disabler = ReaUtil.disabler(ctx)
end

function ReaSpeechActionsUI:render()
  local disable_if = self.disabler
  local progress
  app:trap(function ()
    progress = self.worker:progress()
  end)

  disable_if(progress, function()
    local plugin_actions = self.plugins:actions()
    for _, action in ipairs(plugin_actions) do
      action:render()
      ImGui.SameLine(ctx)
    end
  end)

  if progress then
    if ImGui.Button(ctx, "Cancel") then
      self.worker:cancel()
    end

    ImGui.SameLine(ctx)
    local overlay = string.format("%.0f%%", progress * 100)
    local status = self.worker:status()
    if status then
      overlay = overlay .. ' - ' .. status
    end
    ImGui.ProgressBar(ctx, progress, nil, nil, overlay)
  end
end
