local class = require('middleclass')
local pListen = class('pListen')

function pListen:listen(app)
  app:on(self.pre..'prepare',function(socketID,msg)
    self:prepareToPlay(socketID,msg)
  end)
  app:on(self.pre..'play',function(socketID,msg)
    self:play(socketID,msg)
  end)
  app:on(self.pre..'leaveRoom',function(socketID,msg)
    self:leaveRoom(socketID,msg)
  end)
  app:on(self.pre..'sitdown',function(socketID,msg)
    self:sitdown(socketID,msg)
  end)
  app:on(self.pre..'puts',function(socketID,msg)
    self:onPut(socketID,msg)
  end)
  app:on(self.pre..'choosed',function(socketID,msg)
    self:choosed(socketID,msg)
  end)
  app:on(self.pre..'overgame',function(socketID,msg)
    self:overgame(socketID,msg)
  end)
  app:on(self.pre..'overAction',function(socketID,msg)
    self:overAction(socketID,msg)
  end)
  app:on(self.pre..'cancelTrusteeship',function(socketID,msg)
    self:cancelTrusteeship(socketID,msg)
  end)

  app:on(self.pre..'bankerStart',function(socketID,msg)
    self:bankerStart(socketID,msg)
  end)

  app:on(self.pre..'qiang',function(socketID,msg)
    self:qiangZhuang(socketID,msg)
  end)

  app:on(self.pre..'requestSitdown',function(socketID,msg)    -- 请求坐下
    self:requestSitdown(socketID,msg)
  end)

  app:on(self.pre..'reloadData',function(socketID,msg)    -- 用户重连
    self:reloadData(socketID,msg)
  end)

  app:on(self.pre..'requestTrusteeship',function(socketID,msg)    -- 用户重连
    self:requestTrusteeship(socketID,msg)
  end)
end

function pListen:reloadData(socketID, msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:reloadData()
  end
end


function pListen:requestSitdown(socketID, msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onRequestSitdown()
  end
end

function pListen:qiangZhuang(socketID, msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onQiang(msg.number)
  end
end

function pListen:bankerStart(socketID)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:bankerStart()
  end
end

function pListen:cancelTrusteeship(socketID)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:setTrusteeship(false)
    user.agent:stopTrusteeship("request")
    local rep = {
      msgID = 'cancelTrusteeship',
    }
    user:sendMsg(rep)
  end
end

function pListen:overAction(socketID, msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onOverAction(msg.result)
  end
end

function pListen:overgame(socketID)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onOvergame()
  end
end

function pListen:choosed(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onChoosed(msg.cards)
  end
end

function pListen:onPut(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onPut(msg.score)
  end
end

function pListen:leaveRoom(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onLeaveRoom(msg)
  end
end
function pListen:play(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:onOutPoker(msg)
  end
end

function pListen:prepareToPlay(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:prepareToPlay(msg)
  end
end

function pListen:sitdown(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    self.app.gameMgr:sitdown(user,msg)
  end
end

function pListen:requestTrusteeship(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:startTrusteeship(user, msg, "request")
    local rep = {
      msgID = 'requestTrusteeship',
    }
    user:sendMsg(rep)
  end
end

return pListen
