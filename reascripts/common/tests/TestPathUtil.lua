package.path = '../common/libs/?.lua;../common/vendor/?.lua;' .. package.path

local lu = require('luaunit')

require('EnvUtil')
require('PathUtil')

TestPathUtil = {
  PROJECT_PATH = "Z:\\reaper-project-path",
}

reaper = {
  GetOS = function() return 'Win64' end,
  GetProjectPath = function() return TestPathUtil.PROJECT_PATH end,
}

function TestPathUtil:testHasExtension()
  lu.assertTrue(PathUtil.has_extension("some-file.json"))
  lu.assertTrue(PathUtil.has_extension("path\\to\\some-file.json"))
  lu.assertTrue(PathUtil.has_extension("path/to/some-file.json"))
  lu.assertTrue(PathUtil.has_extension("C:\\path\\to\\some-file.json"))
  lu.assertTrue(PathUtil.has_extension("/path/to/some-file.json"))

  lu.assertFalse(PathUtil.has_extension("some-file"))
  lu.assertFalse(PathUtil.has_extension("path\\to\\some-file"))
  lu.assertFalse(PathUtil.has_extension("path/to/some-file"))
  lu.assertFalse(PathUtil.has_extension("C:\\path\\to\\some-file"))
  lu.assertFalse(PathUtil.has_extension("/path/to/some-file"))

  lu.assertTrue(PathUtil.has_extension(".json"))
  lu.assertFalse(PathUtil.has_extension(""))

end

function TestPathUtil:testApplyExtension()
  local extension = "json"

  local _assert_applied = function(p)
    lu.assertEquals(PathUtil.apply_extension(p, extension), p .. '.' .. extension)
  end

  local _assert_unapplied = function(p)
    lu.assertEquals(PathUtil.apply_extension(p, extension), p)
  end

  -- blank in, blank out
  lu.assertEquals(PathUtil.apply_extension("", extension), "")

  for _, p in ipairs({
    '\\',
    '\\\\',
    'some-file',
    'path\\to\\some-file',
    'C:\\path\\to\\some-file'
  }) do
    _assert_applied(p)
  end

  for _, p in ipairs({
    'some-file.json',
    'path\\to\\some-file.json',
    'C:\\path\\to\\some-file.json',
    'path\\to\\.json',
    '.json'
  }) do
    _assert_unapplied(p)
  end

  for _, os_string in ipairs({"OSX64", "Other"}) do
    reaper.GetOS = function() return os_string end

    for _, p in ipairs({
      '/',
      '//',
      'some-file',
      'path/to/some-file',
      '/path/to/some-file'
    }) do
      _assert_applied(p)
    end

    for _, p in ipairs({
      'some-file.json',
      'path/to/some-file.json',
      '/path/to/some-file.json',
      '.json',
      '/path/to/.json',
    }) do
      _assert_unapplied(p)
    end
  end
end

function TestPathUtil:testGetRealPathForFullPathArg()
  reaper.GetProjectPath = function()
    return self.PROJECT_PATH
  end

  reaper.GetOS = function() return 'Win64' end

  local path_arg = "path\\to\\some-file.json"

  lu.assertEquals(PathUtil.get_real_path(path_arg), self.PROJECT_PATH .. "\\" .. path_arg)

  path_arg = "C:\\path\\to\\some-file.json"

  lu.assertEquals(PathUtil.get_real_path(path_arg), path_arg)
end

function TestPathUtil:testGetRevealCommand()
  local windows_path = "C:\\path\\to\\some-file.json"
  local windows_expectation = '%SystemRoot%\\explorer.exe /select,"' .. windows_path .. '"'

  local mac_and_other_path = "/path/to/some-file.json"
  local mac_expectation = '/usr/bin/env open -R "' .. mac_and_other_path .. '"'
  local other_expectation = '/usr/bin/env xdg-open "' .. mac_and_other_path .. '"'

  reaper.GetOS = function() return "Win64" end
  lu.assertEquals(PathUtil.get_reveal_command(windows_path), windows_expectation)

  reaper.GetOS = function() return "OSX64" end
  lu.assertEquals(PathUtil.get_reveal_command(mac_and_other_path), mac_expectation)

  reaper.GetOS = function() return "Other" end
  lu.assertEquals(PathUtil.get_reveal_command(mac_and_other_path), other_expectation)
end

function TestPathUtil:testIsFullPath()
  local os_returnval = 'Win64'
  reaper.GetOS = function() return os_returnval end

  local assertions = {
    [true] = {
      "C:\\path\\to\\some-file.json",
      "Z:\\path\\to\\some-file.json",
      "\\Server\\Volume\\File"
    },
    [false] = {
      "path\\to\\some-file.json",
      "some-file.json",
    },
  }

  for expected, path in pairs(assertions) do
    for _, p in ipairs(path) do
      lu.assertEquals(PathUtil.is_full_path(p), expected)
    end
  end

  for _, os_string in ipairs({"OSX64", "Other"}) do
    os_returnval = os_string
    assertions = {
      [true] = {
        "/path/to/some-file.json",
      },
      [false] = {
        "path/to/some-file.json",
        "some-file.json",
      },
    }

    for expected, path in pairs(assertions) do
      for _, p in ipairs(path) do
        lu.assertEquals(PathUtil.is_full_path(p), expected)
      end
    end
  end
end

function TestPathUtil:testPathSeparator()
  local os_returnval
  reaper.GetOS = function() return os_returnval end

  local assertions = {
    ["\\"] = {"Win32", "Win64"},
    ["/"] = {"OSX32", "OSX64", "macOS-arm64", "Other" },
  }

  for separator, os_strings in pairs(assertions) do
    for _, os_string in ipairs(os_strings) do
      os_returnval = os_string
      lu.assertEquals(PathUtil._path_separator(), separator)
    end
  end
end

os.exit(lu.LuaUnit.run())
