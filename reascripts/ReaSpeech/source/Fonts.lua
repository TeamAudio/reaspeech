--[[

  Fonts.lua - Font configuration

]]--

Fonts = {
  DEFAULT_SIZE = 15,
  MIN_SIZE = 8,
  MAX_SIZE = 24,
}

function Fonts:init(ctx)
  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.General',
    persist = true,
  }

  local font_size = storage:number('font_size', self.DEFAULT_SIZE)
  self.size = Storage.Cell.new {
    get = function () return font_size:get() end,
    set = function (value)
      if value < self.MIN_SIZE then
        value = self.MIN_SIZE
      elseif value > self.MAX_SIZE then
        value = self.MAX_SIZE
      end
      font_size:set(value)
    end
  }

  self.last_font_size = self.size:get()

  self:load_and_attach(ctx, self.last_font_size)
end

function Fonts:check(ctx)
  local current_font_size = self.size:get()

  if current_font_size == self.last_font_size then
    return
  end

  self.last_font_size = current_font_size

  self:load_and_attach(ctx, current_font_size)
end

function Fonts:load_and_attach(ctx, font_size)
  if ImGui.ValidatePtr(self.main, 'ImGui_Font*') then
    ImGui.Detach(ctx, self.main)
  end

  self.main = ImGui.CreateFont('sans-serif', font_size)
  ImGui.Attach(ctx, self.main)

  if ImGui.ValidatePtr(self.bold, 'ImGui_Font*') then
    ImGui.Detach(ctx, self.bold)
  end

  self.bold = ImGui.CreateFont('sans-serif', font_size, ImGui.FontFlags_Bold())
  ImGui.Attach(ctx, self.bold)
end

function Fonts.wrap(ctx, font, f, trap_f)
  trap_f = trap_f or function(f_)
    return xpcall(f_, reaper.ShowConsoleMsg)
  end

  ImGui.PushFont(ctx, font)
  trap_f(function() f() end)
  ImGui.PopFont(ctx)
end
