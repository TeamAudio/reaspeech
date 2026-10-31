--[[

ReaSpeechDev.lua - ReaSpeech development entry point

]]--

local script_path, _ = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")

local function recursive_dofile(dir)
  local source_file, source_index = '', 0

  while (source_file ~= nil) do
    source_file = reaper.EnumerateFiles(dir, source_index)
    if source_file and source_file:sub(-4) == '.lua' then
      local source_path = dir .. '/' .. source_file
      reaper.ShowConsoleMsg(source_path .. '\n')
      dofile(source_path)
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
dofile(script_path .. 'vendor/json.lua')

recursive_dofile(script_path .. 'resources/images')

for _, source_dir in ipairs({'libs', 'ui', 'main'}) do
  recursive_dofile(script_path .. 'source/' .. source_dir)
end

dofile(script_path .. 'version.lua')
dofile(script_path .. 'source/include/main.lua')
