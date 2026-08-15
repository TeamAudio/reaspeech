--[[

  ProjectJSON.lua - Storage module for project-specific JSON data

  ProjectJSON Example:

    local project_storage = Storage.ProjectJSON('reaspeech/config.json', {
      schema_version = 3,
      minimum_version = 1,
      migrations = ProjectMigrations
    })

    local project_setting = project_storage:string('transcription_model', 'medium')

  API:

]]--

-- Project-specific JSON Storage
Storage.ProjectJSON = {
  make = function (options)
    assert(options.subpath, 'missing subpath')

    local subpath = options.subpath
    local schema_version = options.schema_version or 1
    local minimum_version = options.minimum_version or 1
    local migrations = options.migrations or {}

    -- Get project directory
    local function get_project_path()
      local project_path = reaper.GetProjectPathEx(0)
      if not project_path or project_path == "" then
        error("No project is open or project has not been saved")
      end
      project_path = PathUtil.normalize(project_path)

      if not reaper.file_exists(project_path) then
        reaper.RecursiveCreateDirectory(project_path, 0)

        if not reaper.file_exists(project_path) then
          error("Failed to create project directory: " .. project_path)
        end
      end
      return project_path
    end

    -- Construct full file path
    local function get_filepath()
      local project_path = get_project_path()
      return project_path .. "/" .. subpath
    end

    return Storage.JSONFile.make {
      filepath = get_filepath(),
      schema_version = schema_version,
      minimum_version = minimum_version,
      migrations = migrations
    }
  end,
}

-- Add callable metatable to Storage.ProjectJSON for convenience constructor
setmetatable(Storage.ProjectJSON, {
  __call = function(self, subpath, options)
    options = options or {}

    -- Support both old and new API styles
    if type(subpath) == "table" then
      -- New API: Storage.ProjectJSON({ subpath = "...", schema_version = 2, ... })
      options = subpath
    else
      -- Convenience API: Storage.ProjectJSON("path", { schema_version = 2, ... })
      options.subpath = subpath
    end

    return self.make(options)
  end
})
