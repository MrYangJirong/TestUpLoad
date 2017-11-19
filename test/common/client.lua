local uv = require('uv')
local mycodec = require('./mycodec')

local client = {}

function client.create(onConnected,onMessage,onDisconnet)
  local ret = {
    socket = uv.new_tcp(),
    onConnected = onConnected,
    onMessage = onMessage,
    onDisconnet = onDisconnet,
    isConnected = false
  }

  return ret
end

function client.connect(handle,ip,port)
  handle.ip = ip
  handle.port = tonumber(port)

  if not handle.socket then
    handle.socket = uv.new_tcp()
  end

  uv.tcp_connect(handle.socket, ip, port,function(error)
    if error then
      client.destroy(handle)
    else
      handle.codec = mycodec.create()

      if handle.onConnected then
        handle.isConnected = true
        handle.onConnected(handle)
      end

      print('enable keepalive')
      uv.tcp_keepalive(handle.socket, true, 0)

      handle.socket:read_start(function (err, chunk)
        if err then
          client.destroy(handle)
        else
          if chunk then
            mycodec.process(handle.codec,chunk,function(msg)
              handle.onMessage(handle,msg)
            end,
            function()
              client.destroy(handle,true)
            end)
          else
            client.destroy(handle,true)
          end
        end
      end)
    end
  end)
end

function client.send(handle,data)
  if not handle.isConnected then
    return
  end

  local package = mycodec.createPackage(data)
  handle.socket:write(package,function(err)
    if err then
      client.destroy(handle)
    end
  end)
end

function client.destroy(handle,needShutdown)
  handle.isConnected = false

  if handle.socket then
    if not uv.is_closing(handle.socket) then
      if needShutdown then
        uv.shutdown(handle.socket)
      else
        uv.close(handle.socket)
      end
    end

    handle.socket = nil
  end

  handle.onDisconnet(handle)
end

function client.disconnect(handle)
  client.destroy(handle)
end

return client
