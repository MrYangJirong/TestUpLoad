local json = require('json')
require('loadrocks')

local server = require('./common/server')
local Emitter = require('core').Emitter

local remote_debug = false

if remote_debug then
  require('mobdebug').start()
end

local Master = Emitter:extend()

function Master:initialize(options)
  self.options = options
  self.all_gateservers = {}

  self:on('rgOnLogin',function(conn,msg)
    self:rgOnLogin(conn,msg)
  end)

  self:on('heartbeat',function(conn,msg)
    local rep = {
      msgID = 'heartbeatRep'
    }

    self:sendMsg2Client(conn,rep)
  end)

  self:on('getVerson',function(conn, msg)
    self:requiredClientVersion(conn, msg)
  end)
  self:on('getGateLst',function(conn,msg)
    self:getGateLst(conn,msg)
  end)
end

function Master:rgOnLogin(conn,msg)
  local gate = self.all_gateservers[conn]
  if not gate then
    gate = {}
    self.all_gateservers[conn] = gate
  end

	gate._peer = conn
	gate._ip = msg.ip
	gate._port = msg.port

	print('中心服务器注册成功' , msg.ip,msg.port)

  local rep = {
    msgID = 'rgSuccess'
  }

  self:sendMsg2Client(conn,rep)
end

function Master:getSuitableGateServr()
  for k,v in pairs(self.all_gateservers) do
    return v
  end
end

function Master:requiredClientVersion(conn)
  self:sendMsg2Client(conn, {
    msgID = 'version',
    version = '0.1.1', -- TODO: this version should read from somewhere..
    url = 'http://cdn.example.com/'
  })
end

function Master:getGateLst(conn, msg)
  print('call getGateLst')
	local entry = self:getSuitableGateServr()
  if entry then
    local rep = {
      ip = entry._ip,
      port = entry._port,
      msgID = "GetGtServer"
    }

    self:sendMsg2Client(conn, rep)
  end
end

function Master:sendMsg2Client(conn,msg)
  local package = json.encode(msg)
  server.send(self.server,conn,package)
end

function Master:start()
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

function Master:onNewConnect(conn)
end

function Master:onMessage(conn,msg)
  local package = json.decode(msg)

  if package and package.msgID then
    self:emit(package.msgID,conn,package)
  end
end

function Master:onDisconnect(conn)
  print('some client is disconnected')

  local gate = self.all_gateservers[conn]
	if gate then
		self.all_gateservers[conn] = nil
		print('中心服务器退出')
	end
end

local function parse(arg)
  local cli = require('cliargs')
  cli:set_name('master')
  cli:option('-p, --port=PORT', 'the port that the master server bind to', 28302)
  local args, err = cli:parse(arg)
  if err then
    print(err)
    os.exit(1)
  end
  for k, v in pairs(args) do print(k, v) end
  return args
end

local options = parse(require('arg'))
local master = Master:new(options)
master:start()

print("master server listening at port " .. options.port)
