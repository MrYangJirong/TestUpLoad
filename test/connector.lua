local json = require('json')
local Emitter = require('core').Emitter
require('loadrocks')

local client = require('./common/client')
local GateServer = require('./gate/gate_server')
local timer = require('timer')

require('functions')

local Gate = Emitter:extend()

function Gate:initialize(options)
  self.delay = 0
  self.options = options

  self.conn2Master = client.create(
    function(handle)
      self:onConnected(handle)
    end,

    function(handle,data)
      self:onMessage(handle,data)
    end,

    function(handle)
      self:onDisconnet(handle)
    end
  )

  self.conn2Game = client.create(
    function(handle)
      self:onConnected(handle)
    end,

    function(handle,data)
      self:onMessage(handle,data)
    end,

    function(handle)
      self:onDisconnet(handle)
    end
  )

  self:on('rgSuccess',function(msg)
    print('注册到master服务器成功')
  end)

  self:on('heartbeatRep',function()
  end)

  self:on('disconnect2Session',function(msg)
    self:disconnectPeer(msg)
  end)

  self.gateServer = GateServer:new(self, self.options)
end

function Gate:disconnectPeer(msg)
  self.gateServer:disconnectPeer(msg)
end

function Gate:start()
  -- connect 2 the master
  self:connect2Master()
  self:connecg2Game()
  self.gateServer:start()
end

local function splitServer(s)
  return s:match('(%d+%.%d+%.%d+%.%d+):(%d+)')
end

function Gate:connect2Master()
  client.connect(self.conn2Master, splitServer(self.options.master))
end

function Gate:connecg2Game()
  client.connect(self.conn2Game, splitServer(self.options.game))
end

function Gate:_registerOnMaster()
	local body = {
    msgID = "rgOnLogin",
  	ip = self.options.host,
  	port = self.options.port
  }

	self:sendMsg2Login(body);
end

function Gate:_registerOnGame()
  local body = {
    msgID = 'rgOnGame'
  }

  self:sendMsg2Game(body)
end

function Gate:sendMsg2Login(msg)
  local pacakge = json.encode(msg)
  client.send(self.conn2Master,pacakge)
end

function Gate:sendMsg2Game(msg)
  local pacakge = json.encode(msg)
  client.send(self.conn2Game,pacakge)
end

function Gate:onConnected(handle)
  if handle == self.conn2Master then
    print('连接到master服务器成功',os.date())
    self:_registerOnMaster()
  elseif handle == self.conn2Game then
    print('连接到game服务器成功',os.date())
    self.connected2Game = true
    self:_registerOnGame()
  end
end

function Gate:onMessage(handle,msg)
  local pacakge = json.decode(msg)

  if pacakge then
    if pacakge.msgID then
      self:emit(pacakge.msgID,pacakge)
    else
      if pacakge.content then
        self.gateServer:sendMsg2Client(pacakge)
      end
    end
  end
end

function Gate:onDisconnet(handle)
  if handle == self.conn2Master then
    print('与master服务器断开，尝试重连...')
    timer.setTimeout(5 * 1000,function()
      self:connect2Master()
    end)
  elseif handle == self.conn2Game then
    print('与game服务器断开，尝试重连...')
    self.connected2Game = false
    timer.setTimeout(5 * 1000,function()
      self:connecg2Game()
    end)

    self.gateServer:disconnectAllClient()
  end
end

function Gate:update()
  self.delay = self.delay + 30
  if self.delay > 30 * 1000 then
    self.delay = 0

    local msg = {
      msgID = 'heartbeat'
    }
    if self.conn2Master.isConnected then
      self:sendMsg2Login(msg)
    end

    if self.conn2Game.isConnected then
      self:sendMsg2Game(msg)
    end
  end
end

local function defaultPort(host, port)
  return (host:find(':')) and host or host..':'..port
end

local function parse(arg)
  for k, v in pairs(arg) do print(k, v) end

  local cli = require('cliargs')
  cli:set_name('gate')
  cli:option('-m, --master=HOST[:PORT]', 'the master server', '127.0.0.1:28302')
  cli:option('-g, --game=HOST[:PORT]', 'the the game server', '127.0.0.1:6789')
  cli:option('-h, --host=HOST', 'the the gate public ip', '118.31.64.212')
  cli:option('-p, --port=PORT', 'the the gate port', 1234)
  local args, err = cli:parse(arg)
  if err then
    print(err)
    os.exit(1)
  end

  for k, v in pairs(args) do print(k, v) end

  args.p, args.port = tonumber(args.p), tonumber(args.port)

  args.master = defaultPort(args.master, 28302)
  args.game = defaultPort(args.game, 6789)
  args.m, args.g = args.master, args.game

  return args
end

local function run(options)
  print(('run connector server: %s:%d'):format(options.host, options.port))
  local gate = Gate:new(options)
  gate:start()
  timer.setInterval(30, function ()
    gate:update()
  end)
end


local options = parse(require('arg'))

if not options.host then
  print('get ipaddress of eths...')
  local ips = require('ipaddress').get()
  options.host = ips[1] or '127.0.0.1'
end
run(options)
