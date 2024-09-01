--[[

  CurlRequest.lua - wrapper interface for curl

]]--

CurlRequest = Polo {
  DEFAULT_HTTP_METHOD = 'GET',
  DEFAULT_HEADERS = {
    ['accept'] = 'application/json',
  },
  DEFAULT_CURL_TIMEOUT = 0,
  BASE_CURL_OPTIONS = {
    '--http1.1', -- force HTTP/1.1
    '-i',        -- include headers in output
  },
  DEFAULT_EXTRA_CURL_OPTIONS = {},
  DEFAULT_ERROR_HANDLER = function(_msg) end,
  DEFAULT_TIMEOUT_HANDLER = function() end,
}

function CurlRequest.async(options)
  options.use_async = true
  options.output_file = Tempfile:name()
  options.extra_curl_options = {
    ' -o ' .. options.output_file,
  }
  options.sentinel_file = Tempfile:name()

  return CurlRequest.new(options)
end

function CurlRequest:init()
  assert(self.url, 'missing url')

  self.query_data = self.query_data or {}
  self.http_method = self.http_method or self.DEFAULT_HTTP_METHOD
  self.headers = self.headers or self.DEFAULT_HEADERS
  self.curl_timeout = self.curl_timeout or self.DEFAULT_CURL_TIMEOUT
  self.extra_curl_options = self.extra_curl_options or self.DEFAULT_EXTRA_CURL_OPTIONS
  self.error_handler = self.error_handler or self.DEFAULT_ERROR_HANDLER
  self.timeout_handler = self.timeout_handler or self.DEFAULT_TIMEOUT_HANDLER
end

function CurlRequest:execute()
  local command = self:build_curl_command()

  app:debug('CurlRequest: ' .. command)

  if self.use_async then
    return self:execute_async(command)
  else
    return self:execute_sync(command)
  end
end

function CurlRequest:ready()
  if self.response then
    return true
  end

  if not self.check_sentinel(self.sentinel_file) then
    return false
  end

  local f = io.open(self.output_file, 'r')
  if not f then
    self.error_msg = "Couldn't open output file: " .. tostring(self.output_file)
    Tempfile.remove(self.sentinel_file)
    return false
  end

  local http_status, body = self.http_status_and_body(f)
  f:close()

  if http_status == -1 then
    app:debug(body .. ", trying again later")
    return false
  end

  Tempfile:remove(self.output_file)
  Tempfile:remove(self.sentinel_file)

  if http_status ~= 200 then
    self.error_msg = "Server responded with status " .. http_status
    self.error_handler(self.error_msg)
    app:log(self.error_msg)
    app:debug(body)
    return false
  end

  if #body < 1 then
    self.error_msg = "Empty response"
    self.error_handler(self.error_msg)
    return false
  end

  if app:trap(function()
    self.response = json.decode(body)
  end) then
    return true
  else
    self.error_msg = "JSON parse error"
    self.error_handler(self.error_msg)
    app:log(body)
    return false
  end
end

function CurlRequest:error()
  return self.error_msg
end

function CurlRequest:result()
  return self.response
end

function CurlRequest:execute_sync(command)
  local exec_result = (ExecProcess.new { command }):wait()

  if exec_result == nil then
    local msg = "Unable to run curl"
    app:log(msg)
    self.error_handler(msg)
    return nil
  end

  local status, output = exec_result:match("(%d+)\n(.*)")
  status = tonumber(status)

  if status == 28 then
    app:debug("Curl timeout reached")
    self.timeout_handler()
    return nil
  elseif status ~= 0 then
    local msg = "Curl failed with status " .. status
    app:debug(msg)
    self.error_handler(msg)
    return nil
  end

  local response_status, response_body = self.http_status_and_body(output)

  if response_status >= 400 then
    local msg = "Request failed with status " .. response_status
    app:log(msg)
    self.error_handler(msg)
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

function CurlRequest:execute_async(command)
  local executor = ExecProcess.new { command, self.touch_cmd(self.sentinel_file) }

  if not executor:background() then
    local err = "Unable to run curl"
    app:log(err)
    self.error_handler(err)
  end

  return self
end

function CurlRequest:build_curl_command()
  return table.concat({
    self.get_curl_cmd(),
    self:get_url(),
    self:extra_curl_arguments(),
    self:curl_http_method_argument(),
    self:curl_header_arguments(),
    self:file_upload_arguments(),
    self:curl_timeout_argument(),
  }, ' ')
end

function CurlRequest.get_curl_cmd()
  local curl = "curl"
  if not reaper.GetOS():find("Win") then
    curl = "/usr/bin/curl"
  end
  return curl
end

function CurlRequest:get_url()
  local query = {}
  for k, v in pairs(self.query_data) do
    table.insert(query, k .. '=' .. url.quote(v))
  end

  return self.url .. '?' .. table.concat(query, '&')
end

function CurlRequest:extra_curl_arguments()
  return table.concat(self.BASE_CURL_OPTIONS, ' ')
    .. ' ' .. table.concat(self.extra_curl_options, ' ')
end

function CurlRequest:curl_http_method_argument()
  if self.http_method == 'GET' then
    return ''
  end

  return " -X " .. self.http_method
end

function CurlRequest:curl_header_arguments()
  local headers = ""
  for key, value in pairs(self.headers) do
    headers = headers .. ' -H "' .. key .. ': ' .. value .. '"'
  end

  return headers
end

function CurlRequest:file_upload_arguments()
  local uploads = ""
  for key, path in pairs(self.file_uploads or {}) do
    uploads = uploads .. ' -F ' .. self._maybe_quote(key .. '=@"' .. path .. '"')
  end

  return uploads
end

function CurlRequest._maybe_quote(str)
  if reaper.GetOS():find("Win") then
    return str
  else
    return "'" .. str .. "'"
  end
end

function CurlRequest:curl_timeout_argument()
  if not self.async or self.curl_timeout == 0 then
    return ''
  end

  return ' -m ' .. self.curl_timeout
end

CurlRequest.check_sentinel = function(filename)
  local sentinel = io.open(filename, 'r')

  if not sentinel then
    return false
  end

  sentinel:close()
  return true
end

CurlRequest.touch_cmd = function(filename)
  if reaper.GetOS():find("Win") then
    return 'echo. > "' .. filename .. '"'
  else
    return 'touch "' .. filename .. '"'
  end
end

function CurlRequest.http_status_and_body(response)
  local headers, content = CurlRequest._split_curl_response(response)
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

function CurlRequest._split_curl_response(input)
  local line_iterator = CurlRequest._line_iterator(input)
  local chunk_iterator = CurlRequest._chunk_iterator(line_iterator)
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

function CurlRequest._line_iterator(input)
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

function CurlRequest._chunk_iterator(line_iterator)
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
