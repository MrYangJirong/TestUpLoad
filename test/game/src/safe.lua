local function safe(callback)
  local helper = require('game.src.helper')

  local ret = function(...)
    xpcall(function(...)--luacheck:ignore
      callback(...)
    end, function(status)
      print(status)
      local errorMsg = debug.traceback()
      print(errorMsg)
      helper.writeLog(status..'\r'..errorMsg)
    end,...)
  end

  return ret
end


return safe
