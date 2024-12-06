--[[

  Tempfile.lua - Temporary filename creator

]]--

Tempfile = {
  _names = {}
}

function Tempfile:name()
  if EnvUtil.is_windows() then
    return self:_add_name(os.getenv("TEMP") .. os.tmpname())
  else
    return self:_add_name(os.tmpname())
  end
end

function Tempfile:remove(name)
  if os.remove(name) then
    self._names[name] = nil
  end
end

function Tempfile:remove_all()
  for name, _ in pairs(self._names) do
    os.remove(name)
  end
end

function Tempfile:_add_name(name)
  self._names[name] = true
  return name
end
