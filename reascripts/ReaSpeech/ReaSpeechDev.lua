--[[

ReaSpeechDev.lua - ReaSpeech UI development version

]]--

local script_path, _ = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

dofile(script_path .. 'source/include/globals.lua')
dofile(script_path .. '../common/vendor/json.lua')
dofile(script_path .. '../common/vendor/url.lua')

-- Considering extracting this into a function, but we're getting into
-- chicken/egg territory with where that would be defined and how it'd be used.
for _, source_dir in pairs({'resources/images', '../common/libs', 'source'}) do
  local source_file, source_index = '', 0
  while (source_file ~= nil) do
    source_file = reaper.EnumerateFiles(script_path .. source_dir, source_index)
    if source_file and source_file:sub(-4) == '.lua' then
      reaper.ShowConsoleMsg(script_path .. source_dir .. '/' .. source_file .. '\n')
      dofile(script_path .. source_dir .. '/' .. source_file)
    end
    source_index = source_index + 1
  end
end

-- We're not inside of docker! We're undocked!
Script = {
  name = "ReaSpeechDev",
  host = "localhost:9000",
  protocol = "http:",
  env = "production",
  lua = _VERSION:match('[%d.]+'),
  timeout = 30000,
}

Fonts.LOCAL_FILE = script_path .. "../../app/static/reascripts/ReaSpeech/icons.ttf"

dofile(script_path .. 'source/include/main.lua')

-- Uncomment the following line to load example response data
-- dofile(script_path .. 'examples/response_data_json.lua')
