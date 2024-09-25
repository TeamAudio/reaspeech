--[[

  AlertPopup.lua - Alert popup UI

]]--

AlertPopup = Polo {
  WIDTH = 400,
  HEIGHT = 200,
  MIN_CONTENT_WIDTH = 375,
  BUTTON_WIDTH = 120,
  DEFAULT_TITLE = 'Alert',
}

function AlertPopup:init()
  Logging.init(self, 'AlertPopup')

  self.title = self.title or self.DEFAULT_TITLE
  self.msg = ''
end

function AlertPopup:show(title, msg)
  self.title = title or self.title
  self.msg = msg
  self:open()
end

function AlertPopup:render()
  local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
  ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, self.WIDTH, self.HEIGHT, ImGui.Cond_FirstUseEver())

  if ImGui.BeginPopupModal(ctx, self.title, true, ImGui.WindowFlags_AlwaysAutoResize()) then
    app:trap(function () self:render_content() end)
    ImGui.EndPopup(ctx)
  else
    self:close()
  end
end

function AlertPopup:render_content()
  ImGui.Text(ctx, self.msg)
  self:render_separator()
  if ImGui.Button(ctx, 'OK', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function AlertPopup:render_separator()
  ImGui.Dummy(ctx, self.MIN_CONTENT_WIDTH, 0)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 0)
end

function AlertPopup:open()
  ImGui.OpenPopup(ctx, self.title)
end

function AlertPopup:close()
  ImGui.CloseCurrentPopup(ctx)
  if self.onclose then self.onclose() end
end
