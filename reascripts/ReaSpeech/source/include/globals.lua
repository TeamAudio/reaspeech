--[[

  globals.lua - Global functions

]]--

-- Create ImGui namespace
ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end

-- For debugging
function dump(o)
  if type(o) ~= "table" then return tostring(o) end
  local result = {"{"}
  for k, v in pairs(o) do
    k = type(k) == "string" and k or "[" .. dump(k) .. "]"
    v = type(v) == "string" and '"' .. v .. '"' or dump(v)
    table.insert(result, k .. " = " .. v .. ",")
  end
  if #result == 1 then return "{}" end
  result[#result] = result[#result]:gsub(",$", "")
  table.insert(result, "}")
  return table.concat(result, " ")
end
