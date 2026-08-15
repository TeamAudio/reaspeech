package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('libs/WavFile')

--

local TEST_DIR = os.tmpname()
os.remove(TEST_DIR)
os.execute('mkdir -p "' .. TEST_DIR .. '"')

-- Build a 16-bit mono WAV at 100Hz where sample value == frame index,
-- with a junk chunk before data to exercise chunk skipping
local function write_test_wav(path, frames, rate)
  rate = rate or 100
  local samples = {}
  for i = 0, frames - 1 do
    samples[#samples + 1] = string.pack('<i2', i)
  end
  local data = table.concat(samples)

  local fmt = string.pack('<I2I2I4I4I2I2', 1, 1, rate, rate * 2, 2, 16)
  local junk = 'xyzzy' -- odd-sized chunk: tests padding-aware skipping

  local body =
    'fmt ' .. string.pack('<I4', #fmt) .. fmt ..
    'junk' .. string.pack('<I4', #junk) .. junk .. '\0' ..
    'data' .. string.pack('<I4', #data) .. data

  local f = assert(io.open(path, 'wb'))
  f:write('RIFF', string.pack('<I4', 4 + #body), 'WAVE', body)
  f:close()
end

local SRC = TEST_DIR .. '/source.wav'
write_test_wav(SRC, 200) -- 2 seconds at 100Hz

local function read_samples(path)
  local info = assert(WavFile.info(path))
  local f = assert(io.open(path, 'rb'))
  f:seek('set', info.data_offset)
  local data = f:read(info.data_size)
  f:close()
  local out = {}
  for i = 1, #data, 2 do
    out[#out + 1] = string.unpack('<i2', data, i)
  end
  return out, info
end

--

TestWavFileInfo = {}

function TestWavFileInfo:testParsesFormat()
  local info = assert(WavFile.info(SRC))
  lu.assertEquals(info.channels, 1)
  lu.assertEquals(info.sample_rate, 100)
  lu.assertEquals(info.bits_per_sample, 16)
  lu.assertEquals(info.frame_count, 200)
  lu.assertAlmostEquals(info.duration, 2.0, 0.001)
end

-- Mono WAVE_FORMAT_EXTENSIBLE fixture: a full 40-byte fmt chunk whose
-- SubFormat GUID carries the given format code (1 = PCM, 3 = float)
local function write_extensible_wav(path, subformat_code, bits, data)
  local block_align = bits // 8
  local guid = string.pack('<I2', subformat_code)
    .. '\x00\x00\x00\x00\x10\x00\x80\x00\x00\xAA\x00\x38\x9B\x71'
  local fmt = string.pack('<I2I2I4I4I2I2I2I2I4',
    0xFFFE, 1, 48000, 48000 * block_align, block_align, bits, 22, bits, 1)
    .. guid
  local body = 'fmt ' .. string.pack('<I4', #fmt) .. fmt
    .. 'data' .. string.pack('<I4', #data) .. data
  local f = assert(io.open(path, 'wb'))
  f:write('RIFF', string.pack('<I4', 4 + #body), 'WAVE', body)
  f:close()
end

function TestWavFileInfo:testAcceptsExtensibleFormat()
  local path = TEST_DIR .. '/extensible.wav'
  write_extensible_wav(path, 3, 32, string.rep('\0', 40)) -- 10 frames of silence

  local info = assert(WavFile.info(path))
  lu.assertEquals(info.audio_format, 0xFFFE)
  lu.assertEquals(info.subformat, 3)
  lu.assertEquals(info.frame_count, 10)
end

function TestWavFileInfo:testRejectsTruncatedFmtChunk()
  local path = TEST_DIR .. '/truncated-fmt.wav'
  local fmt = string.pack('<I2I2I4', 1, 1, 48000) -- 8 of the required 16 bytes
  local body = 'fmt ' .. string.pack('<I4', #fmt) .. fmt
  local f = assert(io.open(path, 'wb'))
  f:write('RIFF', string.pack('<I4', 4 + #body), 'WAVE', body)
  f:close()

  local info, err = WavFile.info(path)
  lu.assertNil(info)
  lu.assertStrContains(err, 'Truncated fmt chunk')
end

function TestWavFileInfo:testConsumesFmtChunkPadding()
  local path = TEST_DIR .. '/odd-fmt.wav'
  local fmt = string.pack('<I2I2I4I4I2I2', 1, 1, 100, 200, 2, 16) .. '\1' -- odd size
  local data = string.rep('\0', 4)
  local body = 'fmt ' .. string.pack('<I4', #fmt) .. fmt .. '\0'
    .. 'data' .. string.pack('<I4', #data) .. data
  local f = assert(io.open(path, 'wb'))
  f:write('RIFF', string.pack('<I4', 4 + #body), 'WAVE', body)
  f:close()

  local info = assert(WavFile.info(path))
  lu.assertEquals(info.frame_count, 2)
end

function TestWavFileInfo:testRejectsRF64()
  local path = TEST_DIR .. '/big.wav'
  local f = assert(io.open(path, 'wb'))
  f:write('RF64', string.pack('<I4', 0xFFFFFFFF), 'WAVE', string.rep('\0', 64))
  f:close()

  local info, err = WavFile.info(path)
  lu.assertIsNil(info)
  lu.assertStrContains(err, 'RF64')
end

function TestWavFileInfo:testRejectsNonWav()
  local path = TEST_DIR .. '/not_a_wav.txt'
  local f = io.open(path, 'wb') f:write('hello there, not audio') f:close()
  local info, err = WavFile.info(path)
  lu.assertIsNil(info)
  lu.assertStrContains(err, 'Not a RIFF/WAVE')
end

TestWavFileSlice = {}

function TestWavFileSlice:testSliceMiddle()
  local out = TEST_DIR .. '/middle.wav'
  lu.assertIsTrue(WavFile.slice(SRC, out, 0.5, 1.5))

  local samples, info = read_samples(out)
  lu.assertEquals(#samples, 100)
  lu.assertEquals(samples[1], 50)  -- frame at 0.5s
  lu.assertEquals(samples[100], 149)
  lu.assertAlmostEquals(info.duration, 1.0, 0.001)
  lu.assertEquals(info.sample_rate, 100)
end

function TestWavFileSlice:testClampsToFileBounds()
  local out = TEST_DIR .. '/clamped.wav'
  lu.assertIsTrue(WavFile.slice(SRC, out, -5.0, 99.0))

  local samples = read_samples(out)
  lu.assertEquals(#samples, 200) -- whole file
  lu.assertEquals(samples[1], 0)
end

function TestWavFileSlice:testEmptyRangeFails()
  local out = TEST_DIR .. '/empty.wav'
  local ok, err = WavFile.slice(SRC, out, 5.0, 6.0)
  lu.assertIsFalse(ok)
  lu.assertStrContains(err, 'Empty slice range')
end

function TestWavFileSlice:testMissingSourceFails()
  local ok, err = WavFile.slice(TEST_DIR .. '/nope.wav', TEST_DIR .. '/out.wav', 0, 1)
  lu.assertIsFalse(ok)
  lu.assertStrContains(err, 'Could not open')
end

--

TestWavFilePeaks = {}

function TestWavFilePeaks:testColumnsCoverRangeInOrder()
  -- Source ramps 0..199 over 2s: highs must ascend column to column
  local peaks = assert(WavFile.peaks(SRC, 0, 2, 4))
  lu.assertEquals(#peaks, 4)

  for i = 1, 3 do
    lu.assertIsTrue(peaks[i + 1][2] > peaks[i][2])
  end

  -- First column's low is sample 0; last column's high is near 199/32768
  lu.assertEquals(peaks[1][1], 0)
  lu.assertIsTrue(math.abs(peaks[4][2] - 199 / 32768) < 0.001)
end

function TestWavFilePeaks:testValuesNormalized()
  local peaks = assert(WavFile.peaks(SRC, 0, 2, 8))
  for _, pair in ipairs(peaks) do
    lu.assertIsTrue(pair[1] >= -1 and pair[1] <= 1)
    lu.assertIsTrue(pair[2] >= -1 and pair[2] <= 1)
    lu.assertIsTrue(pair[1] <= pair[2])
  end
end

function TestWavFilePeaks:testRangeClampsToFile()
  local peaks = assert(WavFile.peaks(SRC, 1.5, 99, 2))
  lu.assertEquals(#peaks, 2)
end

function TestWavFilePeaks:testEmptyRangeErrors()
  local peaks, err = WavFile.peaks(SRC, 5, 6, 4)
  lu.assertIsNil(peaks)
  lu.assertStrContains(err, 'Empty')
end

function TestWavFilePeaks:testExtensibleFloatUsesSubformat()
  local path = TEST_DIR .. '/extensible-float.wav'
  write_extensible_wav(path, 3, 32,
    string.pack('<f', 0.5) .. string.pack('<f', -0.25))

  local peaks = assert(WavFile.peaks(path, 0, 1, 1))
  lu.assertAlmostEquals(peaks[1][1], -0.25, 0.001)
  lu.assertAlmostEquals(peaks[1][2], 0.5, 0.001)
end

function TestWavFilePeaks:testExtensiblePcm32UsesSubformat()
  -- 32-bit extensible PCM must be read as integer samples, not float
  local path = TEST_DIR .. '/extensible-pcm32.wav'
  write_extensible_wav(path, 1, 32,
    string.pack('<i4', 0x40000000) .. string.pack('<i4', -0x40000000))

  local peaks = assert(WavFile.peaks(path, 0, 1, 1))
  lu.assertAlmostEquals(peaks[1][1], -0.5, 0.001)
  lu.assertAlmostEquals(peaks[1][2], 0.5, 0.001)
end

function TestWavFilePeaks:testMissingFileErrors()
  local peaks, err = WavFile.peaks(TEST_DIR .. '/nope.wav', 0, 1, 4)
  lu.assertIsNil(peaks)
  lu.assertStrContains(err, 'Could not open')
end

--

local result = lu.LuaUnit.run()
os.execute('rm -rf "' .. TEST_DIR .. '"')
os.exit(result)
