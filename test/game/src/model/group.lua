require('../../../libs/functions.lua')
local safety = require('../classes/safety')
local class = require('middleclass')
local safe = require('game.src.safe')
local helper = require('game.src.helper')

local GroupStruct = require('../../../libs/group/groupStruct.lua')
local GroupAgent = require('../../../libs/group/groupAgent.lua')
local TimerInUpdate = require('../../../libs/timerInUpdate.lua')

local Group = class('Group')

function Group:initialize(app, info)
    self.app = app
    self.tabAgent = {}  -- k:playerId, v:groupAgent
    self.tabAdmin = {}  -- arr|v:playerId
    
    self.tabRoom = {}   --[[k:deskId | v:{ ownerPlayerId = int, playerCnt = int, rule = {}, ownerInfo = {}}
                           self:onNewDesk()     
                        ]]
    self.tabAdminMsg = {}   -- map|k:playerId, v:GroupStruct.adminMsg
    self.tabBlock = {}  -- arr|v:playerId

    self.owner = nil
    self.ownerInfo = nil
    self.name = ""
    self.id = 000000
    if info then
        self.name = info.name or ""
        self.id = info.id or 000000
    end


    -- timerinupdate
    self.uTimer = TimerInUpdate()

    -- 同步数据库
    self.uTimer:addTimer('synDataBase', {mode = 'repeat', time = 10 * 1000}, function()
        self:syn2Db()
    end)

    -- 绑定在线玩家
    self.uTimer:addTimer('bindOnlineUser', {mode = 'repeat', time = 1000}, function()
        self:bindOnlineUser()
    end)

    -- 解散桌子消息
    self.onDelDesk = self.app.groupMgr:on('onDelDesk', function(deskId)
        if deskId and self:isDeskInGroup(deskId) then
            local retMsg = {
                msgID = 'delDesk',
                deskId = deskId,
            }
            self:broadcastMsg(retMsg)
        end
    end)

end

function Group:onMsg(socketID, msg)
    local msgID = msg.msgID
    --  groups:
    --      publish
    if msgID == 'Group_requestJoin' then
        self:onJoinRequest(socketID, msg)
    end

    if msgID == 'Group_memberList' then
        self:onMemberList(socketID, msg)
    end

    --      member
    if msgID == 'Group_quit' then
        self:onSomebodyQuit(socketID, msg)
    end

    if msgID == 'Group_creatRoom' then
        self:onCreatDesk(socketID, msg)
    end

    if msgID == 'Group_joinRoom' then

    end

    if msgID == 'Group_roomList' then
        self:onRoomList(socketID, msg)
    end

    --      admin
    -- if msgID == 'Group_dismiss' then
    --     self:onDismiss(socketID,msg)
    -- end

    if msgID == 'Group_delUser' then
        self:onDelUser(socketID,msg)
    end

    if msgID == 'Group_updateInfo' then

    end

    if msgID == 'Group_acceptJoin' then
        self:onAcceptJoin(socketID, msg)
    end

    if msgID == 'Group_adminMsg' then
        self:onAdminMsg(socketID, msg)
    end

    if msgID == 'Group_resetBlock' then
        self:onResetBlock(socketID, msg)
    end

    if msgID == 'Group_modifyInfo' then
        self:onModifyInfo(socketID, msg)
    end

end

function Group:update(dt)
    self.uTimer:update(dt)
end

function Group:bindOnlineUser()
    for k,v in pairs(self.tabAgent) do
        if not v:getBindUser() then
            local playerId = v:getPlayerId()
            if playerId then
                local user = self.app:getUserByPlayerId(playerId)
                if user then
                    print("group:bindOnlineUser", self.id, user.playerId)
                    v:bindUser(user)
                end
            end
        end
    end
end

function Group:onCreat(user)
    self:addAgent(user)
    self:addAdmin(user.playerId)
    self:setOwner(user)
    self:syn2Db()
end

function Group:setOwner(user)
    self.owner = user.playerId
    self.ownerInfo = GroupStruct.userInfo_user(user)
end

function Group:addAdmin(playerId)
    self.tabAdmin[playerId] = playerId
end

function Group:getAgentCnt()
    return table.nums(self.tabAgent)
end

function Group:getAdminMsgCnt()
    return table.nums(self.tabAdminMsg)
end

function Group:getRoomCnt()
    return table.nums(self.tabRoom)
end

-- userInfo GroupStruct.userInfo
function Group:addAgent(user, userInfo)
    print('addAgent')
    local agent = nil
    if user then 
        agent = GroupAgent(self.app, self, user) 
    end
    if userInfo then
        agent = GroupAgent(self.app, self, nil, userInfo) 
    end
    self.tabAgent[agent:getPlayerId()] = agent
end

function Group:isUserInGroup(playerId)
    return self.tabAgent[playerId] and true or false
end

function Group:isDeskInGroup(deskId)
    return self.tabRoom[deskId] and true or false
end

function Group:packageInfo()
    return {
        name = self.name,
        id = self.id,
        roomCnt = self:getRoomCnt(),
        memberCnt = self:getAgentCnt(),
        msgCnt = 3,
        iconInfo = {},
        ownerInfo = self.ownerInfo,
        adminMsgCnt = self:getAdminMsgCnt(),
    }
