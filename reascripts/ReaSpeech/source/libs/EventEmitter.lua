--[[

  EventEmitter.lua - Schema-validated synchronous event bus

  Every event must be declared in the schema before it can be emitted
  or listened for. emit() raises on undeclared event names and on
  payloads missing a required field, so a malformed payload fails
  loudly at the emit site instead of surfacing later as a silent
  listener desync.

  Usage:

    local emitter = EventEmitter.new {
      schema = {
        thing_happened = { required = { 'thing_id' } },
      }
    }

    emitter:listen('thing_happened', function(event) ... end)
    emitter:emit('thing_happened', { thing_id = guid })

]]--

EventEmitter = Polo {}

function EventEmitter:init()
  assert(self.schema, 'EventEmitter: schema is required')
  self.listeners = {}
end

function EventEmitter:definition(event_name)
  local definition = self.schema[event_name]

  if not definition then
    error(("EventEmitter: undeclared event '%s'"):format(tostring(event_name)), 3)
  end

  return definition
end

function EventEmitter:listen(event_name, callback)
  self:definition(event_name)

  if not self.listeners[event_name] then
    self.listeners[event_name] = {}
  end

  table.insert(self.listeners[event_name], callback)
end

function EventEmitter:emit(event_name, payload)
  local definition = self:definition(event_name)

  payload = payload or {}

  for _, field in ipairs(definition.required or {}) do
    if payload[field] == nil then
      error(("EventEmitter: event '%s' missing required field '%s'")
        :format(event_name, field), 3)
    end
  end

  for _, callback in ipairs(self.listeners[event_name] or {}) do
    Trap(function()
      callback(payload)
    end)
  end
end

function EventEmitter:remove_listener(event_name, callback_to_remove)
  local filtered = {}

  for _, callback in ipairs(self.listeners[event_name] or {}) do
    if callback ~= callback_to_remove then
      table.insert(filtered, callback)
    end
  end

  self.listeners[event_name] = filtered
end

function EventEmitter:listener_count(event_name)
  return #(self.listeners[event_name] or {})
end
