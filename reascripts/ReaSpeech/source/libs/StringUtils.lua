--[[

    StringUtils.lua - miscellaneous string utiilities

]]--

string.split = string.split or function(str, sep)
  local result = {}

  local pattern = ("([^%s]*)"):format(sep)

  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end

  return result
end