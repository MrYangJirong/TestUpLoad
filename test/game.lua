local json = require('json')
local fs = require "fs"
local Emitter = require('core').Emitter
local timer = require('timer')
local helper = require('game.src.helper')
require('loadrocks')

local server = require('./common/server')
local remote_debug = false

if remote_debug then
  require('mobdebug').start()
end

local function doDebug()
  require('mobdebug').start()
end

require('functions')
if not fs.existsSync('logs') then
  fs.mkdirSync('logs')
end

--package.path = package.path .. ';src/?.lua;./src/logic/upPoker/?.lua'
local Application = require('./game/src/Application')
local Game = Emitter:extend()

function Game:initialize(args)
  self.args = args
  self.gates = {}

  self.app = Application(self,doDebug)
end

function Game:start()
  self.server = server.create(self.args.port,
    function(conn)
      self:onNewConnect(conn)
    end,

    function(conn,msg)
      xpcall(function(i)--luacheck:ignore
        self:onMessage(conn,msg)
      end, function(status)
        print(status)
        local errorMsg = debug.traceback()
        print(errorMsg)
        helper.writeLog(status..'\r'..errorMsg)
      end)
    end,

    function(conn)
      self:onDisconnect(conn)
    end
  ,'127.0.0.1')

  self.interval = timer.setInterval(30, function ()
    xpcall(function(i)--luacheck:ignore
      self:mainloop()
    end, function(status)
      print(status)
      local errorMsg = debug.traceback()
      print(errorMsg)
      helper.writeLog(status..'\r'..errorMsg)
    end)
  end)
end

function Game:onNewConnect(conn)--luacheck:ignore
end

function Game:_registerGate(conn)
    local entry = {
      conn = conn,
      all_playser = {}
    }

    self.gates[conn] = entry
    print('connector connected')
end

function Game:disconnectPeer(id)
  if not id then return end
  local session = id.session

  local msg = {
    msgID = 'disconnect2Session',
    session = session
  }

  local gate = id.gate
  local conn = gate.conn

  self:sendMsg2Gate(conn,msg)
end

function Game:_createPlayer(conn, msg)
  local gate = self.gates[conn]

  if gate then
    if msg.session then
      local sessionID = msg.session
      local id = {
        gate = gate,
        session = sessionID,
        sockname = msg.sockname
      }
      --new SessionID(it->second, sessionID)
      gate.all_playser[sessionID] = id
      self.app:onCreatePlayer(id)

      -- response create success
      local rep = {
        session = sessionID,
        content = {
          msgID = 'createPlayerSuccess'
        }
      }

      self:sendMsg2Gate(conn, rep)
    end
  end
end

function Game:sendMsg2Gate(conn,rep)
  server.send(self.server,conn,json.encode(rep))
end

function Game:sendMsg(session,msg)
  local gate = session.gate
  local conn = gate.conn

  local package = {
    content = msg,
    session = session.session
  }

  self:sendMsg2Gate(conn, package)
end

function Game:_delPlayer(conn, msg)
  local gate = self.gates[conn]
  if gate then
    if msg.session then
      local sessionID = msg.session
      local player = gate.all_playser[sessionID]
      if player then
          gate.all_playser[sessionID] = nil
          self.app:onDelPlayer(player)
      end
    end
  end
end

function Game:onMessage(conn,msg)
  local package = json.decode(msg)
  if package and package.msgID then
    if package.msgID == 'rgOnGame' then
      self:_registerGate(conn)
    elseif package.msgID == 'createPlayer' then
      self:_createPlayer(conn,package)
    elseif package.msgID == 'delPlayer' then
      self:_delPlayer(conn,package)
    elseif package.msgID == 'heartbeat' then
      local rep = {
        msgID = 'heartbeatRep'
      }

      self:sendMsg2Gate(conn,rep)
    else
      if package.session then
          local sessionID = package.session
          local id = self:getSessionID(sessionID, conn)
          if id then
              self.app:onMsg(id, package)
          end
      end
    end
  end
end

function Game:getSessionID(session, conn)
  local gate = self.gates[conn]
  if gate then
    local player = gate.all_playser[session]
    if player then
        return player
    end
  end
end

function Game:onDisconnect(conn)
  local gate = self.gates[conn]
  if gate then
    local all_playser = gate.all_playser

    for sessionID,player in pairs(all_playser) do
        gate.all_playser[sessionID] = nil
        self.app:onDelPlayer(player)
    end

    self.gates[conn] = nil
    print('connector disconnected')
  end
end

function Game:mainloop()
  self.app:mainLoop()
end


local function parse(arg)
  local cli = require('cliargs')
  cli:set_name('game')
  cli:option('--db=HOST[:PORT]', 'the mongo db server ip', '127.0.0.1:27017')
  cli:option('-p, --port=PORT', 'the port that the game server bind to', 6789)
  local args, err = cli:parse(arg)
  if err then
    print(err)
    os.exit(1)
  end
  for k, v in pairs(args) do print(k, v) end
  if not args.db:find(':%d+') then
    args.db = args.db ..':27017'
  end
  return args
end

local args = parse(require('arg'))
local game = Game:new(args)
game:start()
print('game start success and listen on ', args.port)
