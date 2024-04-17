--[[

  ReaSpeechProductActivation.lua - Product key entry and activation checks

]]--

ReaSpeechProductActivation = {
  ACTIVATION_URL = "https://techaud.io/ProductActivationDeveloper.php",

  PRODUCT_ID = 79004057,
  PRODUCT_CHECK_COUNT = 4,
  PRODUCT_NAME = "ReaSpeech",
  --TODO Remove for official release
  PRODUCT_DEVELOPERLICENSE ="576D-C7C1-6C5A-429D",

  config = nil,

  -- nil = not activated
  -- 'pending' = activation in process
  -- 'activated' = activation complete
  state = nil,
  activation_message =""
}

ReaSpeechProductActivation.__index = ReaSpeechProductActivation
ReaSpeechProductActivation.new = function (o)
  o = o or {}
  setmetatable(o, ReaSpeechProductActivation)
  o:init()
  return o
end

function ReaSpeechProductActivation:init()
  self:init_config()
  self:activation_state_check()
end

function ReaSpeechProductActivation:init_config()
  self.config = OptionsConfig:new {
    section = 'ReaSpeech',
    options = {
      product_run_check_count = {'number', 0},
      product_license = {'string', ''},
      product_license_value = {'string', ''},
      eula_signed = {'boolean', false},
    }
  }
end

function ReaSpeechProductActivation:activation_state_check()
  local has_l = self.config:exists('product_license')
  local has_lv = self.config:exists('product_license_value')

  if has_l and has_lv then
    local count = self.config:get('product_run_check_count')

    if count > self.PRODUCT_CHECK_COUNT then
      self.state = 'pending'
      self:handle_product_activation_recheck()
    else
      self.state = 'activated'
      self.config:set('product_run_check_count', count + 1)
    end
  else
    self.state = nil
  end
end

function ReaSpeechProductActivation:handle_product_activation(product_key)
  product_key = string.gsub(product_key, "%s+", "")
  if #product_key == 0 then
    self.state = nil
    return
  end

  local process_result = self:send_activation_request(product_key, false)

  if process_result then
    self:process_activation_reply(product_key, process_result)
  end

end

function ReaSpeechProductActivation:handle_product_activation_recheck()
  local process_result = self:send_activation_request(self.config:get('product_license'), true)

  if process_result then
    if string.find(process_result, "SUCCESS") then
      self.state = 'activated'
      self.config:set('product_run_check_count', 0)
    elseif string.find(process_result, "FAILURE") then
      self.state = nil
      self.config:delete('product_license')
      self.config:delete('product_license_value')
    else
      -- Connection failed, silently ignore
      self.state = 'activated'
    end
  else
    -- Command failed, silently ignore
    self.state = 'activated'
  end
end

function ReaSpeechProductActivation:send_activation_request(product_key, is_recheck)
  local curl = "curl"
  if not reaper.GetOS():find("Win") then
    curl = "/usr/bin/curl"
  end

  local cmd_data_id = "user_product_id=" .. self.PRODUCT_ID
  local cmd_data_license = "user_license=" .. product_key
  local cmd_data_p_n = "user_product_name=" .. self.PRODUCT_NAME
  local cmd_data_p_v = "user_product_version=" .. ReaSpeechUI.VERSION
  local cmd_data_recheck = "recheck=" .. tostring(is_recheck)

  local cmd_args = (
    curl.." -X POST"
    .. " -d " .. cmd_data_id
    .. " -d " .. cmd_data_license
    .. " -d " .. cmd_data_p_n
    .. " -d " .. cmd_data_p_v
    .. " -d " .. cmd_data_recheck
    .. " \"" .. self.ACTIVATION_URL .. "\""
  )

  local process_result = reaper.ExecProcess(cmd_args, 8000)
  if process_result then
    return process_result
  else
    self.activation_message = "Activation failed: Connection Error"
    reaper.ShowConsoleMsg("Failed CURL at activation request" .. '\n')
    return nil
  end

end

function ReaSpeechProductActivation:process_activation_reply(product_key, process_result)
  process_result = string.gsub(process_result, "%s+", "")

  if string.find(process_result, "SUCCESS") then
    self.config:set('product_run_check_count', 1)
    self.config:set('product_license', product_key)
    self.config:set('product_license_value', process_result)

    self.state = 'activated'
    self.activation_message = "Thanks for your support! Enjoy :)"
  elseif string.find(process_result, "FAILURE") then
    self.state = nil
    if string.find(process_result, "Invalid_License") then
      self.activation_message = "Activation failed: Sorry, we didn't find a valid license :("
    else
      self.activation_message = "Activation failed: Sorry, you are out of activations :("
    end

  end
end