end

function Group:packageRoomInfo()
    local retTab = {}
    for k, v in pairs(self.tabRoom) do
        local playerCnt = 0
        local desk = self.app.gameMgr:findDeskBy(k)
        if desk then
            playerCnt = desk:getChairCnt()
            self.tabRoom[k].playerCnt = playerCnt    
            retTab[k] = self.tabRoom[k]      
        end
    end
    return retTab
end

function Group:packageAdminMsg()
    return self.tabAdminMsg
end

function Group:packageMemberInfo()
    local userInfoList = {}
    for i,v in pairs(self.tabAgent) do
        local userInfo = GroupStruct.userInfo(
            v:getPlayerId(),
            v:getNickname(),
            v:getUid(),
            v:getAvatar()
        )
        userInfoList[userInfo.playerId] = userInfo
    end
    return userInfoList
end

function Group:initFromDb(groupId, callBack)
    print("Group:initFromDb groupId:", groupId)
    self.app.mongo:findOne("group", {groupId = groupId}, {}, nil, function(err, dbGroup)
        if err then 
            print("group initFromDb 查询数据库失败") 
            return
        end
        if not dbGroup then
            print("group initFromDb groupId无效") 
            return
        end
        self.id = dbGroup.groupId
        self.name = dbGroup.name
        self.ownerInfo = dbGroup.ownerInfo
        self.owner = dbGroup.ownerInfo.playerId
        
        for i, v in pairs(dbGroup.memberList) do
            self:addAgent(nil, v)
        end

        for i, v in pairs(dbGroup.adminList) do
            self:addAdmin(v.playerId)
        end
        if callBack then
            callBack(self.id, self)
        end
    end)
end

function Group:syn2Db()
    local memberList = {}
    local adminList = {}
    local ownerInfo = {}
    for i,v in pairs(self.tabAgent) do
        
        local userInfo = GroupStruct.userInfo(
            v:getPlayerId(),
            v:getNickname(),
            v:getUid(),
            v:getAvatar()
        )
        table.insert( memberList, userInfo)
        if self.tabAdmin[userInfo.playerId] then
            table.insert( adminList, userInfo)
        end
        if userInfo.playerId == self.owner then
            ownerInfo = userInfo
        end
    end
    if self.id ~= 000000 then
        self.app.mongo:update('group',
            {groupId=self.id}, 
            {['$set'] = {
                groupId = self.id,
                name = self.name,
                adminList = adminList,
                memberList = memberList,
                ownerInfo = ownerInfo,
            }},
            true,
            false, 
            function(_)end
        )
    end
end

function Group:broadcastMsg(msg)
    if not msg.groupId then
        msg.groupId = self.id
    end 
    for i,v in pairs(self.tabAgent) do
        v:sendMsg(msg)
    end
end

function Group:sendMsg2user(socketID, msg)
    local user = self.app.actives[socketID]
	if not user then return end
    if not msg.groupId then
        msg.groupId = self.id
    end
    user:sendMsg(msg)
end

function Group:broadcartGroupInfo()
    local msg = {
        msgID = 'groupInfo',
        data = self:packageInfo()
    }
    self:broadcastMsg(msg)
end

function Group:checkAdminRight(playerId)
    return self.tabAdmin[playerId]
end

function Group:checkMemberRight(playerId)
    return self.tabAgent[playerId]
end

function Group:onJoinRequest(socketID, msg)
    local user = self.app.actives[socketID]
	if not user then return end
    print('onJoinRequest', self.id, user.nickName)
    local code = 0
    local userInfo = GroupStruct.userInfo(
        user.playerId,
        user.nickName,
        user.uid,
        user.avatar
    )
    if self.tabBlock[user.playerId] then
        code = -1
    elseif self:isUserInGroup(user.playerId) then
        code = -2
    elseif self.tabAdminMsg[user.playerId] then
        code = -3
    else
        code = 1
        self.tabAdminMsg[user.playerId] = GroupStruct.adminMsg('joinRequest', userInfo)
        dump(self.tabAdminMsg)
    end
    local retMsg = {
        msgID = "joinRequestResult",
        code = code,
    }
    self:sendMsg2user(socketID, retMsg)
end

function Group:onAdminMsg(socketID, msg)
    print("onAdminMsg")
    local user = self.app.actives[socketID]
	if not user then return end
    if not self:checkAdminRight(user.playerId) then return end
        
    local msg = {
        msgID = "Group_adminMsgResult",
        data = self:packageAdminMsg()
    }
    self:sendMsg2user(socketID, msg)
end

function Group:onAcceptJoin(socketID, msg)
    print("onAcceptJoin")
    local user = self.app.actives[socketID]
	if not user then return end
    if not self:checkAdminRight(user.playerId) then return end

    -- 添加用户
    local operate = msg.operate
    local playerId = msg.playerId
    local msgData = self.tabAdminMsg[playerId]
    if msgData and msgData.userInfo then
        if operate == 'accept' then 
            self:addAgent(nil, msgData.userInfo) 
        end
        if operate == 'block' then 
            self.tabBlock[playerId] = playerId
        end
        self.tabAdminMsg[playerId] = nil
    end    
    
    local retMsg = {
        msgID = 'Group_acceptJoinResult',
        code = 1,
    }
    self:sendMsg2user(socketID, retMsg)
    self:onAdminMsg(socketID, retMsg)
