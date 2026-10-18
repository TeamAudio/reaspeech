--[[

  ProjectStorage.lua - Storage module for project-specific JSON data

  JSONStorage rooted at the current project's path: the file lives at
  <project path>/<subpath>. Errors when no project is open or the
  project has not been saved.

  Example:

    local project_storage = ProjectStorage('reaspeech/config.json', {
      schema_version = 3,
      minimum_version = 1,
      migrations = ProjectMigrations
    })

    local project_setting = project_storage:string('transcription_model', 'medium')

  API:

    ProjectStorage(subpath, options)
      Create a storage object for the JSON file at subpath, relative
      to the project path. Options are forwarded to JSONStorage
      (schema_version, minimum_version, migrations). The
      options-table form ProjectStorage({ subpath = ..., ... }) is
      also supported.

]]--

-- Top-level global rather than a Storage member: assigning
-- Storage.ProjectStorage here would require Storage to have loaded
-- first, and the production bundle's file order is alphabetical, not
-- dependency-driven. JSONStorage and PathUtil are referenced only
-- inside make(), at call time.
ProjectStorage = {
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

    return JSONStorage.make {
      filepath = get_filepath(),
      schema_version = schema_version,
      minimum_version = minimum_version,
      migrations = migrations
    }
  end,
}

-- Add callable metatable to ProjectStorage for convenience constructor
setmetatable(ProjectStorage, {
  __call = function(self, subpath, options)
    options = options or {}

    -- Support both old and new API styles
    if type(subpath) == "table" then
      -- New API: ProjectStorage({ subpath = "...", schema_version = 2, ... })
      options = subpath
    else
      -- Convenience API: ProjectStorage("path", { schema_version = 2, ... })
      options.subpath = subpath
    end

    return self.make(options)
  end
})
