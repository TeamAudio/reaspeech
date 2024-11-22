--[[

  Trap.lua - Error handling wrapper for Lua exceptions

  Usage:

    Trap.on_error = function (e)
      reaper.ShowConsoleMsg(tostring(e) .. "\n")
    end

    Trap(function () error("This is an error") end)

]]--

Trap = {
  on_error = function (e)
    print(tostring(e))
  end,

  __call = function (self, f)
    return xpcall(f, self.on_error)
  end
}

setmetatable(Trap, Trap)
