--[[

  Storage.lua - Persistence helper for configuration data

  ExtState Example:

    local settings = Storage.ExtState.make {
      section = 'MyScript.Settings',
      persist = true,
    }

    local my_setting = settings:boolean('my_setting', true)
    local my_number = settings:number('my_number', 42)
    local my_string = settings:string('my_string', 'hello')

    local my_setting_value = my_setting:get()
    my_setting:set(not my_setting_value)
    my_setting:erase()

    local my_number_value = my_number:get()
    my_number:set(my_number_value + 1)

    local my_string_value = my_string:get()
    my_string:set(my_string_value .. ' world')

  ProjExtState Example:

    local proj_storage = Storage.ProjExtState.make {
      project = 0,
      extname = 'MyExtension',
    }

    local my_proj_setting = proj_settings:boolean('my_proj_setting', true)
    local my_proj_number = proj_settings:number('my_proj_number', 42)
    local my_proj_string = proj_settings:string('my_proj_string', 'hello')

    local my_proj_setting_value = my_proj_setting:get()
    my_proj_setting:set(not my_proj_setting_value)
    my_proj_setting:erase()

    local my_proj_number_value = my_proj_number:get()
    my_proj_number:set(my_proj_number_value + 1)

    local my_proj_string_value = my_proj_string:get()
    my_proj_string:set(my_proj_string_value .. ' world')

  API:

    Storage.ExtState.make(options)
      Create a new ExtState storage object.

      options:
        section (string) - The section name for the ExtState data.
        persist (boolean) - Whether the data should persist between sessions.

    Storage.ProjExtState.make(options)
      Create a new ProjExtState storage object.

      options:
        project (integer) - The project identifier.
        extname (string) - The extension name for the ProjExtState data.

    storage:boolean(key, default)
      Create a boolean storage cell.

      key (string) - The key for the storage data.
      default (boolean) - The default value for the storage data.

    storage:number(key, default)
      Create a number storage cell.

      key (string) - The key for the storage data.
      default (number) - The default value for the storage data.

    storage:string(key, default)
      Create a string storage cell.

      key (string) - The key for the storage data.
      default (string) - The default value for the storage data.

    cell:get()
      Get the value of the storage cell.

    cell:set(value)
      Set the value of the storage cell.

    cell:erase()
      Erase the storage data.

]]--

Storage = {
  new = function (engine)
    local o = { engine = engine }
    setmetatable(o, Storage)
    return o
  end,
}
Storage.__index = Storage

function Storage:boolean(key, default)
  local engine = self.engine
  return Storage.Cell.new {
    get = function () return engine.get_boolean(key, default) end,
    set = function (value) engine.set_boolean(key, value) end,
    erase = function () engine.erase(key) end,
  }
end

function Storage:number(key, default)
  local engine = self.engine
  return Storage.Cell.new {
    get = function () return engine.get_number(key, default) end,
    set = function (value) engine.set_number(key, value) end,
    erase = function () engine.erase(key) end,
  }
end

function Storage:string(key, default)
  local engine = self.engine
  return Storage.Cell.new {
    get = function () return engine.get_string(key, default) end,
    set = function (value) engine.set_string(key, value) end,
    erase = function () engine.erase(key) end,
  }
end

function Storage._boolean_to_string(bool)
  return bool and 'true' or 'false'
end

function Storage._number_to_string(num)
  return tostring(tonumber(num) or 0)
end

function Storage._string_to_boolean(str)
  return str == 'true'
end

function Storage._string_to_number(str)
  return tonumber(str) or 0
end

Storage.Cell = {
  new = function (methods)
    local o = {}

    if methods.get then
      function o:get(key)
        return methods.get(key)
      end
    end

    if methods.set then
      function o:set(value)
        return methods.set(value)
      end
    end

    if methods.erase then
      function o:erase()
        return methods.erase()
      end
    end

    setmetatable(o, Storage.Cell)

    return o
  end
}
Storage.Cell.__index = Storage.Cell

Storage.ExtState = {
  make = function (options)
    assert(options.section, 'missing section')

    local section = options.section
    local persist = options.persist or false

    local exists = function (key)
      return reaper.HasExtState(section, key)
    end

    return Storage.new {
      get_boolean = function (key, default)
        if not exists(key) then return default end
        return Storage._string_to_boolean(reaper.GetExtState(section, key))
      end,
      get_number = function (key, default)
        if not exists(key) then return default end
        return Storage._string_to_number(reaper.GetExtState(section, key))
      end,
      get_string = function (key, default)
        if not exists(key) then return default end
        return reaper.GetExtState(section, key)
      end,
      set_boolean = function (key, value)
        reaper.SetExtState(section, key, Storage._boolean_to_string(value), persist)
      end,
      set_number = function (key, value)
        reaper.SetExtState(section, key, Storage._number_to_string(value), persist)
      end,
      set_string = function (key, value)
        reaper.SetExtState(section, key, tostring(value), persist)
      end,
      erase = function (key)
        reaper.DeleteExtState(section, key, persist)
      end,
    }
  end,
}

Storage.ProjExtState = {
  make = function (options)
    assert(options.project, 'missing project')
    assert(options.extname, 'missing extname')

    local project = options.project
    local extname = options.extname

    return Storage.new {
      get_boolean = function (key, default)
        local rv, value = reaper.GetProjExtState(project, extname, key)
        if rv == 0 then return default end
        return Storage._string_to_boolean(value)
      end,
      get_number = function (key, default)
        local rv, value = reaper.GetProjExtState(project, extname, key)
        if rv == 0 then return default end
        return Storage._string_to_number(value)
      end,
      get_string = function (key, default)
        local rv, value = reaper.GetProjExtState(project, extname, key)
        if rv == 0 then return default end
        return value
      end,
      set_boolean = function (key, value)
        reaper.SetProjExtState(project, extname, key, Storage._boolean_to_string(value))
      end,
      set_number = function (key, value)
        reaper.SetProjExtState(project, extname, key, Storage._number_to_string(value))
      end,
      set_string = function (key, value)
        reaper.SetProjExtState(project, extname, key, tostring(value))
      end,
      erase = function (key)
        reaper.SetProjExtState(project, extname, key, '')
      end,
    }
  end,
}
