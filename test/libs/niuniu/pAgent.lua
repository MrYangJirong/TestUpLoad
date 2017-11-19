local class = require('middleclass')
local pAgent = class('pAgent')

function pAgent:init(app, user)
  self.app = app
  self.user = user
  if not self:isBot() then
    self.onLogout = self.user:on('onLogout',function()
      self.desk:leave(self)
    end)
  end

  self.allFunction = {
    putMoney = function(dt)
      self:putMoneyLogic(dt)
    end,

    choosed = function(dt)
      self:choosedLogic(dt)
    end,

    overgame = function(dt)
      self:overgameLogic(dt)
    end,

    qiangZhuang = function(dt)
      self:qiangZhuangLogic(dt)
    end
  }
  self.money = 0
  self.wathcerMode = false

  self.dropLineTrustee = false
  self.isInMatch = false
end

function pAgent:bankerStart()
  if self.desk then
    self.desk:bankerStart(self)
  end
end

function pAgent:setOtherMode(path)
  local otherMode = require(path)
  for i, v in pairs(otherMode) do
    self[i] = v
  end
end

function pAgent:chatInGame(msg)
  if self.desk then
    self.desk:chatInGame(self:getUid(),msg)
  end
end

function pAgent:playVoice(msg)
  if self.desk then
    self.desk:playVoice(self:getUid(),msg)
  end
end

function pAgent:moneyChange(num)
  self.money = self.money + num
end

function pAgent:getMoney()
  return self.money
end

function pAgent:setPrepare(flag)
  self.isPrepare = flag
end

function pAgent:getPrepare()
  return self.isPrepare
end

function pAgent:isBot()
  return self.user:isBot()
end

function pAgent:setLeaved(flag)
  self.isLeaved = flag
end

function pAgent:getLeaved()
  return self.isLeaved
end

function pAgent:setTrusteeship(flag)
  self.isTrusteeship = flag
end

function pAgent:getTrusteeship()
  return self.isTrusteeship
end

function pAgent:prepareToPlay()
  if self.desk:isPlayer(self) then
    self:setPrepare(true)
    -- notify the desk somebody is prepare
    self.desk:prepare(self)
  end
end

function pAgent:finalize()
  if self.onLogout then self.onLogout:dispose() self.onLogout = nil end

  if self.user then
    if self:isBot() then
      self.user:setBusy(false)
    end
    self.isLeaved = nil
    self.hand = nil
    self.user:clearGames()          -- 数据库修改
    self.user = nil
  end
  self.desk = nil
end

function pAgent:setDesk(desk)
  self.desk = desk
end

function pAgent:getNickname()
  if self.user then
    return self.user.nickName
  end
end

function pAgent:getUid()
  return self.user.uid
end

function pAgent:publicMsg(msg)
  if msg.msgID == self.gName..".putMoney" then
    self.cacheMsg = msg
  elseif msg.msgID == self.gName..".chooseCard" then
    self.cacheMsg = msg
  elseif msg.msgID == self.gName..".qiangZhuang" then
    self.cacheMsg = msg
  elseif msg.msgID == "error" then
    dump(msg) -- luacheck: ignore dump
    return
  end
end

function pAgent:runRobitLogic(msg)
  self:generateRobotTime()
  if msg.msgID == self.gName..".putMoney" then
    self.msg = msg
    self:setState("putMoney")
  elseif msg.msgID == self.gName..".chooseCard" then
    self.msg = msg
    self:setState("choosed")
  elseif msg.msgID == self.gName..".qiangZhuang" then
    self.msg = msg
    self:setState("qiangZhuang")
  elseif msg.msgID == self.gName..".overgame" then
    self.msg = msg
    self:setState("overgame")
  end
end

function pAgent:runTrusteeshipLogic(msg, handleStatus, force)
  force = force or false
  if not self.dropLineTrustee and not force then
    return
  end

  local data = nil
  if handleStatus then
    data = self.desk:package(self:getUid())
  end

  -- 游戏消息
  local function handleMsg(msg)
    print("托管操作:", self:getNickname(), msg.msgID)

    local newMsg = {}
    for i,v in pairs(msg) do
      newMsg[i] = v
    end
    newMsg.waitTime = 1000
    self:runRobitLogic(newMsg)
    if msg.msgID ~= self.gName..".action" then
      self.user:sendMsg(newMsg)
    end
  end

  -- 游戏, 桌子状态
  local function handleStatusChange(data)
    local info = data.info
    local status = info.state
    local played = info.played
    local isPlaying = info.isPlaying
    self.delay = 0
    self.msg = {}
    self.msg.waitTime = 3000

    -- 游戏状态
    if isPlaying then
      print("托管操作:", self:getNickname(), status)
      if status == "QiangZhuang" and not self.hand:isQiang() then
        self:qiangZhuangLogic(10000)
      elseif status == "PutMoney" then
        self:putMoneyLogic(10000)
      elseif status == "Playing" and not self.hand:isChoosed() then
        self:choosedLogic(10000)
      end
    end
  end
  
  if msg then handleMsg(msg) end
  if data then handleStatusChange(data) end
  
end

