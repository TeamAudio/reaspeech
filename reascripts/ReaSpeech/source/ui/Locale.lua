--[[

  Locale.lua - accessor for loaded locale

]]--

Locale = setmetatable({}, {
  __call = function(self)
    if self._locale then
      return self._locale
    end

    self:init()

    return self._locale
  end
})


function Locale:init()

  local storage = Storage.ExtState.make {
    section = 'ReaSpeech.General',
    persist = true,
  }

  self.locale = storage:string('locale', 'en')

  self._last_locale = self.locale:get()

  self._locale = Strings.localize(self._last_locale)
end

function Locale:check()
  local current_locale = self.locale:get()

  if current_locale == self._last_locale then
    return
  end

  self._last_locale = current_locale

  self._locale = Strings.localize(current_locale)
end