end

function Group:onDelUser(socketID, msg)
    print("onDelUser")
    local user = self.app.actives[socketID]
	if not user then return end
    if not self:checkAdminRight(user.playerId) then return end

    -- 删除用户
    local playerId = msg.playerId
    local agent = self.tabAgent[playerId]
    if agent then
        agent:finalize()
        self.tabAgent[playerId] = nil
    end    
    self:onMemberList(socketID, msg)
end

function Group:onResetBlock(socketID, msg)
    print("onResetBlock")
    local user = self.app.actives[socketID]
	if not user then return end
    if not self:checkAdminRight(user.playerId) then return end
    self.tabBlock = {}
end

function Group:onMemberList(socketID, msg)
    print("onMemberList")
    local user = self.app.actives[socketID]
	if not user then return end
    -- if not self:checkAdminRight(user.playerId) then return end
    local retMsg = {
        msgID = 'memberList',
        data = self:packageMemberInfo()
    }
    self:sendMsg2user(socketID, retMsg)
end

function Group:onModifyInfo(socketID, msg)
    print("onModifyInfo")
    local user = self.app.actives[socketID]
	if not user then return end
    if not self:checkAdminRight(user.playerId) then return end
    if msg and msg.name and msg.name ~= "" then
        self.name = msg.name
    end
    local retMsg = {
        msgID = 'onModifyInfoResult',
        name = self.name
    }
    self:sendMsg2user(socketID, retMsg)
    self:broadcartGroupInfo()
end

function Group:onDismiss(socketID, msg)
    print("onDismiss", self.id)
    local user = self.app.actives[socketID]
    if not user then return end
    if not self:checkAdminRight(user.playerId) then return end
    local retMsg = {
        msgID = "groupDismiss",
        code = 1,
    }
    self:broadcastMsg(retMsg)
    self:finalize()
    return true
end

function Group:finalize()
    self.onDelDesk:dispose()
    self.uTimer:finalize()
    local tabAgent = self.tabAgent
    self.tabAgent = {}
    for k, v in pairs(tabAgent) do
        v:finalize()
    end
    -- 删除数据库
    self.app.mongo:remove('group', {groupId = self.id}, 0, function(err, _)
        print('remove group err is', err)
    end)
end

function Group:onSomebodyQuit(socketID, msg)
    print("onSomebodyQuit", self.id)
    local user = self.app.actives[socketID]
    if not user then return end
    if not self:checkMemberRight(user.playerId) then return end
    
    local playerId = user.playerId
    local agent = self.tabAgent[playerId]
    if agent then
        agent:finalize()
        self.tabAgent[playerId] = nil
    end 

    local retMsg = {
        msgID = "Group_quitResult",
        code = 1,
    }
    self:sendMsg2user(socketID, retMsg)
end

function Group:onCreatDesk(socketID, msg)
    print("Group:onCreatDesk", self.id)
    local user = self.app.actives[socketID]
    if not user then return end
    if not self:checkMemberRight(user.playerId) then return end

    if safety.paramLose({'options'}, msg) then return end
    local game = self.app.gameMgr:getGame(msg.gameIdx)
    if user and game then
        local resultCallBack =  function(roomInfo)
            print("     Group:onCreatDesk:resultCallBack", self.id)
            self:onNewDesk(roomInfo)
            local retMsg = {
                msgID = 'Group_creatRoomResult',
                code = 1,
            }
            self:sendMsg2user(socketID, retMsg)
        end
        game:createDesk(user, msg, resultCallBack)
    end
end

-- roomInfo StarGameServer\game\src\model\game.lua insert
function Group:onNewDesk(roomInfo)
    if not roomInfo then return end
    local deskId = roomInfo.deskId
    local ownerPlayerId = roomInfo.owner
    local option = roomInfo.options
    local playerCnt = 0

    if not self.tabRoom[deskId] then 
        self.tabRoom[deskId] = {}
    end
    
    local onwerAgent = self.tabAgent[ownerPlayerId]
    if not onwerAgent then return end

    local onwerInfo = onwerAgent:packageInfo()

    self.tabRoom[deskId] = {
        ownerPlayerId = ownerPlayerId,
        ownerInfo = onwerInfo,
        playerCnt = playerCnt,
        rule = option,
    }
    local retMsg = {
        msgID = "newDesk",
        deskId = deskId,
    }
    self:broadcastMsg(retMsg)
end

function Group:onRoomList(socketID, msg)
    print("Group:onRoomList", self.id)
    local user = self.app.actives[socketID]
    if not user then return end
    if not self:checkMemberRight(user.playerId) then return end

    local retMsg = {
        msgID = "groupRoomList",
        data = self:packageRoomInfo()
    }
    self:sendMsg2user(socketID, retMsg)
end

return Group