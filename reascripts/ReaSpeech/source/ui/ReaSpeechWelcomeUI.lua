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
  ImGui.SameLine(ctx, 0, 0)
  Widgets.link("Docker image", ReaUtil.url_opener(self.DOCKER_DOC_URL), self.LINK_COLOR, self.LINK_COLOR)
  ImGui.SameLine(ctx, 0, 0)
  ImGui.Text(ctx, ".")
end

function ReaSpeechWelcomeUI:render_close_button()
  ImGui.Dummy(ctx, self.WIDTH, self.PADDING - 2)
  ImGui.SetCursorPosX(ctx, self.PADDING - 2)
  if ImGui.Button(ctx, "Let's Go!") then
    self:close()
  end
end

function ReaSpeechWelcomeUI:render_heading(text)
  ImGui.PushFont(ctx, Fonts.bold)
  Trap(function ()
    ImGui.Dummy(ctx, self.WIDTH, self.HEADING_MARGIN)
    ImGui.SetCursorPosX(ctx, self.PADDING)
    ImGui.Text(ctx, text)
  end)
  ImGui.PopFont(ctx)
end

function ReaSpeechWelcomeUI:render_text(text)
  ImGui.Dummy(ctx, self.WIDTH, self.PARA_MARGIN)
  ImGui.SetCursorPosX(ctx, self.PADDING)
  ImGui.Text(ctx, text)
end

function ReaSpeechWelcomeUI:render_footer()
  ImGui.Dummy(ctx, self.WIDTH, self.FOOTER_MARGIN)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorPos(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    screen_x,
    screen_y,
    screen_x + self.WIDTH,
    screen_y + self.FOOTER_HEIGHT,
    self.FOOTER_BG_COLOR
  )

  ImGui.Dummy(ctx, self.WIDTH, self.FOOTER_HEIGHT)
  ImGui.SetCursorPos(ctx, cursor_x + self.PADDING, cursor_y + self.PADDING)

  Widgets.link("ReaSpeech Website", ReaUtil.url_opener(self.HOME_URL))
  ImGui.SameLine(ctx)
  Widgets.link("GitHub", ReaUtil.url_opener(self.GITHUB_URL))
  ImGui.SameLine(ctx)
  Widgets.link("Docker Hub", ReaUtil.url_opener(self.DOCKER_HUB_URL))
end