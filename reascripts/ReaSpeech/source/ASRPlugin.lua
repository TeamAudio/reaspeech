--[[

  ASRPlugin.lua - ASR plugin for ReaSpeech

]]--

ASRPlugin = Polo {
}

function ASRPlugin:init()
  Logging.init(self, 'ASRPlugin')
  self._actions = ASRActions.new(self)
end

function ASRPlugin:actions()
  return self._actions:actions()
end