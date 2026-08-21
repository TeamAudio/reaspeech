--[[

  ProjectFolderScan.lua - obvious ingest candidates in the project folder

  A bounded walk of the project directory, classifying the files a
  Script Matching session most likely wants: transcript JSONs (sniffed
  for a segments field - cheap evidence, the real import still
  validates) and script spreadsheets (whatever the import gating
  accepts - every format reaper-datasource reads). Surfaced as QUICK
  CHOICES in the link-transcript and
  import-material flows, sparing the file browser.

]]--

ProjectFolderScan = Polo {
  MAX_DEPTH = 2,
  SNIFF_BYTES = 65536,

  -- ReaSpeech's own storage and output; nothing in there is ingest
  SKIP_DIRS = {
    ['reaspeech'] = true,
    ['reaspeech_export'] = true,
  },
}

function ProjectFolderScan:init()
  Logging().init(self, 'ProjectFolderScan')

  -- Injectable for tests; reads the head of a file for sniffing
  self.read_head = self.read_head or function(filepath, bytes)
    local file = io.open(filepath, 'rb')
    if not file then return nil end
    local head = file:read(bytes)
    file:close()
    return head
  end
end

-- Returns { transcripts = {path...}, spreadsheets = {path...} },
-- each sorted for a stable quick-choice list
function ProjectFolderScan:scan()
  local results = { transcripts = {}, spreadsheets = {} }

  for _, root in ipairs(self:roots()) do
    self:scan_directory(root, 1, results)
  end

  table.sort(results.transcripts)
  table.sort(results.spreadsheets)
  return results
end

-- The project folder proper (the .RPP's directory) plus the media
-- path when it lives elsewhere. GetProjectPathEx alone returns the
-- MEDIA directory (often <project>/Media), which would miss files
-- sitting next to the .RPP; a media path inside the project folder
-- is already covered by the bounded walk.
function ProjectFolderScan:roots()
  local roots = {}

  local _, project_file = reaper.EnumProjects(-1, '')
  if project_file and project_file ~= '' then
    local project_dir = project_file:match('^(.*)[/\\][^/\\]+$')
    if project_dir and project_dir ~= '' then
      table.insert(roots, PathUtil.normalize(project_dir))
    end
  end

  local media_path = reaper.GetProjectPathEx(0)
  if media_path and media_path ~= '' then
    media_path = PathUtil.normalize(media_path)
    local covered = false
    for _, root in ipairs(roots) do
      if media_path == root or media_path:sub(1, #root + 1) == root .. '/' then
        covered = true
      end
    end
    if not covered then
      table.insert(roots, media_path)
    end
  end

  return roots
end

function ProjectFolderScan:scan_directory(dir, depth, results)
  local index = 0
  while true do
    local filename = reaper.EnumerateFiles(dir, index)
    if not filename then break end
    self:classify(dir .. '/' .. filename, filename, results)
    index = index + 1
  end

  if depth >= ProjectFolderScan.MAX_DEPTH then return end

  index = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(dir, index)
    if not subdir then break end
    if not ProjectFolderScan.SKIP_DIRS[subdir] and subdir:sub(1, 1) ~= '.' then
      self:scan_directory(dir .. '/' .. subdir, depth + 1, results)
    end
    index = index + 1
  end
end

function ProjectFolderScan:classify(filepath, filename, results)
  if filename:sub(1, 1) == '.' then return end

  if filename:lower():sub(-5) == '.json' then
    if self:sniff_transcript(filepath) then
      table.insert(results.transcripts, filepath)
    end
  elseif ScriptMaterialExcelSpreadsheet:can_handle_file(filepath) then
    table.insert(results.spreadsheets, filepath)
  end
end

-- Cheap shape check without a full parse: a ReaSpeech transcript JSON
-- carries a top-level segments field near the head of the file
function ProjectFolderScan:sniff_transcript(filepath)
  local head = self.read_head(filepath, ProjectFolderScan.SNIFF_BYTES)
  return head ~= nil and head:find('"segments"', 1, true) ~= nil
end
