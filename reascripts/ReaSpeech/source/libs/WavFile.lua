--[[

  WavFile.lua - read WAV metadata and slice sample ranges to new files

  Pure Lua file I/O; no REAPER APIs. Supports PCM and IEEE-float WAV
  sources of any bit depth and channel count. Lets callers cut audio
  ranges directly from source media without touching the project.

]]--

WavFile = {}

-- Parse the RIFF structure. Returns a table with format fields and the
-- data chunk's offset/size, or nil and an error message.
function WavFile.info(path)
  local f = io.open(path, 'rb')
  if not f then
    return nil, 'Could not open file: ' .. path
  end

  local header = f:read(12)
  if not header or #header < 12 then
    f:close()
    return nil, 'Not a RIFF/WAVE file: ' .. path
  end
  if header:sub(1, 4) == 'RF64' then
    f:close()
    return nil, 'RF64/BW64 (>4GB WAV) is not supported: ' .. path
  end
  if header:sub(1, 4) ~= 'RIFF' or header:sub(9, 12) ~= 'WAVE' then
    f:close()
    return nil, 'Not a RIFF/WAVE file: ' .. path
  end

  local info = { path = path }

  while true do
    local chunk_header = f:read(8)
    if not chunk_header or #chunk_header < 8 then break end

    local chunk_id = chunk_header:sub(1, 4)
    local chunk_size = string.unpack('<I4', chunk_header, 5)

    if chunk_id == 'fmt ' then
      local fmt = f:read(chunk_size)
      info.audio_format, info.channels, info.sample_rate,
        info.byte_rate, info.block_align, info.bits_per_sample =
        string.unpack('<I2I2I4I4I2I2', fmt)
      info.fmt_chunk = fmt
    elseif chunk_id == 'data' then
      info.data_offset = f:seek()
      info.data_size = chunk_size
      break
    else
      f:seek('cur', chunk_size + (chunk_size % 2))
    end
  end

  f:close()

  if not info.fmt_chunk then
    return nil, 'No fmt chunk found: ' .. path
  end
  if not info.data_offset then
    return nil, 'No data chunk found: ' .. path
  end
  -- 1 = PCM, 3 = IEEE float, 0xFFFE = WAVE_FORMAT_EXTENSIBLE (safe for
  -- slicing: the fmt chunk is copied verbatim and only block_align and
  -- sample_rate are interpreted)
  if info.audio_format ~= 1 and info.audio_format ~= 3 and info.audio_format ~= 0xFFFE then
    return nil, ('Unsupported WAV format %d (only PCM and float): %s')
      :format(info.audio_format, path)
  end

  info.frame_count = info.data_size // info.block_align
  info.duration = info.frame_count / info.sample_rate

  return info
end

-- Decimated min/max peaks of [start_seconds, end_seconds) for waveform
-- display: `columns` {low, high} pairs normalized to [-1, 1], first
-- channel only, examining up to PEAK_SAMPLES_PER_COLUMN evenly spaced
-- frames per column (display-grade decimation, not exhaustive).
-- Returns the list, or nil and an error message.
WavFile.PEAK_SAMPLES_PER_COLUMN = 64

