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

    local my_table = settings:table('my_table', { foo = 'bar' })
    local my_table_value = my_table:get()
    my_table:set({ foo = 'baz' })

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

  JSONFile Example:

    local file_storage = Storage.JSONFile('/path/to/data.json', {
      schema_version = 2,
      minimum_version = 1,
      migrations = {
        [2] = function(data) -- v1 -> v2 migration
          data._data.new_field = 'default_value'
          return data
        end
      }
    })

    local my_setting = file_storage:boolean('my_setting', true)
    local my_table = file_storage:table('config', { theme = 'dark' })

  API:

    Storage.ExtState.make(options)
      Create a new ExtState storage object.

      options:
        section (string) - The section name for the ExtState data.
        persist (boolean) - Whether the data should persist between sessions.

    Storage.memory(value)
      Create a memory storage cell.

      value (any) - The initial value for the storage data.

    Storage.ProjExtState.make(options)
      Create a new ProjExtState storage object.

      options:
        project (integer) - The project identifier.
        extname (string) - The extension name for the ProjExtState data.

    Storage.JSONFile(filepath, options)
      Create a new JSON file storage object.

      filepath (string) - The absolute path to the JSON file.
      options (table, optional) - Configuration options:
        schema_version (number) - Current schema version (default: 1)
        minimum_version (number) - Minimum supported version (default: 1)
        migrations (table) - Migration functions indexed by target version

  Versioning & Migration:

    Schema versions use simple incrementing numbers (1, 2, 3, ...).
    Each storage instance manages its own schema and migrations.

    Migration functions:
      migrations[2] = function(data) -- Upgrade from v1 to v2
        -- Transform data structure
        return data
      end

    Migrations are applied sequentially from current version to target version.

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

    storage:table(key, default)
      Create a table storage cell.

      key (string) - The key for the storage data.
      default (table) - The default value for the storage data.

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

-- Storage Schema Versioning Utilities
-- Per-instance versioning with simple incrementing numbers

-- Apply migrations to upgrade data from one version to another
function Storage._apply_migrations(data, from_version, to_version, migrations, minimum_version)
  -- Ensure data has proper structure
  if not data._version then
    data._version = from_version or 1
  end

  -- Convert to numbers for easier comparison
  local current_version = tonumber(data._version) or 1
  local target_version = tonumber(to_version) or 1
  local min_version = tonumber(minimum_version) or 1

  -- Version compatibility check
  if current_version < min_version then
    error(string.format(
      "Storage schema version %d is too old (minimum supported: %d)",
      current_version, min_version
    ))
  end

  if current_version > target_version then
    error(string.format(
      "Storage schema version %d is newer than supported %d",
      current_version, target_version
    ))
  end

  -- Apply migrations sequentially
  if migrations then
    for version = current_version + 1, target_version do
      if migrations[version] then
        data = migrations[version](data)
        data._version = version
      end
    end
  end

  -- Ensure final version is set
  data._version = target_version

  return data
end

function Storage.memory(value)
  return Storage.Cell.new {
    get = function () return value end,
    set = function (new_value) value = new_value end,
    erase = function () value = nil end,
  }
end

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

function Storage:table(key, default)
  local engine = self.engine
  return Storage.Cell.new {
    get = function () return engine.get_table(key, default) end,
    set = function (value) engine.set_table(key, value) end,
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
      get_table = function (key, default)
        if not exists(key) then return default end
        return json.decode(reaper.GetExtState(section, key))
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
      set_table = function (key, value)
        reaper.SetExtState(section, key, json.encode(value), persist)
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
      get_table = function (key, default)
        local rv, value = reaper.GetProjExtState(project, extname, key)
        if rv == 0 then return default end
        return json.decode(value)
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
      set_table = function (key, value)
        reaper.SetProjExtState(project, extname, key, json.encode(value))
      end,
      erase = function (key)
        reaper.SetProjExtState(project, extname, key, '')
      end,
    }
  end,
}

