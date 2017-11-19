local class = require('middleclass')
local HasSignals = require('./HasSignals')
local Application = class('Application'):include(HasSignals)
local http = require('http')
local url = require('url')
local json = require('json')
local robotName = require('./model/robotName')
local Mongo = require('luvit-mongodb')
local Login = require('./classes/login')
local RobotMng = require('./model/robotMng')
local GameManager = require('./model/gamemanager')
local Users = require('./classes/users')
local Social = require('./classes/social')
local safe = require('game.src.safe')
local GroupManager = require('./classes/groupmanager.lua')

_G.debug.traceback = require('StackTracePlus').stacktrace

function Application:initialize(net,debugcall)
	HasSignals.initialize(self)
	self.users = {}
	self.net = net
	self.debugcall = debugcall

	self.actives = {}	-- k:socket v:user
	self.activesPlayerId = {} -- k:playerId v:{socketId = socketId, user = usser}

	self.robotMng = RobotMng(self)
	self.social = Social(self)
	self.login = Login(self)
	self.usersModule = Users(self)

	self.gameMgr = GameManager(self)
	self.groupMgr = GroupManager(self)

  local host, port = net.args.db:match('(%d+%.%d+%.%d+%.%d+):(%d+)')
	self.mongo = Mongo:new({host = host, port=tonumber(port), db = "majiang"})
	self.mongo:on("connect", function()
		print('connect 2 the db success')
		--self.leaderboard:initDataFromDB()
		self:loadRealtimeNotify()

		self.mongo:update('user',{}, {['$set'] = {online = false}},false,false, function()
		end)
		self.gameMgr:initDataFromDB()
		self.groupMgr:initGroupFromDb()
	end)


	-- reconnect 2 the db
	self.mongo:on('error',function()
		self.mongo:connect()
	end)

	self.mongo:on('close',function()
		self.mongo:connect()
	end)

	self:startWebServer()
	self.delay_cheat = 40 * 1000
end

