local safety = {}

function safety.paramLose(t, msg)
  for _, v in ipairs(t) do
    if not msg[v] then
      print('msgID ', msg.msgID, 'lose param ', v)
      return true
    end
  end
  return false
end

return safety
