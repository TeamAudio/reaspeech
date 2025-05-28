--[[

  KeyMap.lua - Keyboard bindings registrations & reactions

  Initialize a new map of key bindings with a table of `key_code` => `binding`,
  where `binding` can be a function or a list table of functions.

  Invoke the `react` method as often as you like to check and handle any
  bindings that match.
]]--

KeyMap = Polo {
  new = function(bindings)
    return {
      bindings = bindings
    }
  end
}

function KeyMap:init()
  self.bindings = self.bindings or {}
end

function KeyMap:react()
  for key, binding in pairs(self.bindings) do
    if ImGui.IsKeyPressed(Ctx(), key) then
      if type(binding) == 'function' then
        binding()
      elseif type(binding) == 'table' then
        for _, f in ipairs(binding) do
          f()
        end
      end
    end
  end
end
