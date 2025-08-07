--[[

ReaSpeechWelcomeUI.lua - Welcome screen for ReaSpeech

]]--

ReaSpeechWelcomeUI = Polo {
  TITLE = "Welcome!",

  WIDTH = 610,
  HEIGHT = 800,

  HEADING_MARGIN = 8,
  LINK_COLOR = 0x4493f8ff,
  PADDING = 12,
  PARA_MARGIN = 2,

  FOOTER_BG_COLOR = 0x222222ff,
  FOOTER_HEIGHT = 40,
  FOOTER_MARGIN = 5,

  HOME_URL = "https://techaud.io/reaspeech/",
  GITHUB_URL = "https://github.com/TeamAudio/reaspeech",
  DOCKER_HUB_URL = "https://hub.docker.com/r/techaudiodoc/reaspeech",
  DOCKER_DOC_URL = "https://github.com/TeamAudio/reaspeech/blob/main/docs/docker.md",
}

function ReaSpeechWelcomeUI:init()
  self.is_demo = self.is_demo or false

  ToolWindow.modal(self, {
    title = self.TITLE,
    width = self.WIDTH,
    height = self.HEIGHT,
    window_flags = ImGui.WindowFlags_AlwaysAutoResize(),
    theme = ImGuiTheme.new({
      styles = {
        {ImGui.StyleVar_Alpha, 1.0 },
        {ImGui.StyleVar_WindowPadding, 0, 0 },
      }
    }),
  })
end

function ReaSpeechWelcomeUI:render_content()
  self:render_banner()
  self:render_welcome_text()
  if self.is_demo then
    self:render_demo_text()
  end
  self:render_close_button()
  self:render_footer()
end

function ReaSpeechWelcomeUI:render_banner()
  Widgets.png('reaspeech-banner')
end

function ReaSpeechWelcomeUI:render_welcome_text()
  self:render_heading("Welcome to ReaSpeech!")
  self:render_text([[This is a tool for transcribing audio in REAPER.]])
end

function ReaSpeechWelcomeUI:render_demo_text()
  self:render_heading("Demo Version")
  self:render_text("Please note that this version is a demo and may not be available at all times.")
  self:render_text("For a more reliable experience, you can run ReaSpeech locally using the ")
  ImGui.SameLine(Ctx(), 0, 0)
  Widgets.link("Docker image", ReaUtil.url_opener(self.DOCKER_DOC_URL), self.LINK_COLOR, self.LINK_COLOR)
  ImGui.SameLine(Ctx(), 0, 0)
  ImGui.Text(Ctx(), ".")
end

function ReaSpeechWelcomeUI:render_close_button()
  ImGui.Dummy(Ctx(), self.WIDTH, self.PADDING - 2)
  ImGui.SetCursorPosX(Ctx(), self.PADDING - 2)
  if ImGui.Button(Ctx(), "Let's Go!") then
    self:close()
  end
end

function ReaSpeechWelcomeUI:render_heading(text)
  Fonts.wrap(Ctx(), Fonts.bold, function()
    ImGui.Dummy(Ctx(), self.WIDTH, self.HEADING_MARGIN)
    ImGui.SetCursorPosX(Ctx(), self.PADDING)
    ImGui.Text(Ctx(), text)
  end, Trap)
end

function ReaSpeechWelcomeUI:render_text(text)
  ImGui.Dummy(Ctx(), self.WIDTH, self.PARA_MARGIN)
  ImGui.SetCursorPosX(Ctx(), self.PADDING)
  ImGui.Text(Ctx(), text)
end

function ReaSpeechWelcomeUI:render_footer()
  ImGui.Dummy(Ctx(), self.WIDTH, self.FOOTER_MARGIN)

  local draw_list = ImGui.GetWindowDrawList(Ctx())
  local screen_x, screen_y = ImGui.GetCursorScreenPos(Ctx())
  local cursor_x, cursor_y = ImGui.GetCursorPos(Ctx())

  ImGui.DrawList_AddRectFilled(
    draw_list,
    screen_x,
    screen_y,
    screen_x + self.WIDTH,
    screen_y + self.FOOTER_HEIGHT,
    self.FOOTER_BG_COLOR
  )

  ImGui.Dummy(Ctx(), self.WIDTH, self.FOOTER_HEIGHT)
  ImGui.SetCursorPos(Ctx(), cursor_x + self.PADDING, cursor_y + self.PADDING)

  Widgets.link("ReaSpeech Website", ReaUtil.url_opener(self.HOME_URL))
  ImGui.SameLine(Ctx())
  Widgets.link("GitHub", ReaUtil.url_opener(self.GITHUB_URL))
  ImGui.SameLine(Ctx())
  Widgets.link("Docker Hub", ReaUtil.url_opener(self.DOCKER_HUB_URL))
end
