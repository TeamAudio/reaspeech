package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/EnvUtil')

TestEnvUtil = {
  WINDOWS_STRINGS = {'Win64', 'Win32'},
  OSX_STRINGS = {'OSX64', 'OSX32', 'macOS_64', 'macOS-arm64'},
  LINUX_STRINGS = {'Other'} -- this is definitely an assumption
}

reaper = {}

function TestEnvUtil:testIsWindows()
  for _, os_string in ipairs(self.WINDOWS_STRINGS) do
    reaper.GetOS = function() return os_string end
    lu.assertEquals(EnvUtil.is_windows(), true)
    lu.assertEquals(EnvUtil.is_mac(), false)
    lu.assertEquals(EnvUtil.is_linux(), false)
  end
end

function TestEnvUtil:testIsMac()
  for _, os_string in ipairs(self.OSX_STRINGS) do
    reaper.GetOS = function() return os_string end
    lu.assertEquals(EnvUtil.is_windows(), false)
    lu.assertEquals(EnvUtil.is_mac(), true)
    lu.assertEquals(EnvUtil.is_linux(), false)
  end
end

function TestEnvUtil:testIsLinux()
  for _, os_string in ipairs(self.LINUX_STRINGS) do
    reaper.GetOS = function() return os_string end
    lu.assertEquals(EnvUtil.is_windows(), false)
    lu.assertEquals(EnvUtil.is_mac(), false)
    lu.assertEquals(EnvUtil.is_linux(), true)
  end
end

os.exit(lu.LuaUnit.run())