function Application:processWebQequest(req,res)
	if req.method == 'GET' then
		local data = url.parse(req.url)
		local query = data.query

		if data and query then
			xpcall(function()
        self.emitter:emit(data.pathname,query)
      end, function(status)
        print(status)
        print(debug.traceback())
      end)
		end
	elseif req.method == 'POST' then
		local data = url.parse(req.url)
		local chunks = ''
		req:on('data', function (chunk)
		chunks = chunks..chunk
		end)
		req:on('end', function ()
		print('POST chunks is ',chunks)
			self.emitter:emit(data.pathname,chunks)
			local body = '1' -- 1 成功 0 失败
			res:setHeader("Content-Type", "text/plain")
			res:setHeader("Content-Length", #body)
			res:finish(body)
		end)
	end

	if req.method == 'GET' then
		local body
		if self.webresult then
			body = self.webresult..''
		else
			body = "complete"
		end

		self.webresult = nil

	  res:setHeader("Content-Type", "text/plain")
	  res:setHeader("Content-Length", #body)
	  res:finish(body)
	end
end

function Application:startWebServer()
	http.createServer(function (req, res)
		self:processWebQequest(req,res)
	end):listen(9999, '127.0.0.1')

	print('start the web server at ',9999)

	self:on('/mail',function(query)
		self:mailWebMsg(query)
	end)

	self:on('/newmatch',function(query)
		self:freshCompetition(query)
	end)

	self:on('/onlinetotal',function(query)
		self:getOnlineTotalCnt(query)
	end)

	self:on('/onNotify',function(query)
		self:broadcastNotify(query)
	end)

	self:on('/wechatnotify',function(query)
		self:processWechatnotifyCallback(query)
	end)

	self:on('/stopNotify',function()
		self:stopNotify()
	end)

	self:on('/unbind',function(query)
		self:unbindPlayerInvite(query)
	end)

	self:on('/onqiyuanshop',function(data)
		self:onQiYuanShop(data)
	end)

	self:on('/buyDiamond',function(data)
		self:buyDiamond(data)
	end)

end

function Application:buyDiamond(data)
	print("buyDiamond<===========")
	local result = json.decode(data)
	dump(result)

	-- 微信充值
	local function weixinCharge()
		local function recordCharge(result, invite)
			invite = invite or -1
			local setData = {
				playerId = result.playerId,
				diamond = result.diamond,
				song = result.song,
				orderId = result.orderId,
				invite = invite,
				type = result.type,
			}
			self.mongo:insert('gameChargeRecord', setData, nil, function() end)
		end

		repeat
			if not result then break end
			if not result.playerId then break end
			if not result.diamond then break end
			if not result.orderId then break end
			if not result.song then break end
			if not result.code then break end
			if result.code ~= "fu81hfeniyun81" then break end
			
			local active = false

			-- 用户在线
			for _,v in pairs(self.users) do
				if tonumber(v.playerId) == tonumber(result.playerId) then
					active = true
					print("		用户在线: ",result.playerId, "充值: ",result.diamond)
					local chargeVal = tonumber(result.diamond)
					if v.invite and result.song then
						print("		有邀请码: ", v.invite)
						chargeVal = chargeVal + tonumber(result.song)
					end
					print("		实际充值: ", chargeVal)
					v:updateRes("diamond", chargeVal)
					v:chargeResult(result, v.invite)
					recordCharge(result, v.invite)
					break
				end
			end

			-- 用户离线
			if not active then
				print("		用户离线: ",result.playerId, "充值: ",result.diamond)
				-- 用离线直接写数据库
				self.mongo:findOne("user", {playerId = tonumber(result.playerId)},{}, nil, function(err, dbuser)
					if not err then
						if not dbuser then
							print("没有找到对应玩家")
						else
							local chargeVal = tonumber(result.diamond)
							if dbuser.invite and result.song then
								print("		有邀请码: ", dbuser.invite)
								chargeVal = chargeVal + result.song
							end
							print("		实际充值: ", chargeVal)
							self.mongo:update('user', {playerId = tonumber(result.playerId)}, {['$inc'] = {diamond = chargeVal}}, nil, true, function() end)
							recordCharge(result, dbuser.invite)
						end
					end
				end)
			end
			return
		until true
		print("微信充值 - 数据异常")
	end
	
	-- 后台充值
	local function backServerCharge()
		local function recordCharge(result, invite)
			invite = invite or -1
			local setData = {
				playerId = tonumber(result.playerId),
				diamond = tonumber(result.diamond),
				agent = result.agentNum,
				type = result.type,
			}
			self.mongo:insert('webChargeRecord', setData, nil, function() end)
		end
		repeat
			if not result then break end
			if not result.playerId then break end
			if not result.diamond then break end
			if not result.agentNum then break end
			if not result.code then break end
			if result.code ~= "fu81hfeniyun81" then break end
			-- 用户在线
			local active = false
			for _,v in pairs(self.users) do
				if tonumber(v.playerId) == tonumber(result.playerId) then
					active = true
					print("		用户在线: ",result.playerId, "充值: ",result.diamond)
					v:updateRes("diamond", tonumber(result.diamond))
					recordCharge(result)
					break
				end
			end
			-- 用户离线
			if not active then
				print("		用户离线: ",result.playerId, "充值: ",result.diamond)
				-- 用离线直接写数据库
				self.mongo:findOne("user", {playerId = tonumber(result.playerId)},{}, nil, function(err, dbuser)
					if not err then
						if not dbuser then
							print("没有找到对应玩家")
						else
							local chargeVal = tonumber(result.diamond)
							self.mongo:update('user', {playerId = tonumber(result.playerId)}, {['$inc'] = {diamond = chargeVal}}, nil, true, function() end)
							recordCharge(result)
						end
					end
				end)
			end
			print("后台充值 - 数据异常")
		until true
	end

	if result.type == "houtai" then
		backServerCharge()
	elseif result.type == "weixin" then
		weixinCharge()
	end
end

function Application:getOnlineTotalCnt()
	print('call function Application:getOnlineTotalCnt()')
	local total = 0
	for _,_ in pairs(self.actives) do
		total = total + 1
	end

	self.webresult = total
	print('self.webresult ',self.webresult)
end

function Application:noitfy(msg)
	for _,v in pairs(self.actives) do
		v:sendMsg(msg)
	end
end

function Application:broadcastWebMsg(query)
	local result = json.decode(query)

	local msg = {
		msgID = 'broadcast',
		content = result.content
	}
	for _,v in pairs(self.actives) do
		v:sendMsg(msg)
	end
end

function Application:onQiYuanShop(data)

end

function Application:processWechatnotifyCallback(query)
	dump(query)
	local xml = require('xml')
	query = xml.load(query)
	dump(query)

	if query then
		local out_trade_no

		for i = 1,#query do
			if query[i].xml == 'out_trade_no' then
				out_trade_no = query[i][1]
				break
			end
		end

		if out_trade_no then
			print('find out_trade_no is ',out_trade_no)

			self.mongo:findOne('wechatorder', {order = Mongo.ObjectId.new(out_trade_no)},nil, nil, safe(function(err, dbOrder)
				print('err, dbOrder is ',err, dbOrder)
				if not err then
					if dbOrder then
						local uid = dbOrder.uid
						if uid then
							local user = self.users[uid]
							if user then
								print('call wechatPaySuccess')
								user:wechatPaySuccess(dbOrder)
							end
						end
					end
				end
			end))
		end
	end
end

function Application:unbindPlayerInvite(query)
	local result = json.decode(query)
	dump(result)
	if result and result.playerId then
		self.mongo:update('user',{playerId=tonumber(result.playerId)}, {['$unset'] = {invite = ""}},nil,true, function(err)
			if not err then
				for _,v in pairs(self.users) do
					if tonumber(v.playerId) == tonumber(result.playerId) then
						v.invite = nil
						break
					end
				end
			end
		end)
	end
end

function Application:stopNotify()
	local notify = {
		msgID = 'stopnotify',
	}
	self:noitfy(notify)

	local mongo = self.mongo
	mongo:remove('rtnotify', {
		rtnotify = true
	},false)
end

function Application:broadcastNotify(query)
	local result = json.decode(query)

	local notify = {
		msgID = 'notify',
		title = result.title,
		content = result.content
	}
	self:noitfy(notify)

	local op = {
		title = result.title,
		content = result.content,
		rtnotify = true
	}

	local mongo = self.mongo
	mongo:update('rtnotify', {
		rtnotify = true
	},op, true,true)

	self.rtnotify = op
end

function Application:loadRealtimeNotify()
	local mongo = self.mongo
	mongo:findOne("rtnotify", {
		rtnotify = true
	},nil, nil, safe(function(err, notify)
		if not err then
			if notify then
				self.rtnotify = notify
				dump(self.rtnotify)
			end
		end
	end))
end

function Application:mailWebMsg(query)
	local result = json.decode(query)

	local mongo = self.mongo

	local mail = {
		title = result.title,
		content = result.content,
		bean = tonumber(result.bean),
		diamond = tonumber(result.diamond),
		oid = mongo.ObjectId.new()
	}

	local isAll = result.nickName[1] == 'all'
	if isAll then
		print('isAll push all')
		mongo:update('user',{}, {['$push'] = {mails = mail}},false,false, function()
	  end)
	end

	for k,v in pairs(self.users) do
		print('uid is ',k)

		for i = 1,#result.nickName do
			if isAll or v.nickName == result.nickName[i] then
				if not isAll then
					table.remove(result.nickName,i)
				end

				local dontDB = isAll
				v.mail:send(mail,dontDB)
				break
			end
		end
	end

	if not isAll then
		for i = 1,#result.nickName do
			mongo:update('user',{nickName=result.nickName[i]}, {['$push'] = {mails = mail}},nil,true, function()
			end)
		end
	end
end

local all_pay_gems = {
  50,100,200,500,1000,2000,5000
}

function Application:cheatNotify()
	if not self.delayForCheat then
		self.delayForCheat = 0
	end

	self.delayForCheat = self.delayForCheat + 30
	if self.delayForCheat < self.delay_cheat then
		return
	end
	self.delayForCheat = 0
	self.delay_cheat = math.random(20,60) * 1000


	local firstName = robotName.firstName[math.random(#robotName.firstName)]
	local lastName = robotName.lastName[math.random(#robotName.lastName)]
	local name = firstName..lastName

	firstName = robotName.firstName[math.random(#robotName.firstName)]
	lastName = robotName.lastName[math.random(#robotName.lastName)]
	local second = firstName..lastName

	local all_cheat_function = {
		function()
			local rep = {
				msgID = 'notify',
				data = {
					{
						text = '土豪',
						color = {255,255,255}
					},
					{
						text = name,
						color = {0xFF,0xA5,0x00}
					},
					{
						text = '充值了',
						color = {255,255,255}
					},
					{
						text = all_pay_gems[math.random(#all_pay_gems)],
						color = {0xFF,0xA5,0x00}
					},
					{
						text = '钻石，小伙伴们快点找他做朋友吧！',
						color = {255,255,255}
					}
				}
			}

			self:noitfy(rep)
		end,

		function()
			local rep = {
	      msgID = 'notify',
	      data = {
	        {
	          text = name,
	          color = {0xFF,0xA5,0x00}
	        },
	        {
	          text = '与',
	          color = {255,255,255}
	        },
	        {
	          text = second,
	          color = {0xFF,0xA5,0x00}
	        },
	        {
	          text = '的配合简直天衣无缝，将对手打成负分，连升',
	          color = {255,255,255}
	        },
	        {
	          text = 4,
	          color = {0xFF,0xA5,0x00}
	        },
	        {
	          text = '级',
	          color = {255,255,255}
	        },
	      }
	    }

	    self:noitfy(rep)
		end
	}

	all_cheat_function[math.random(#all_cheat_function)]()
end

function Application:clearTimeOut()
	if not self.delayForClear then
		self.delayForClear = 0
	end
	self.delayForClear = self.delayForClear + 30
	if self.delayForClear > 6400 * 1000 then
		self.delayForClear = 0
		local ntime = os.time() - 1296000

		self.mongo:remove("records", {time = {["$lt"] = ntime}},0, function(err, _)
			print('remove records err is', err)
	  end)
	end
end

function Application:mainLoop()
	--local curTick = net.timeGetTime()
	--local dt = curTick - self.lstTick
	self:clearTimeOut()
	--self:cheatNotify(30)
	self.gameMgr:update(30)
	self.groupMgr:update(30)
end

function Application:onCreatePlayer(socketID)-- luacheck: ignore
end

function Application:disconnectPeer(socketID)
	if not socketID then return end
	self.net:disconnectPeer(socketID)
end

function Application:addActives(socketID, user)
	self.actives[socketID] = user
	if user and user.playerId then
		self.activesPlayerId[user.playerId] = {socketID = socketID, user = user}
	end
end

function Application:delActives(socketID)
	local user = self.actives[socketID]
	if user then
		if user.playerId then
			self.activesPlayerId[user.playerId] = nil
		end
	end
	self.actives[socketID] = nil
end

function Application:getUser(socketID)
	return self.actives[socketID]
end

function Application:getUserByPlayerId(playerId)
	if self.activesPlayerId[playerId] and self.activesPlayerId[playerId].user then
		return self.activesPlayerId[playerId].user
	end
end

function Application:onDelPlayer(socketID)
	local user = self.actives[socketID]
	if user then
		user.socketID = nil

		if user.onDelete then
			user:onDelete()
		end
	end

	-- self.actives[socketID] = nil
	self:delActives(socketID)
end

function Application:onMsg(socketID,msg)
	local msgID = msg.msgID
	if msgID == 'debug' then
		self.debugcall()
	else
		self.emitter:emit(msgID,socketID,msg)
	end
end

function Application:sendMsg(socketID,msg)
	self.net:sendMsg(socketID,msg)
end

function Application.writeLog(error)
	local time = os.time()
	local tb = os.date('*t',time)
	local filename = tb.year..'-'..tb.month..'-'..tb.day..'-'..tb.hour..'-'..tb.min
	local fs = require('fs')
	local fd = fs.openSync('logs/'..filename,'w')
	fs.writeSync(fd,0,error)
	fs.close(fd)
end

return Application
