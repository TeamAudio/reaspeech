--[[

  ReaSpeechProductActivationUI.lua - ReaSpeech Product Activation UI

]]--

ReaSpeechProductActivationUI = Polo {
  LARGE_ITEM_WIDTH = 375,
}

function ReaSpeechProductActivationUI:init()
  assert(self.product_activation, 'missing product activation')
  self.license_input = ''
end

function ReaSpeechProductActivationUI:render()
  if self.product_activation.state ~= "activated" then
    self:render_activation_inputs()
    return
  end

  if not self.product_activation.config:get('eula_signed') then
    self:render_EULA_inputs()
    return
  end
end

function ReaSpeechProductActivationUI:render_activation_inputs()
  ImGui.Text(ctx, ('Welcome to ReaSpeech by Tech Audio'))
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
  ImGui.Text(ctx, ('Please enter your license key to get started'))
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 5)
  ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
  app:trap(function ()
    local rv, value = ImGui.InputText(ctx, '##', self.license_input)
    if rv then
      self.license_input = value
    end
    if self.product_activation.activation_message ~= "" then
      --Possibly make this ColorText with and change depending on message
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, self.product_activation.activation_message)
    end
  end)
  ImGui.PopItemWidth(ctx)
  ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 30)
  if ImGui.Button(ctx, "Submit") then
    self:handle_product_activation(self.license_input)
  end
end

function ReaSpeechProductActivationUI:render_EULA_inputs()
  ImGui.PushItemWidth(ctx, self.LARGE_ITEM_WIDTH)
  app:trap(function ()
    ImGui.Text(ctx, 'EULA')
    ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
    ImGui.TextWrapped(ctx, ReaSpeechEULAContent)
    ImGui.Dummy(ctx, self.LARGE_ITEM_WIDTH, 25)
     if ImGui.Button(ctx, "Agree") then
      self.product_activation.config:set('eula_signed', true)
    end
  end)
  ImGui.PopItemWidth(ctx)
end

function ReaSpeechProductActivationUI:handle_product_activation(input_license)
  --reaper.ShowConsoleMsg(tostring(input_license) .. '\n')
  self.product_activation:handle_product_activation(input_license)
end
