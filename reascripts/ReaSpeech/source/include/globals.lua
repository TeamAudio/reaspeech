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
function dump(o, seen_tables)
  seen_tables = seen_tables or {}
  if type(o) ~= "table" then return tostring(o) end

  if seen_tables[tostring(o)] then
    return "{ circular reference detected }"
  end

  seen_tables[tostring(o)] = true

  local result = {"{"}
  for k, v in pairs(o) do
    k = type(k) == "string" and k or "[" .. dump(k, seen_tables) .. "]"
    v = type(v) == "string" and '"' .. v .. '"' or dump(v, seen_tables)
    table.insert(result, k .. " = " .. v .. ",")
  end
  if #result == 1 then return "{}" end
  result[#result] = result[#result]:gsub(",$", "")
  table.insert(result, "}")
  return table.concat(result, " ")
end
