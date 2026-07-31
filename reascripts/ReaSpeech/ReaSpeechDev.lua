--[[

ReaSpeechDev.lua - ReaSpeech UI development version

]]--

local script_path, _ = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

local function recursive_dofile(dir)
  local source_file, source_index = '', 0

  local initializer = dir .. '/_module.lua'
  if reaper.file_exists(initializer) then
    reaper.ShowConsoleMsg(initializer .. '\n')
    dofile(initializer)
  end

  while (source_file ~= nil) do
    source_file = reaper.EnumerateFiles(dir, source_index)
    if source_file and source_file:sub(-4) == '.lua' then
      local source_path = dir .. '/' .. source_file

      if source_path ~= initializer then
        reaper.ShowConsoleMsg(source_path .. '\n')
        dofile(source_path)
      end
    end
    source_index = source_index + 1
  end

  local subdir, subdir_index = '', 0
  while (subdir ~= nil) do
    subdir = reaper.EnumerateSubdirectories(dir, subdir_index)
    if subdir then
      recursive_dofile(dir .. '/' .. subdir)
    end
    subdir_index = subdir_index + 1
  end
end

dofile(script_path .. 'source/include/globals.lua')

for _, source_dir in pairs({'../vendor', '../resources', 'libs', 'ui', 'main'}) do
  recursive_dofile(script_path .. 'source/' .. source_dir)
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

dofile(script_path .. 'source/include/main.lua')

-- Uncomment the following line to load example response data
-- dofile(script_path .. 'examples/response_data_json.lua')
