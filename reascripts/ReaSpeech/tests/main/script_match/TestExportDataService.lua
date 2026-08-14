package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/Polo')

Logging = function()
  return {
    init = function(obj)
      obj.log = function() end
      obj.debug = function() end
    end
  }
end

require('main/script_match/export/ExportDataService')

-- slice_duration and estimate_file_size are pure math; a bare instance
-- avoids the service's session/workflow wiring
local function make_service()
  return setmetatable({}, { __index = ExportDataService })
end

--

TestSliceDuration = {}

function TestSliceDuration:testMatchRangeOnly()
  local service = make_service()
  lu.assertEquals(service:slice_duration({ start_time = 1.0, end_time = 3.0 }, {}), 2.0)
end

function TestSliceDuration:testRollsExtendTheRange()
  local service = make_service()
  local duration = service:slice_duration(
    { start_time = 1.0, end_time = 3.0 },
    { pre_roll_seconds = 0.5, post_roll_seconds = 1.0 })
  lu.assertEquals(duration, 3.5)
end

function TestSliceDuration:testMinimumDurationClamps()
  local service = make_service()
  local duration = service:slice_duration(
    { start_time = 1.0, end_time = 1.5 },
    { min_duration_seconds = 2.0 })
  lu.assertEquals(duration, 2.0)
end

function TestSliceDuration:testFallsBackToMatchDuration()
  local service = make_service()
  local duration = service:slice_duration(
    { duration = 1.5 },
    { post_roll_seconds = 0.5 })
  lu.assertEquals(duration, 2.0)
end

--

TestEstimateFileSize = {}

function TestEstimateFileSize:testUsesSourceByteRate()
  local service = make_service()
  -- 48k/24-bit stereo source: byte rate 288000
  lu.assertEquals(service:estimate_file_size(2.0, 288000), 576044)
end

function TestEstimateFileSize:testFallbackWhenSourceUnreadable()
  local service = make_service()
  lu.assertEquals(service:estimate_file_size(1.0, nil), 88244)
end

--

os.exit(lu.LuaUnit.run())
