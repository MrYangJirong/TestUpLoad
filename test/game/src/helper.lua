local helper = {}

function helper.writeLog(error)
	local time = os.time()
	local tb = os.date('*t',time)
	local filename = tb.year..'-'..tb.month..'-'..tb.day..'-'..tb.hour..'-'..tb.min

  local fd = io.open ('logs/'..filename,'w')
  fd:write(error)
  fd:close()
end

function helper.complete(param, msg)
  for _, v in ipairs(param) do
    if not msg[v] then
      print('msgID ', msg.msgID, 'lose param ', v)
      return false
    end
  end
  return true
end

return helper
