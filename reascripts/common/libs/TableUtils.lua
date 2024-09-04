--[[

  TableUtils.lua - miscellaneous table utilities

]]--

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