-- 进入托管模式
function pAgent:startTrusteeship(data, msg, mode)
  mode = mode or ""
  self.dropLineTrustee = true
  self:runTrusteeshipLogic(nil, true)
  if mode == "request" then
    self.desk:onRequestTrusteeship(self:getUid())
  end
end

-- 退出托管模式
function pAgent:stopTrusteeship(mode)
  mode = mode or ""
  self.dropLineTrustee = false
  if mode == "request" then
    self.desk:onCancelTrusteeship(self:getUid())
  end
end
-- 当轮牌局中
function pAgent:isInMatch()
 return self.isInMatch
end

function pAgent:setInMatch(bool)
  self.isInMatch = bool
end
function pAgent:sendMsg(msg)
  self:publicMsg(msg)
  if self:isBot() then  -- 机器人
    self:runRobitLogic(msg)
  elseif (not self:getWatcher()) and self.dropLineTrustee then  -- 托管玩家
    self:runTrusteeshipLogic(msg)
  else
    self.user:sendMsg(msg)
  end
end

function pAgent:setWatcher(bWatcherMode)
  self.wathcerMode = bWatcherMode
end

function pAgent:getWatcher()
  return self.wathcerMode
end

function pAgent:setChairID(id)
  self.chairIdx = id
end

function pAgent:getChairID()
  return self.chairIdx
end

function pAgent:package(ex)
  local data = {}
  data.actor = {}
  data.actor.uid = self:getUid()
  data.actor.isLeaved = self.isLeaved
  data.actor.money = self.money
  data.actor.isPrepare = self.isPrepare
  data.actor.avatar = self.user.avatar
  data.actor.sex = self.user.sex
  data.actor.nickName = self.user.nickName
  data.actor.diamond = self.user.diamond
  data.actor.playerId = self.user.playerId
  if self.user.socketID then
    data.actor.ip = self.user.socketID.sockname.ip
  end
  data.actor.win = self.user.win
  data.actor.lose = self.user.lose
  data.actor.cacheMsg = self.cacheMsg
  data.actor.x = self.user.xpos
  data.actor.y = self.user.ypos
  data.actor.vip = self.user:getVIPLevel()
  data.chairIdx = self.chairIdx
  data.isInMatch = self.isInMatch 
  if self.hand then
    data.hand = self.hand:package(ex)
  end
  return data
end


function pAgent:reloadData()
  self.desk:onReloadData(self)
end

function pAgent:onRequestSitdown()
  self.desk:onRequestSitdown(self)
end

function pAgent:onOverAction(result)
  self.desk:overActon(self, result)
end

function pAgent:onQiang(number)
  self.desk:onQiang(self, number)
end

function pAgent:onOvergame()
  self.desk:overgame(self)
end

function pAgent:onLeaveRoom()
  self.desk:leave(self)
end

function pAgent:onPut(score)
  self.cacheMsg = nil
  self.desk:onPut(self, score)
end

function pAgent:onChoosed(cards)
  self.cacheMsg = nil
  self.desk:onChoosed(self, cards)
end

function pAgent:generateRobotTime()
  self.robotTime = math.random(1) * 1000
end

function pAgent:copy(hash)
  local new = {}
  for i, v in pairs(hash) do
    new[i] = v
  end
  return new
end

function pAgent:putMoneyLogic(dt)
  self.delay = self.delay + dt
  local delay = self.msg.waitTime or self.robotTime
  if self.delay > delay then
    self.msg = nil
    self:setState(nil)

    local base = self.desk.deskInfo.base
    local nextPut = 1
    if base == '1/2' then
      nextPut = 1
    elseif base == '2/4' then
      nextPut = 1
    elseif base == '4/8' then
      nextPut = 4
    elseif base == '5/10' then
      nextPut = 6
    elseif base == '1' then
      nextPut = 1
    elseif base == '2' then
      nextPut = 2
    elseif base == '4' then
      nextPut = 4
    elseif base == '5' then
      nextPut = 5
    elseif base == '10' then
      nextPut = 10
    end

    self:onPut(nextPut)
  end
end

function pAgent:choosedLogic(dt)
  self.delay = self.delay + dt
  local delay = self.msg.waitTime or self.robotTime
  if self.delay > delay then
    --local msg = self:copy(self.msg)
    self.msg = nil
    self:setState(nil)
    local niuniu = self.hand:findNiuniu(self.hand['#'])
    if niuniu then
      self:onChoosed(niuniu[1])
    else
      self:onChoosed({})
    end
  end
end

function pAgent:qiangZhuangLogic(dt)
  self.delay = self.delay + dt
  if self.delay > 1000 then
    self.msg = nil
    self:setState(nil)
    self:onQiang(0)
    --[[
    if self.hand.option.qzMax then
      self:onQiang(math.random(self.hand.option.qzMax))
    else
      self:onQiang(math.random(1))
    end
    ]]
  end
end

function pAgent:overgameLogic(dt)
  self.delay = self.delay + dt
  if self.delay > 1000 then
    self.msg = nil
    self:setState(nil)
    self:onOverAction(1)
  end
end

function pAgent:update(dt)
  local call = self.allFunction[self.state]
  if call then
    call(dt)
  end
end

function pAgent:setState(state)
  self.delay = 0
  self.state = state
end

return pAgent