function WavFile.peaks(path, start_seconds, end_seconds, columns)
  local info, err = WavFile.info(path)
  if not info then return nil, err end

  local read_sample = WavFile._sample_reader(info)
  if not read_sample then
    return nil, ('Unsupported sample format for peaks (%d-bit, format %d): %s')
      :format(info.bits_per_sample, info.audio_format, path)
  end

  local first_frame = math.max(0, math.floor(start_seconds * info.sample_rate))
  local last_frame = math.min(info.frame_count, math.ceil(end_seconds * info.sample_rate))
  if last_frame <= first_frame or (columns or 0) < 1 then
    return nil, 'Empty peak range'
  end

  local f = io.open(path, 'rb')
  if not f then return nil, 'Could not open file: ' .. path end
  f:seek('set', info.data_offset + first_frame * info.block_align)
  local data = f:read((last_frame - first_frame) * info.block_align)
  f:close()
  if not data then return nil, 'Could not read sample data: ' .. path end

  -- Trust the bytes actually read, not the header, for the frame count
  local total_frames = #data // info.block_align
  if total_frames < 1 then return nil, 'Empty peak range' end

  local frames_per_column = total_frames / columns
  local stride = math.max(1, math.floor(frames_per_column / WavFile.PEAK_SAMPLES_PER_COLUMN))

  local peaks = {}
  for column = 0, columns - 1 do
    local column_first = math.floor(column * frames_per_column)
    local column_last = math.min(total_frames - 1, math.ceil((column + 1) * frames_per_column) - 1)

    local low, high
    for frame = column_first, column_last, stride do
      local sample = read_sample(data, frame * info.block_align + 1)
      if not low or sample < low then low = sample end
      if not high or sample > high then high = sample end
    end

    table.insert(peaks, { low or 0, high or 0 })
  end

  return peaks
end

-- Returns fn(data, offset) -> first-channel sample in [-1, 1], or nil
-- for formats peaks can't interpret. WAVE_FORMAT_EXTENSIBLE guesses:
-- 32-bit means float, anything else integer PCM.
function WavFile._sample_reader(info)
  local bits = info.bits_per_sample
  local is_float = info.audio_format == 3 or (info.audio_format == 0xFFFE and bits == 32)

  if is_float and bits == 32 then
    return function(data, offset)
      local value = string.unpack('<f', data, offset)
      if value > 1 then return 1 elseif value < -1 then return -1 end
      return value
    end
  elseif bits == 16 then
    return function(data, offset)
      return string.unpack('<i2', data, offset) / 32768
    end
  elseif bits == 24 then
    return function(data, offset)
      local b1, b2, b3 = data:byte(offset, offset + 2)
      local value = b1 | (b2 << 8) | (b3 << 16)
      if value >= 0x800000 then value = value - 0x1000000 end
      return value / 8388608
    end
  elseif bits == 32 then
    return function(data, offset)
      return string.unpack('<i4', data, offset) / 2147483648
    end
  elseif bits == 8 then
    return function(data, offset)
      return (data:byte(offset) - 128) / 128
    end
  end

  return nil
end

-- Copy [start_seconds, end_seconds) of source_path into destination_path
-- as a minimal WAV with the same format. The range is clamped to the
-- file's bounds. Returns true, or false and an error message.
function WavFile.slice(source_path, destination_path, start_seconds, end_seconds)
  local info, err = WavFile.info(source_path)
  if not info then
    return false, err
  end

  local first_frame = math.max(0, math.floor(start_seconds * info.sample_rate))
  local last_frame = math.min(info.frame_count, math.ceil(end_seconds * info.sample_rate))

  if last_frame <= first_frame then
    return false, ('Empty slice range %.2f-%.2fs (source is %.2fs)')
      :format(start_seconds, end_seconds, info.duration)
  end

  local src = io.open(source_path, 'rb')
  if not src then
    return false, 'Could not open source: ' .. source_path
  end

  local dst = io.open(destination_path, 'wb')
  if not dst then
    src:close()
    return false, 'Could not open destination for writing: ' .. destination_path
  end

  local data_bytes = (last_frame - first_frame) * info.block_align
  local fmt = info.fmt_chunk
  local riff_size = 4 + (8 + #fmt) + (8 + data_bytes)

  dst:write('RIFF', string.pack('<I4', riff_size), 'WAVE')
  dst:write('fmt ', string.pack('<I4', #fmt), fmt)
  dst:write('data', string.pack('<I4', data_bytes))

  src:seek('set', info.data_offset + first_frame * info.block_align)

  local remaining = data_bytes
  while remaining > 0 do
    local chunk = src:read(math.min(remaining, 1024 * 1024))
    if not chunk or #chunk == 0 then break end
    dst:write(chunk)
    remaining = remaining - #chunk
  end

  src:close()
  dst:close()

  if remaining > 0 then
    return false, ('Source ended %d bytes short of the requested slice'):format(remaining)
  end

  return true
end
