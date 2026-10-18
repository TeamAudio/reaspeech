--[[

  JSONStorage.lua - Persistence helper for data stored in JSON files

  Returns Storage objects (see Storage.lua for the cell API) backed by
  a JSON file on disk, with per-instance schema versioning.

  Example:

    local file_storage = JSONStorage('/path/to/data.json', {
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

    JSONStorage(filepath, options)
      Create a new JSON file storage object.

      filepath (string) - The absolute path to the JSON file.
      options (table, optional) - Configuration options:
        schema_version (number) - Current schema version (default: 1)
        minimum_version (number) - Minimum supported version (default: 1)
        migrations (table) - Migration functions indexed by target version

      The options-table form JSONStorage({ filepath = ..., ... }) is
      also supported.

    JSONStorage.invalidate(filepath)
      Drop the cached data for filepath (or the whole cache when
      called without arguments), forcing the next read to come
      from disk.

  Versioning & Migration:

    Schema versions use simple incrementing numbers (1, 2, 3, ...).
    Each storage instance manages its own schema and migrations.

    Migration functions:
      migrations[2] = function(data) -- Upgrade from v1 to v2
        -- Transform data structure
        return data
      end

    Migrations are applied sequentially from current version to target version.
    The migrations table may be sparse: a version with no entry is a
    no-op upgrade (the data was already compatible with that version).

  Reads are served from a process-wide write-through cache keyed by
  filepath: every in-process read and write goes through this engine,
  so the cache stays coherent without re-reading and re-decoding the
  file on every get. Two caveats: files changed by anything OTHER than
  this engine while the script runs are not seen until
  JSONStorage.invalidate(filepath); and readers share table
  references with the cache, so treat loaded data as owned by whoever
  saves it back.

]]--

-- Top-level global rather than a Storage member: the production bundle
-- concatenates library files in name order, so nothing here may assign
-- to or call a sibling-defined global at load time. References to
-- Storage happen inside make(), at call time.
JSONStorage = {
  _cache = {},

  invalidate = function (filepath)
    if filepath then
      JSONStorage._cache[filepath] = nil
    else
      JSONStorage._cache = {}
    end
  end,
}

-- Apply migrations to upgrade data from one version to another.
local function apply_migrations(data, from_version, to_version, migrations, minimum_version)
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
      "JSONStorage schema version %d is too old (minimum supported: %d)",
      current_version, min_version
    ))
  end

  if current_version > target_version then
    error(string.format(
      "JSONStorage schema version %d is newer than supported %d",
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

function JSONStorage.make(options)
  assert(options.filepath, 'missing filepath')

  local filepath = options.filepath
  local schema_version = options.schema_version or 1
  local minimum_version = options.minimum_version or 1
  local migrations = options.migrations or {}

  -- Helper function to ensure directory exists
  local function ensure_dir(path)
    local dir = path:match("(.+)[/\\][^/\\]*$")
    if dir and not reaper.file_exists(dir) then
      -- RecursiveCreateDirectory handles the whole path, including
      -- absolute roots and Windows drive letters
      reaper.RecursiveCreateDirectory(dir, 0)
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
    decoded = apply_migrations(decoded, decoded._version, schema_version, migrations, minimum_version)

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

    -- Atomic move; on Windows os.rename will not replace an existing
    -- destination, so fall back to remove-then-rename
    local success = os.rename(temp_filepath, filepath)
    if not success then
      os.remove(filepath)
      success = os.rename(temp_filepath, filepath)
    end
    if not success then
      os.remove(temp_filepath)
      error("Failed to atomically write file: " .. filepath)
    end

    JSONStorage._cache[filepath] = data
  end

  -- Get data, from the shared cache when possible
  local function get_data()
    local cached = JSONStorage._cache[filepath]
    if cached then
      return cached
    end

    local data = load_data()
    JSONStorage._cache[filepath] = data
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
end

-- Add callable metatable to JSONStorage for convenience constructor
setmetatable(JSONStorage, {
  __call = function(self, filepath, options)
    options = options or {}

    -- Support both old and new API styles
    if type(filepath) == "table" then
      -- New API: JSONStorage({ filepath = "...", schema_version = 2, ... })
      options = filepath
    else
      -- Convenience API: JSONStorage("path", { schema_version = 2, ... })
      -- Backward compatible: JSONStorage("path")
      options.filepath = filepath
    end

    return self.make(options)
  end
})
