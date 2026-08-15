package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('vendor/json')
require('vendor/url')

require('libs/Polo')
require('libs/EnvUtil')
require('libs/Storage')
require('libs/Logging')
require('libs/TableUtils')
require('libs/Tempfile')
require('libs/CurlRequest')

--

local function new_request(options)
  return CurlRequest().new(options)
end

local function header_values(request)
  local args = request:curl_header_arguments()
  local values = {}
  for i = 1, #args, 2 do
    values[args[i + 1]] = true
  end
  return values
end

TestCurlRequest = {}

function TestCurlRequest:setUp()
  reaper.__test_setUp()
  self._is_windows = EnvUtil.is_windows
  -- mock_reaper reports Win64, which sends Tempfile down its %TEMP%
  -- branch; use the Unix behavior so temp files work in the test env
  EnvUtil.is_windows = function() return false end
end

function TestCurlRequest:tearDown()
  EnvUtil.is_windows = self._is_windows
  Tempfile:remove_all()
end

function TestCurlRequest:testJsonDataWritesBodyToTempFile()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    json_data = { foo = 'bar', count = 5 },
  }

  local args = request:json_data_arguments()

  lu.assertEquals(args[1], '-d')
  lu.assertEquals(args[2]:sub(1, 1), '@')

  local path = args[2]:sub(2)
  lu.assertEquals(request.json_temp_file, path)

  local f = assert(io.open(path, 'r'))
  local contents = f:read('*all')
  f:close()

  lu.assertEquals(json.decode(contents), { foo = 'bar', count = 5 })
end

function TestCurlRequest:testJsonDataKeepsBodyOutOfCommandLine()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    json_data = { key = 'sensitive payload' },
  }

  local command = request:build_curl_command()

  lu.assertNil(command:find('sensitive payload', 1, true))
  lu.assertNotNil(command:find('-d @', 1, true))
end

function TestCurlRequest:testJsonDataSetsContentTypeHeader()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    json_data = { foo = 'bar' },
  }

  local headers = header_values(request)
  lu.assertTrue(headers['"Content-Type: application/json"'])
end

function TestCurlRequest:testJsonDataDoesNotPolluteDefaultHeaders()
  new_request {
    url = 'http://localhost:9000/endpoint',
    json_data = { foo = 'bar' },
  }

  lu.assertNil(CurlRequest().DEFAULT_HEADERS['Content-Type'])

  local plain_request = new_request { url = 'http://localhost:9000/endpoint' }
  lu.assertNil(plain_request.headers['Content-Type'])
end

function TestCurlRequest:testJsonDataDoesNotMutateCallerHeaders()
  local caller_headers = { ['X-Custom'] = 'yes' }

  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    json_data = { foo = 'bar' },
    headers = caller_headers,
  }

  lu.assertNil(caller_headers['Content-Type'])

  local headers = header_values(request)
  lu.assertTrue(headers['"X-Custom: yes"'])
  lu.assertTrue(headers['"Content-Type: application/json"'])
end

function TestCurlRequest:testUrlWithoutQueryHasNoQuestionMark()
  local request = new_request { url = 'http://localhost:9000/endpoint' }

  lu.assertEquals(request:get_url(), { '"http://localhost:9000/endpoint"' })
end

function TestCurlRequest:testUrlQuotesQueryValues()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    query_data = { q = 'two words' },
  }

  lu.assertEquals(request:get_url(),
    { '"http://localhost:9000/endpoint?q=' .. url.quote('two words') .. '"' })
end

function TestCurlRequest:testUrlStringifiesNumericQueryValues()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    query_data = { n = 5 },
  }

  lu.assertEquals(request:get_url(), { '"http://localhost:9000/endpoint?n=5"' })
end

function TestCurlRequest:testUrlSkipsTableQueryValues()
  local request = new_request {
    url = 'http://localhost:9000/endpoint',
    query_data = { t = { 1, 2, 3 } },
  }

  lu.assertEquals(request:get_url(), { '"http://localhost:9000/endpoint"' })
end

function TestCurlRequest:testHttpMethodArguments()
  local get_request = new_request { url = 'http://localhost:9000/endpoint' }
  lu.assertEquals(get_request:curl_http_method_argument(), '')

  local post_request = new_request {
    url = 'http://localhost:9000/endpoint',
    http_method = 'POST',
  }
  lu.assertEquals(post_request:curl_http_method_argument(), { '-X', 'POST' })
end

function TestCurlRequest:testHttpStatusAndBodyParsesResponse()
  local request = new_request { url = 'http://localhost:9000/endpoint' }

  local status, body = request:http_status_and_body(
    'HTTP/1.1 200 OK\nContent-Type: application/json\n\n{"ok":true}')

  lu.assertEquals(status, 200)
  lu.assertEquals(json.decode(body), { ok = true })
end

function TestCurlRequest:testHttpStatusAndBodySkipsContinueHeaders()
  local request = new_request { url = 'http://localhost:9000/endpoint' }

  local status, body = request:http_status_and_body(
    'HTTP/1.1 100 Continue\n\nHTTP/1.1 200 OK\nContent-Length: 4\n\nbody')

  lu.assertEquals(status, 200)
  lu.assertEquals(body, 'body')
end

function TestCurlRequest:testHttpStatusAndBodyRejectsGarbage()
  local request = new_request { url = 'http://localhost:9000/endpoint' }

  local status = request:http_status_and_body('not an http response')

  lu.assertEquals(status, -1)
end

function TestCurlRequest:testMaybeQuotePlatformBehavior()
  EnvUtil.is_windows = function() return false end
  lu.assertEquals(CurlRequest()._maybe_quote('a b'), "'a b'")

  EnvUtil.is_windows = function() return true end
  lu.assertEquals(CurlRequest()._maybe_quote('a b'), 'a b')
end

os.exit(lu.LuaUnit.run())
