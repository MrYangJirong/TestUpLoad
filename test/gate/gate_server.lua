local Emitter = require('core').Emitter
local json = require('json')
local Mongo = require('luvit-mongodb')
local server = require('../common/server')
local ObjectId = Mongo.ObjectId

local GateServer = Emitter:extend()

function GateServer:initialize(gate, options)
  self.gate, self.options = gate, options

  self._all_sessions = {}
  self._all_sessions_by_name = {}
end

function GateServer:start()
  self.server = server.create(self.options.port,
    function(conn)
      self:onNewConnect(conn)
    end,

    function(conn,msg)
      self:onMessage(conn,msg)
    end,

    function(conn)
      self:onDisconnect(conn)
    end
  )
end

function GateServer:getSessionBySocket(conn)
  return self._all_sessions[conn]
end

function GateServer:getSessionBySessionId(id)
  return self._all_sessions_by_name[id]
end

function GateServer:onNewConnect(conn)
end

function GateServer:onMessage(conn,msg)
  local pacakge = json.decode(msg)
  if pacakge and pacakge.msgID then
    if pacakge.msgID == 'loginOnGate' then
      if self.gate.connected2Game then
        self:_createSession(conn)
      else
        local rep = {
          msgID = 'waitForRetry'
        }

        self:sendMsg2ClientByConn(conn,rep)
      end
    else
      self:_default2Game(conn, pacakge)
    end
  end
end

function GateServer:_default2Game(conn, pacakge)
  local session = self:getSessionBySocket(conn)
  if session then
      -- append the session id
      pacakge.session = session.id
      self:sendMsg2Game(pacakge)
  end
end

function GateServer:disconnectAllClient()
  for k,_ in pairs(self._all_sessions) do
    server.disconnect(self.server,k)
  end

  self._all_sessions = {}
  self._all_sessions_by_name = {}
end

function GateServer:_createSession(conn)
  print('_createSession',os.date())
  local oid = ObjectId.new()
  local id = tostring(oid)
  local s = {
    id = id,
    conn = conn
  }

  self._all_sessions[conn] = s
  self._all_sessions_by_name[id] = s

  -- send msg 2 game
  local body = {
    msgID = "createPlayer",
    session = id,
    sockname = conn.socket:getpeername()
  }
  self.gate:sendMsg2Game(body)
end

function GateServer:sendMsg2Game(msg)
  self.gate:sendMsg2Game(msg)
end

function GateServer:onDisconnect(conn)
  local session = self:getSessionBySocket(conn)
  if session then
      local body = {
        msgID = "delPlayer",
        session = session.id
      }

      self:sendMsg2Game(body)
      -- erase from name map
      self:eraseFromSessionFromNameMap(session.id)
      self:eraseFromSessionFromSessions(conn)
  end
end

function GateServer:eraseFromSessionFromNameMap(id)
  self._all_sessions_by_name[id] = nil
end

function GateServer:eraseFromSessionFromSessions(conn)
  self._all_sessions[conn] = nil
end

function GateServer:disconnectPeer(msg)
  local sessionId = msg.session
  if sessionId then
    local session = self:getSessionBySessionId(sessionId)
    if session then
      server.disconnect(self.server,session.conn)
      self:eraseFromSessionFromSessions(session.conn)
    end

    self:eraseFromSessionFromNameMap(sessionId)
  end
end

function GateServer:sendMsg2ClientByConn(conn,content)
  server.send(self.server,conn,json.encode(content))
end

function GateServer:sendMsg2Client(msg)
  local sessionId = msg.session
  local content = msg.content
  if sessionId and content then
    local user = self:getSessionBySessionId(sessionId)
    if user then
      self:sendMsg2ClientByConn(user.conn,content)
      --server.send(self.server,user.conn,json.encode(content))
    end
  end
end

return GateServer
