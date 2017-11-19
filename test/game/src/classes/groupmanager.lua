local class = require('middleclass')
local safe = require('game.src.safe')
local helper = require('game.src.helper')
local HasSignals = require('../HasSignals')

local Group = require('../model/group.lua')
local Groupmanager = class('Groupmanager'):include(HasSignals)

function Groupmanager:initialize(app)
	HasSignals.initialize(self)
	self.app = app
	self.tabGroup = {} -- 牛友群列表
	
	-- 在APP注册消息回调
	-- gameManager
	app.gameMgr:on('onDelDesk', function(deskId)
		print('Groupmanager onDelDesk', deskId)
		self.emitter:emit('onDelDesk', deskId)
	end)

	--  manager:
	app:on('GroupMgr_list', function(socketID, msg)
		self:listGroup(socketID, msg)
	end)
	
	app:on('GroupMgr_creat', function(socketID, msg)
		self:creatGroup(socketID, msg)
	end)

	app:on('GroupMgr_getGroup', function(socketID, msg)
		self:onGetGroup(socketID, msg)
	end)

	app:on('GroupMgr_dismiss', function(socketID, msg)
		self:onDismiss(socketID, msg)
	end)

	--  groups:
	-- 		publish
	app:on('Group_requestJoin', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	app:on('Group_memberList', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	--      member
	app:on('Group_quit', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)
	
	app:on('Group_creatRoom', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)
	
	app:on('Group_joinRoom', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	app:on('Group_roomList', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)
	
	--      admin
	app:on('Group_delUser', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)
	
	app:on('Group_updateInfo', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)
	
	app:on('Group_acceptJoin', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	app:on('Group_adminMsg', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	app:on('Group_resetBlock', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

	app:on('Group_modifyInfo', function(socketID, msg)
		self:sendMsg2Group(socketID, msg)
	end)

end

function Groupmanager:initGroupFromDb()
	print("Groupmanager:initGroupFromDb")
	self.app.mongo:find("group", {}, {groupId = 1}, nil, nil, function(err, dbGroups)
		if err then 
            print("Groupmanager initGroupFromDb 查询数据库失败") 
            return
        end
        if not dbGroups then
            print("Groupmanager initGroupFromDb 没有牛友群") 
            return
        end
		if type(dbGroups) == "table" and #dbGroups > 0 then
			for k, v in pairs(dbGroups) do
				local id = v.groupId
				print("		init group", id)
				local group = Group(self.app)
				local function callBack(id, group)
					self:addGroup(id, group)
				end
				group:initFromDb(id, callBack)
			end
		end
	end)
end

function Groupmanager:update(dt)
	for key, v in pairs(self.tabGroup) do
		v:update(dt)
	end
end

function Groupmanager:sendMsg2User(socketID, msg)
    local user = self.app.actives[socketID]
	if not user then return end
    user:sendMsg(msg)
end

function Groupmanager:sendMsg2Group(socketID, msg)
	local group
	if msg and msg.groupId then
		group = self.tabGroup[msg.groupId]
	end
	if group then
		group:onMsg(socketID, msg)
	else
		self:sendMsg2User(socketID, {msgID = 'groupErr', err = '牛游群已经被解散'})
	end
end

function Groupmanager:listGroup(socketID, msg)
	local user = self.app.actives[socketID]
	if not user then return end
	
	local retList = {}
	for key, v in pairs(self.tabGroup) do
		if v:isUserInGroup(user.playerId) then
			table.insert(retList, v:packageInfo())
		end
	end
    
    self:sendMsg2User(socketID, {
        msgID = "listGroup", 
        list = #retList > 0 and retList or false,
    })
end

function Groupmanager:creatGroup(socketID, msg)
	local user = self.app.actives[socketID]
	if not user then return end
	
	local name = msg.name
	math.newrandomseed()
	local groupId = math.random(100000, 999999)
	for tryCnt = 1, 9999 do
		if not self.tabGroup[groupId] then
			local group = Group(self.app, {name = name, id = groupId})
			group:onCreat(user)
			self:addGroup(groupId, group)
			print("创建牛友群|groupId:", groupId, "尝试次数:", tryCnt, "创建人:", user.nickname)
			self:listGroup(socketID, msg)
			self:sendMsg2User(socketID, {
				msgID = "GroupMgr_creatResult", 
				code = 1,
			})
            break
		end
	end
end

function Groupmanager:onGetGroup(socketID, msg)
	local user = self.app.actives[socketID]
	if not user then return end

	local groupInfo = nil
	local code = 0
	local groupId = msg.groupId
	if groupId and self.tabGroup[groupId] then
		groupInfo = self.tabGroup[groupId]:packageInfo()
		code = 1
	end

	local retMsg = {
		msgID = 'GroupMgr_getGroupResult',
		groupInfo = groupInfo,
		code = code,
		mode = msg.mode,
	}
	print("Groupmanager:onGetGroup", retMsg.code, user.playerId, user.nickName)
	self:sendMsg2User(socketID, retMsg)
end

function Groupmanager:onDismiss(socketID, msg)
	local user = self.app.actives[socketID]
	if not user then return end

	local code = 0

	local groupId = msg.groupId
	if groupId and self.tabGroup[groupId] then
		if self.tabGroup[groupId]:onDismiss(socketID, msg) then
			self.tabGroup[groupId] = nil
			code = 1
		end
	end

	local retMsg = {
		msgID = 'GroupMgr_dismissResult',
		groupId = groupId,
		code = code,
	}
	self:sendMsg2User(socketID, retMsg)
end

function Groupmanager:addGroup(groupId, group)
	self.tabGroup[groupId] = group
end


function Groupmanager:canEnterGroupRoom(deskId, playerId)
	for k, v in pairs(self.tabGroup) do
		if v:isDeskInGroup(deskId) then
			if v:checkMemberRight(playerId) then
				return 1
			else
				return 2
			end
		end
	end
	return -1 -- 普通房间
end


return Groupmanager 