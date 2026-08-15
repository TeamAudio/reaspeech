--[[

  Fonts.lua - Font configuration

]]--

Fonts = {
  DEFAULT_SIZE = 15,
  MIN_SIZE = 8,
  MAX_SIZE = 24,
}

function Fonts:create_font(name, size, flags)
  flags = flags or ImGui.FontFlags_None()
  return { object = ImGui.CreateFont(name, flags), size = size }
end

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

function Fonts:current_size()
  return self.size:get()
end

function Fonts:check(ctx)
  local current_font_size = self.size:get()

  local out_of_bounds = current_font_size < self.MIN_SIZE or current_font_size > self.MAX_SIZE

  if (current_font_size == self.last_font_size and not self._has_new_fonts) or out_of_bounds then
    return
  end
  self._has_new_fonts = false

  self.last_font_size = current_font_size

  self:load_and_attach(ctx, current_font_size)
end

function Fonts:load_and_attach(ctx, font_size)
  self:_detach(self.main)
  self.main = self:create_font('sans-serif', font_size)
  self:_attach(ctx, self.main)

  self:_detach(self.big)
  self.big = self:create_font('sans-serif', font_size + 4)
  self:_attach(ctx, self.big)

  self:_detach(self.bigboi)
  self.bigboi = self:create_font('sans-serif', font_size + 8)
  self:_attach(ctx, self.bigboi)

  self:_detach(self.bold)
  self.bold = self:create_font('sans-serif', font_size, ImGui.FontFlags_Bold())
  self:_attach(ctx, self.bold)

  for name, font in pairs(self.registered_fonts or {}) do
    local flags = font.flags or ImGui.FontFlags_None()
    self:_detach(self[name])
    self[name] = self:create_font(font.font_family, font_size + font.size, flags)
    self:_attach(ctx, self[name])
  end
end



function Fonts:_attach(ctx, font)
  ImGui.Attach(ctx, font.object)
  self._attached_ctx[font] = ctx
end

function Fonts:_detach(font)
  if not font or not font.object then
    return
  end

  if not ImGui.ValidatePtr(font.object, 'ImGui_Font*') then return end

  local attached_ctx = self._attached_ctx[font]
  self._attached_ctx[font] = nil
  if not ImGui.ValidatePtr(attached_ctx, 'ImGui_Context*') then return end

  ImGui.Detach(attached_ctx, font.object)
end

function Fonts.wrap(ctx, font, f, trap_f)
  trap_f = trap_f or function(f_)
    return xpcall(f_, reaper.ShowConsoleMsg)
  end

  ImGui.PushFont(ctx, font.object, font.size)
  trap_f(function() f() end)
  ImGui.PopFont(ctx)
end

function Fonts:register(name, font_family, relative_size, flags)
  self.registered_fonts = self.registered_fonts or {}

  if not name or not font_family or not relative_size then
    error("Fonts:register: name, font_family, and size are required")
  end

  self.registered_fonts[name] = {
    font_family = font_family,
    size = relative_size,
    flags = flags,
  }
  self._has_new_fonts = true
end