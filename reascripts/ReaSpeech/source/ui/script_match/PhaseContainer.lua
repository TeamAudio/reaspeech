
-- Phase mixin: identity (key/name), completion status for the phase
-- bar, and the full-height content container. One phase is visible at
-- a time; activation hooks (will_activate) are invoked by
-- ScriptMatchWorkflow when the active phase changes.
PhaseContainer = {
  CONTENT_PADDING = 8,
}

PhaseContainer.init = function(target, key, name, icon)

  local phase_container = {
    key = key or 'phase_container',
    name = name or 'Untitled Phase',
    icon = icon,
    logger = {}
  }

  Logging().init(phase_container.logger, 'PhaseContainer')

  phase_container.logger:log("Initialized for phase: " .. phase_container.name)

  target._phase_container = phase_container

  target.get_completion_status = PhaseContainer.get_completion_status
  target.phase_key = PhaseContainer.phase_key
  target.phase_name = PhaseContainer.phase_name
  target.phase_icon = PhaseContainer.phase_icon
  target.render = PhaseContainer.render
end

function PhaseContainer:phase_key()
  return self._phase_container.key
end


function PhaseContainer:phase_name()
  return self._phase_container.name
end

function PhaseContainer:phase_icon()
  return self._phase_container.icon
end

function PhaseContainer:render()
  -- Full-height view: the active phase owns all space below the phase
  -- bar. Inner children fill and scroll themselves, so a scrollbar
  -- here is always a layout bug, never useful
  if ImGui.BeginChild(Ctx(), self:phase_key() .. "_container", 0, 0, ImGui.ChildFlags_None(), ImGui.WindowFlags_NoScrollbar()) then
    Trap(function()
      ImGui.Dummy(Ctx(), 0, PhaseContainer.CONTENT_PADDING)
      self:render_content_callback()
    end)

    ImGui.EndChild(Ctx())
  end
end

-- The ASCII indicator vocabulary ('*' done, 'o' in progress, '!'
-- attention) maps to EmojiText tags for the phase card taglines
PhaseContainer.INDICATOR_TAGS = {
  ['*'] = 'check',
  ['o'] = 'progress',
  ['!'] = 'warning',
}

function PhaseContainer:get_completion_status()
  local target_status = self.get_status_callback and self:get_status_callback() or {}

  -- No defaults: a phase with nothing to report shows no icon or hint
  return {
    indicator = target_status.indicator,
    hint = target_status.hint,
  }
end
