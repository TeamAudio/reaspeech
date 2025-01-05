--[[

  Fonts.lua - Font configuration

]]--

Fonts = {
  DEFAULT_SIZE = 15,
  MIN_SIZE = 8,
  MAX_SIZE = 24,
}

function Fonts:init(ctx)
  self._attached_ctx = {}

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
  self:_detach(self.main)
  self.main = ImGui.CreateFont('sans-serif', font_size)
  self:_attach(ctx, self.main)

  self:_detach(self.big)
  self.big = ImGui.CreateFont('sans-serif', font_size + 4)
  self:_attach(ctx, self.big)

  self:_detach(self.bold)
  self.bold = ImGui.CreateFont('sans-serif', font_size, ImGui.FontFlags_Bold())
  self:_attach(ctx, self.bold)
end

function Fonts:_attach(ctx, font)
  ImGui.Attach(ctx, font)
  self._attached_ctx[font] = ctx
end

function Fonts:_detach(font)
  if not ImGui.ValidatePtr(font, 'ImGui_Font*') then return end

  local attached_ctx = self._attached_ctx[font]
  self._attached_ctx[font] = nil
  if not ImGui.ValidatePtr(attached_ctx, 'ImGui_Context*') then return end

  ImGui.Detach(attached_ctx, font)
end

function Fonts.wrap(ctx, font, f, trap_f)
  trap_f = trap_f or function(f_)
    return xpcall(f_, reaper.ShowConsoleMsg)
  end

  ImGui.PushFont(ctx, font)
  trap_f(function() f() end)
  ImGui.PopFont(ctx)
end
