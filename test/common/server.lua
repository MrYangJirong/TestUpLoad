local uv = require('uv')
local mycodec = require('./mycodec')

local server = {}

function server.create(port,onNewConnect,onMessage,onDisconnet,bindIP)
  print('server create port is ',port)

  if not bindIP then
    bindIP = '0.0.0.0'
  end

  if not port then
    port = 5678
  end

  local ret = uv.new_tcp()
  local serverHandle = {
    socket = ret,
    onNewConnect = onNewConnect,
    onMessage = onMessage,
    onDisconnet = onDisconnet
  }

  ret:bind(bindIP, tonumber(port))
  ret:listen(128, function(err)
    local clientSocket = uv.new_tcp()
    local client = {
        socket = clientSocket,
        codec = mycodec.create()
    }

    ret:accept(client.socket)

    if onNewConnect then
      onNewConnect(client)
    end

    client.socket:keepalive(true, 0)
    client.socket:read_start(function(err, data)
      if err then
        print('read_start err ',err)
        if onDisconnet then
          onDisconnet(client)
        end

        client.socket:close()
        client.socket = nil
      else
        if data then
          mycodec.process(client.codec,data,function(msg)
            onMessage(client,msg)
          end,
          function()
            print('onDisconnet mycodec.process 11')
            onDisconnet(client)
          end)
        else
          print('onDisconnet mycodec.process 22', data)
          onDisconnet(client)

          client.socket:shutdown()
          client.socket:close()
          client.socket = nil
        end
      end
    end)
  end)

  return serverHandle
end

function server.disconnect(serverHandle,conn)
  conn.socket:shutdown()
  conn.socket:close()
  conn.socket = nil
end

function server.send(serverHandle,client,data)
  if not client.socket then return end

  local package = mycodec.createPackage(data)
  client.socket:write(package,function(err)
    if err then
      print('client.socket:write(package,function(err) 22')
      serverHandle.onDisconnet(client)
      if client and client.socket then
        print('close client.socket')
        if not uv.is_closing(client.socket) then
          client.socket:close()
        end
      else
        print('the motherfucker client.socket is fucking nil')
      end
    end
  end)
end

return server
