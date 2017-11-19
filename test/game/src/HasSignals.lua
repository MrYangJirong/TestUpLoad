
local function Subscription(slots, callback)
  local this = {slots=slots, callback= callback}
  function this:dispose()
    self.slots[self.callback] = nil
  end
  return this
end

local function Emitter()
  local emitter = {}
  local subscribes = {}

  function emitter.on(signal, callback, once)
    assert(type(signal) == 'string')
    assert(type(callback) == 'function' or type(getmetatable(callback).__call) == 'function')
    local t = subscribes[signal]
    if not t then
      t = {}
      subscribes[signal] = t
    end

    t[callback] = once and true or false
    return Subscription(t, callback)
  end

  function emitter:emit(signal, ...)
    assert(self == emitter, 'Use emitter:emit() not emitter.emit()')
    local slots = subscribes[signal]
    if slots then
      for f, once in pairs(slots) do
        f(...)
        if once then
          slots[f] = nil
        end
      end
    end
  end

  return emitter
end

local Observable = {}

function Observable:on(event, callback)
  return self.emitter.on(event, callback)
end

function Observable:once(event, callback)
  return self.emitter.on(event, callback, true)
end

function Observable:initialize()
  self.emitter = Emitter()
end

return Observable