-- JSON File Storage Backend
--
-- Reads are served from a process-wide write-through cache keyed by
-- filepath: every in-process read and write goes through this engine,
-- so the cache stays coherent without re-reading and re-decoding the
-- file on every get. Two caveats: files changed by anything OTHER than
-- this engine while the script runs are not seen until
-- Storage.JSONFile.invalidate(filepath); and readers share table
-- references with the cache, so treat loaded data as owned by whoever
-- saves it back.
Storage.JSONFile = {
  _cache = {},

  invalidate = function (filepath)
    if filepath then
      Storage.JSONFile._cache[filepath] = nil
    else
      Storage.JSONFile._cache = {}
    end
  end,

  make = function (options)
    assert(options.filepath, 'missing filepath')

    local filepath = options.filepath
    local schema_version = options.schema_version or 1
    local minimum_version = options.minimum_version or 1
    local migrations = options.migrations or {}

    -- Helper function to ensure directory exists
    local function ensure_dir(path)
      local dir = path:match("(.+)[/\\][^/\\]*$")
      if dir and not reaper.file_exists(dir) then
        -- Create directory recursively
        local parts = {}
        for part in dir:gmatch("[^/\\]+") do
          table.insert(parts, part)
        end

        local current_path = ""
        for i, part in ipairs(parts) do
          if i == 1 and string.match(part, "^[A-Za-z]:$") then
            -- Windows drive letter
            current_path = part .. "\\"
          else
            current_path = current_path .. (i == 1 and "" or "/") .. part
            if not reaper.file_exists(current_path) then
              reaper.RecursiveCreateDirectory(current_path, 0)
            end
          end
        end
      end
    end

    -- Load data from file
    local function load_data()
      if not reaper.file_exists(filepath) then
        return { _version = schema_version, _data = {} }
      end

      local file = io.open(filepath, "r")
      if not file then
        return { _version = schema_version, _data = {} }
      end

      local content = file:read("*all")
      file:close()

      if content == "" then
        return { _version = schema_version, _data = {} }
      end

      local success, decoded = pcall(json.decode, content)
      if not success then
        -- Backup corrupted file and start fresh
        local backup_path = filepath .. ".backup." .. os.time()
        os.rename(filepath, backup_path)
        return { _version = schema_version, _data = {} }
      end

      -- Ensure proper structure
      if type(decoded) ~= "table" then
        decoded = { _data = decoded }
      end
      if not decoded._version then
        decoded._version = schema_version -- Use current schema version as fallback
      end
      if not decoded._data then
        decoded._data = {}
      end

      -- Apply migrations if needed
      decoded = Storage._apply_migrations(decoded, decoded._version, schema_version, migrations, minimum_version)

      return decoded
    end

    -- Save data to file atomically
    local function save_data(data)
      ensure_dir(filepath)

      -- Ensure we're always saving with current schema version
      data._version = schema_version

      local temp_filepath = filepath .. ".tmp." .. os.time()
      local file = io.open(temp_filepath, "w")
      if not file then
        error("Failed to open file for writing: " .. temp_filepath)
      end

      file:write(json.encode(data))
      file:close()

      -- Atomic move
      local success = os.rename(temp_filepath, filepath)
      if not success then
        os.remove(temp_filepath)
        error("Failed to atomically write file: " .. filepath)
      end

      Storage.JSONFile._cache[filepath] = data
    end

    -- Get data, from the shared cache when possible
    local function get_data()
      local cached = Storage.JSONFile._cache[filepath]
      if cached then
        return cached
      end

      local data = load_data()
      Storage.JSONFile._cache[filepath] = data
      return data
    end

    -- Set value and save immediately
    local function set_value(key, value)
      local data = get_data()
      data._data[key] = value
      save_data(data)
    end

    -- Get value with default
    local function get_value(key, default)
      local data = get_data()
      local value = data._data[key]
      return value ~= nil and value or default
    end

    -- Erase value
    local function erase_value(key)
      local data = get_data()
      data._data[key] = nil
      save_data(data)
    end

    return Storage.new {
      get_boolean = function (key, default)
        return get_value(key, default)
      end,
      get_number = function (key, default)
        return get_value(key, default)
      end,
      get_string = function (key, default)
        return get_value(key, default)
      end,
      get_table = function (key, default)
        return get_value(key, default)
      end,
      set_boolean = function (key, value)
        set_value(key, value)
      end,
      set_number = function (key, value)
        set_value(key, value)
      end,
      set_string = function (key, value)
        set_value(key, value)
      end,
      set_table = function (key, value)
        set_value(key, value)
      end,
      erase = function (key)
        erase_value(key)
      end,
    }
  end,
}

-- Add callable metatable to Storage.JSONFile for convenience constructor
setmetatable(Storage.JSONFile, {
  __call = function(self, filepath, options)
    options = options or {}

    -- Support both old and new API styles
    if type(filepath) == "table" then
      -- New API: Storage.JSONFile({ filepath = "...", schema_version = 2, ... })
      options = filepath
    else
      -- Convenience API: Storage.JSONFile("path", { schema_version = 2, ... })
      -- Backward compatible: Storage.JSONFile("path")
      options.filepath = filepath
    end

    return self.make(options)
  end
})
