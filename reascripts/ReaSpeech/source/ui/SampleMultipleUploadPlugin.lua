--[[

  SampleMultipleUploadPlugin.lua - sample plugin to upload multiple files

]]--

SampleMultipleUploadPlugin = Plugin {
  ENDPOINT = '/test_multiple_upload'
}

function SampleMultipleUploadPlugin:init()
  assert(self.app, 'SampleMultipleUploadPlugin: plugin host app is required')
  Logging().init(self, 'SampleMultipleUploadPlugin')
  self._controls = SampleMultipleUploadControls.new(self)
  self._actions = SampleMultipleUploadActions.new(self)
end

function SampleMultipleUploadPlugin:upload_files()
  local request = {
    endpoint = self.ENDPOINT,
    data = {},
    file_uploads = {
      file1 = self._controls.upload_file1:value(),
      file2 = self._controls.upload_file2:value(),
    },
    jobs = {},
    callback = self:handle_response()
  }

  self.app:submit_request(request)
end

function SampleMultipleUploadPlugin:handle_response()
  return function(response)
    local uploaded_files = {}

    if response.file1 then
      table.insert(uploaded_files, "  - " .. response.file1)
    end

    if response.file2 then
      table.insert(uploaded_files, "  - " .. response.file2)
    end

    self.app.alert_popup:show(
      table.concat(uploaded_files, '\n'),
      'Files uploaded successfully')
  end
end
