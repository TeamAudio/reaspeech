--[[

  ReaSpeechAPI.lua - ReaSpeech API client

]]--

ReaSpeechAPI = {
  CURL_TIMEOUT_SECONDS = 5,
  base_url = nil,
}

-- Initialize the module with the given base URL
-- Example: "http://localhost:9000"
function ReaSpeechAPI:init(base_url)
  self.base_url = base_url
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
function ReaSpeechAPI:fetch_json(url_path, http_method)
  http_method = http_method or 'GET'

  local curl = self:get_curl_cmd()
  local api_url = self:get_api_url(url_path)

  local http_method_argument = ""
  if http_method ~= 'GET' then
    http_method_argument = " -X " .. http_method
  end

  local command = table.concat({
    curl,
    ' "', api_url, '"',
    ' -H "accept: application/json"',
    http_method_argument,
    ' -m ', self.CURL_TIMEOUT_SECONDS,
    ' -s',
  })

  app:debug('Fetch JSON: ' .. command)

  local exec_result = reaper.ExecProcess(command, 0)

  if exec_result == nil then
    app:log("Unable to run curl")
    return nil
  end

  local status, output = exec_result:match("(%d+)\n(.*)")
  if tonumber(status) ~= 0 then
    app:debug("Curl failed with status " .. status)
    return nil
  end

  local response_json = nil
  if app:trap(function()
    response_json = json.decode(output)
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

  local command = table.concat({
    curl,
    ' "', api_url, '"',
    ' -H "accept: application/json"',
    http_method_argument,
    ' -i ',
    ' -o "', output_file, '"',
  })

  app:debug('Fetch large: ' .. command)

  if reaper.ExecProcess(command, -2) then
    return output_file
  else
    app:log("Unable to run curl")
    return nil
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

  local command = table.concat({
    curl,
    ' "', api_url, '?', table.concat(query, '&'), '"',
    ' -H "accept: application/json"',
    ' -H "Content-Type: multipart/form-data"',
    ' -F ', self:_maybe_quote('audio_file=@"' .. file_path .. '"'),
    ' -o "', output_file, '"',
  })

  app:log(file_path)
  app:debug('Post request: ' .. command)

  if reaper.ExecProcess(command, -2) then
    return output_file
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

function ReaSpeechAPI.response_status_and_body(response)
  local matcher = "HTTP/%d%.%d%s(%d+)%s.-\r\n\r\n(.*)"
  local response_status, response_body = response:match(matcher)
  if response_status == "100" then
    local next_response_status, next_response_body = response_body:match(matcher)
    if next_response_status then
      response_status = next_response_status
      response_body = next_response_body
    end
  end
  return tonumber(response_status), response_body
end