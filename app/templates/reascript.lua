-- ReaScript launcher for {{ name }}

Script = {
  name = "{{ name }}",
  host = "{{ host }}",
  lua = _VERSION:match('[%d.]+'),
  timeout = 30000,
  model_name = "{{ model_name }}",
}

function Script:load()
  local curl = "curl"
  local tempfile = os.tmpname()
  if reaper.GetOS():find("Win") then
    tempfile = os.getenv("TEMP") .. tempfile
  else
    curl = "/usr/bin/curl"
  end
  local command = curl
    .. " -sSf http://" .. self.host .. "/static/reascripts/" .. self.name
    .. "/" .. self.name .. "-" .. self.lua .. '.luac -o "' .. tempfile .. '"'
  local result = reaper.ExecProcess(command, self.timeout)
  local offset = result:find("\n")
  local code = tonumber(result:sub(1, offset - 1))
  local output = result:sub(offset + 1, -1)
  if code == 0 then
    loadfile(tempfile)()
  else
    reaper.ShowConsoleMsg(output)
  end
  os.remove(tempfile)
end

Script:load()
