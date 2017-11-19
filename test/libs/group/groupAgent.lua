local class = require('middleclass')
local GroupStruct = require('./groupStruct.lua')
local GroupAgent = class('GroupAgent')

-- userInfo: GroupStruct.userInfo
function GroupAgent:initialize(app, group, user, userInfo)
    self.app = app
    self.user = user
    self.group = group
    self.userInfo = userInfo -- GroupStruct.userInfo
    self.onLogout = nil
    if user then
        self:bindUser(user)
    end
end

function GroupAgent:finalize()
    if self.onLogout then 
        self.onLogout:dispose() 
        self.onLogout = nil 
    end
    self.user = nil
    self.group = nil
    self.app = nil
end

-- return GroupStruct.userInfo
function GroupAgent:packageInfo()
    return GroupStruct.userInfo(
        self:getPlayerId(),
        self:getNickname(),
        self:getUid(),
        self:getAvatar()
    )
end

function GroupAgent:bindUser(user)
    self.user = user
    self.userInfo = GroupStruct.userInfo_user(user)
    if self.onLogout then
        self.onLogout:dispose() 
        self.onLogout = nil
    end
    self.onLogout = self.user:on('onLogout',function()
        self.userInfo = GroupStruct.userInfo_user(user)
        self.user = nil
    end)
end

function GroupAgent:getBindUser()
    return self.user
end

function GroupAgent:getNickname()
    if self.user then
        return self.user.nickName
    end
    return self.userInfo.nickname
end

function GroupAgent:getUid()
    if self.user then
        return self.user.uid
    end
    return self.userInfo.uid
end

function GroupAgent:getAvatar()
    if self.user then
        return self.user.avatar
    end
    return self.userInfo.avatar
end

function GroupAgent:getPlayerId()
    if self.user then
        return self.user.playerId
    end
    return self.userInfo.playerId
end

function GroupAgent:sendMsg(msg)
    if self.user then
        self.user:sendMsg(msg)
    end
end

return GroupAgent