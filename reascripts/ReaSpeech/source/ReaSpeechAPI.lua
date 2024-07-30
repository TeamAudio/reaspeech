--[[

  ReaSpeechAPI.lua - ReaSpeech API client

]]--

ReaSpeechAPI = {
  CURL_TIMEOUT_SECONDS = 5,
  base_url = nil,
  endpoints = {
    asr = '/asr',
  }
}

function ReaSpeechAPI:init(host, protocol)
  protocol = protocol or 'http:'
  self.base_url = protocol .. '//' .. host
end

function ReaSpeechAPI:get_api_url(remote_path)
  local remote_path_no_leading_slash = remote_path:gsub("^/+", "")
  return ("%s/%s"):format(self.base_url, url.quote(remote_path_no_leading_slash))
end

function ReaSpeechAPI:get_curl_cmd()
  local curl = "curl"
  if not reaper.GetOS():find("Win") then
    curl = "/usr/bin/curl"
  end
  return curl
end

-- Fetch simple JSON responses. Will block until result or curl timeout.
-- For large amounts of data, use fetch_large instead.
function ReaSpeechAPI:fetch_json(url_path, http_method, error_handler, timeout_handler)
  http_method = http_method or 'GET'
  error_handler = error_handler or function(_msg) end
  timeout_handler = timeout_handler or function() end

  local curl = self:get_curl_cmd()
  local api_url = self:get_api_url(url_path)

  local http_method_argument = ""
  if http_method ~= 'GET' then
    http_method_argument = " -X " .. http_method
  end

  local command = table.concat({
    curl,
    ' "', api_url, '"',
    ' --http1.1',
    ' -H "accept: application/json"',
    http_method_argument,
    ' -m ', self.CURL_TIMEOUT_SECONDS,
    ' -s',
    ' -i',
  })

  app:debug('Fetch JSON: ' .. command)

  local exec_result = (ExecProcess.new { command }):wait()

  if exec_result == nil then
    local msg = "Unable to run curl"
    app:log(msg)
    error_handler(msg)
    return nil
  end

  local status, output = exec_result:match("(%d+)\n(.*)")
  status = tonumber(status)

  if status == 28 then
    app:debug("Curl timeout reached")
    timeout_handler()
    return nil
  elseif status ~= 0 then
    local msg = "Curl failed with status " .. status
    app:debug(msg)
    error_handler(msg)
    return nil
  end

  local response_status, response_body = self.http_status_and_body(output)

  if response_status >= 400 then
    local msg = "Request failed with status " .. response_status
    app:log(msg)
    error_handler(msg)
    return nil
  end

  local response_json = nil
  if app:trap(function()
    response_json = json.decode(response_body)
  end) then
    return response_json
  else
    app:log("JSON parse error")
    app:log(output)
    return nil
  end
end

-- Requests data that may be large or time-consuming.
-- This method is non-blocking, and does not give any indication that it has
-- completed. The path to the output file is returned.
function ReaSpeechAPI:fetch_large(url_path, http_method)
  http_method = http_method or 'GET'

  local curl = self:get_curl_cmd()
  local api_url = self:get_api_url(url_path)

  local http_method_argument = ""
  if http_method ~= 'GET' then
    http_method_argument = " -X " .. http_method
  end

  local output_file = Tempfile:name()
  local sentinel_file = Tempfile:name()

  local command = table.concat({
    curl,
    ' "', api_url, '"',
    ' --http1.1',
    ' -H "accept: application/json"',
    http_method_argument,
    ' -i ',
    ' -o "', output_file, '"',
  })

  app:debug('Fetch large: ' .. command)

  local executor = ExecProcess.new { command, self.touch_cmd(sentinel_file) }

  if executor:background() then
    return output_file, sentinel_file
  else
    app:log("Unable to run curl")
    return nil
  end
end

ReaSpeechAPI.touch_cmd = function(filename)
  if reaper.GetOS():find("Win") then
    return 'echo. > "' .. filename .. '"'
  else
    return 'touch "' .. filename .. '"'
  end
end

-- Uploads a file to start a request for processing.
-- This method is non-blocking, and does not give any indication that it has
-- completed. The path to the output file is returned.
function ReaSpeechAPI:post_request(url_path, data, file_path)
  local curl = self:get_curl_cmd()
  local api_url = self:get_api_url(url_path)

  local query = {}
  for k, v in pairs(data) do
    table.insert(query, k .. '=' .. url.quote(v))
  end

  local output_file = Tempfile:name()
  local sentinel_file = Tempfile:name()

  local command = table.concat({
    curl,
    ' "', api_url, '?', table.concat(query, '&'), '"',
    ' --http1.1',
    ' -H "accept: application/json"',
    ' -H "Content-Type: multipart/form-data"',
    ' -F ', self:_maybe_quote('audio_file=@"' .. file_path .. '"'),
    ' -i ',
    ' -o "', output_file, '"',
  })

  app:log(file_path)
  app:debug('Post request: ' .. command)

  local executor = ExecProcess.new { command, self.touch_cmd(sentinel_file) }

  if executor:background() then
    return output_file, sentinel_file
  else
    app:log("Unable to run curl")
    return nil
  end
end

function ReaSpeechAPI:_maybe_quote(arg)
  if reaper.GetOS():find("Win") then
    return arg
  else
    return "'" .. arg .. "'"
  end
end

function ReaSpeechAPI.http_status_and_body(response)
  local headers, content = ReaSpeechAPI._split_curl_response(response)
  local last_status_line = headers[#headers] and headers[#headers][1] or ''

  local status = last_status_line:match("^HTTP/%d%.%d%s+(%d+)")
  if not status then
    return -1, 'Status not found in headers'
  end

  local body = {}
  for _, chunk in pairs(content) do
    table.insert(body, table.concat(chunk, "\n"))
  end

  return tonumber(status), table.concat(body, "\n")
end

function ReaSpeechAPI._split_curl_response(input)
  local line_iterator = ReaSpeechAPI._line_iterator(input)
  local chunk_iterator = ReaSpeechAPI._chunk_iterator(line_iterator)
  local header_chunks = {}
  local content_chunks = {}
  local in_header = true
  for chunk in chunk_iterator do
    if in_header and chunk[1] and chunk[1]:match("^HTTP/%d%.%d") then
      table.insert(header_chunks, chunk)
    else
      in_header = false
      table.insert(content_chunks, chunk)
    end
  end
  return header_chunks, content_chunks
end

function ReaSpeechAPI._line_iterator(input)
  if type(input) == 'string' then
    local i = 1
    local lines = {}
    for line in input:gmatch("([^\n]*)\n?") do
      table.insert(lines, line)
    end
    return function ()
      local line = lines[i]
      i = i + 1
      return line
    end
  else
    return input:lines()
  end
end

function ReaSpeechAPI._chunk_iterator(line_iterator)
  return function ()
    local chunk = nil
    while true do
      local line = line_iterator()
      if line == nil or line:match("^%s*$") then break end
      chunk = chunk or {}
      table.insert(chunk, line)
    end
    return chunk
  end
end
