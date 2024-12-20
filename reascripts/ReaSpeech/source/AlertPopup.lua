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

  ToolWindow.modal(self, {
    title = self.title or self.DEFAULT_TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    window_flags = ImGui.WindowFlags_AlwaysAutoResize(),
  })

  self.msg = ''
end

function AlertPopup:show(title, msg)
  self._tool_window.title = title or self._tool_window.title
  self.msg = msg
  self:present()
end

function AlertPopup:render_content()
  if type(self.msg) == 'function' then
    self.msg()
    return
  end
  ImGui.Text(ctx, self.msg)

  self:render_separator()
  if ImGui.Button(ctx, 'OK', self.BUTTON_WIDTH, 0) then
    self:close()
  end
end

function AlertPopup:close()
  if self.onclose then self.onclose() end
end
