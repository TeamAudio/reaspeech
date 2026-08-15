--[[

  TableUtils.lua - miscellaneous table utilities

]]--

-- Recursive copy of plain data tables (no cycle or metatable handling;
-- keys are shared with the original, only values are copied)
table.deep_copy = table.deep_copy or function(value)
  if type(value) ~= 'table' then return value end

  local result = {}
  for k, v in pairs(value) do
    result[k] = table.deep_copy(v)
  end
  return result
end

table.flatten = table.flatten or function(tables)
  local result = {}

  for _, t in ipairs(tables or {}) do
    if type(t) == 'table' then
      for _, u in ipairs(t) do
        table.insert(result, u)
      end
    end
  end

  return result
end