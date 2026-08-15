--[[

    StringUtils.lua - miscellaneous string utiilities

]]--

local B64_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

string.base64_encode = string.base64_encode or function(str)
  local out = {}

  for i = 1, #str, 3 do
    local a, b, c = str:byte(i, i + 2)
    local n = a << 16 | (b or 0) << 8 | (c or 0)

    table.insert(out,
      B64_ALPHABET:sub((n >> 18 & 63) + 1, (n >> 18 & 63) + 1)
      .. B64_ALPHABET:sub((n >> 12 & 63) + 1, (n >> 12 & 63) + 1)
      .. (b and B64_ALPHABET:sub((n >> 6 & 63) + 1, (n >> 6 & 63) + 1) or '=')
      .. (c and B64_ALPHABET:sub((n & 63) + 1, (n & 63) + 1) or '='))
  end

  return table.concat(out)
end

-- Returns nil for anything that isn't valid base64
string.base64_decode = string.base64_decode or function(str)
  str = str:gsub('%s', '')
  if #str % 4 ~= 0 then return nil end

  local out = {}

  for i = 1, #str, 4 do
    local block = str:sub(i, i + 3)
    local n, pad = 0, 0

    for j = 1, 4 do
      local char = block:sub(j, j)
      if char == '=' then
        -- padding may only be the last one or two chars of the final block
        if j < 3 or i + 3 < #str then return nil end
        pad = pad + 1
        n = n << 6
      else
        local index = B64_ALPHABET:find(char, 1, true)
        if not index or pad > 0 then return nil end
        n = n << 6 | (index - 1)
      end
    end

    local bytes = string.char(n >> 16 & 255)
    if pad < 2 then bytes = bytes .. string.char(n >> 8 & 255) end
    if pad < 1 then bytes = bytes .. string.char(n & 255) end
    table.insert(out, bytes)
  end

  return table.concat(out)
end

string.split = string.split or function(str, sep)
  local result = {}

  local pattern = ("([^%s]*)"):format(sep)

  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end

  return result
end