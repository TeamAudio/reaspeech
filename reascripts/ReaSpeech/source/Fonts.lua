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

  self.main = ImGui.CreateFont('sans-serif', self.size:get())
  ImGui.Attach(ctx, self.main)

  self.bold = ImGui.CreateFont('sans-serif', self.size:get(), ImGui.FontFlags_Bold())
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
