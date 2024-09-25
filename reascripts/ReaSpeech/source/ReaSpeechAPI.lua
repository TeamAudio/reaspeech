--[[

  ReaSpeechAPI.lua - ReaSpeech API client

]]--

ReaSpeechAPI = {
  CURL_TIMEOUT_SECONDS = 5,
  base_url = nil,
}

function ReaSpeechAPI:init(host, protocol)
  protocol = protocol or 'http:'
  self.base_url = protocol .. '//' .. host
end

function ReaSpeechAPI:get_api_url(remote_path)
  local remote_path_no_leading_slash = remote_path:gsub("^/+", "")
  return ("%s/%s"):format(self.base_url, url.quote(remote_path_no_leading_slash))
end

-- Fetch simple JSON responses. Will block until result or curl timeout.
-- For large amounts of data, use fetch_large instead.
function ReaSpeechAPI:fetch_json(url_path, http_method, error_handler, timeout_handler)
  local request = CurlRequest.new {
    url = self:get_api_url(url_path),
    method = http_method or 'GET',
    curl_timeout = self.CURL_TIMEOUT_SECONDS,
    extra_curl_options = {
      '-s' -- silent mode
    },
    error_handler = error_handler or function(_msg) end,
    timeout_handler = timeout_handler or function() end,
  }

  return request:execute()
end

-- Requests data that may be large or time-consuming.
-- This method is non-blocking, and does not give any indication that it has
-- completed. The path to the output file is returned.
function ReaSpeechAPI:fetch_large(url_path, http_method)
  local request = CurlRequest.async {
    url = self:get_api_url(url_path),
    method = http_method or 'GET',
  }

  return request:execute()
end

-- Uploads a file to start a request for processing.
-- This method is non-blocking, and does not give any indication that it has
-- completed. The path to the output file is returned.
function ReaSpeechAPI:post_request(url_path, data, file_uploads)
  local request = CurlRequest.async {
    url = self:get_api_url(url_path),
    method = 'POST',
    headers = {
      ['Content-Type'] = 'multipart/form-data',
    },
    query_data = data,
    file_uploads = file_uploads or {},
  }

  return request:execute()
end
