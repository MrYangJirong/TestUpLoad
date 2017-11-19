local class = require('middleclass')
local pDesk = class('pDesk')
local array = require('array')
local table = require('table.addons')

function pDesk:delayAction(func, time)
  if (not func) then print("not rcall func!!") end
  if not time or type(time) ~= 'number' then
    time = 1
  end
  self.delayCall = func
  self.delayTime = time
  self:setState('delayState')
end

function pDesk:bankerStart(agent)
  if agent and agent:getUid() == self.ownerUid then
    if not self.play and self:getChairCnt() >= 2 and self:isAllPrepare() then
      self:gameStart(self.nextBanker)
    end
  end
end


-- 询问房主开始游戏
function pDesk:requestOwnerStart()
  local oUid = self.ownerUid
  local oAgent = nil

  repeat
    _, oAgent = self:getWatcher(oUid)
    if oAgent then break end
    _, oAgent = self:isUserExist(oUid)
  until true
  if oAgent then
    print("询问房主开始游戏", oAgent:getNickname(), self.deskId)
    oAgent:sendMsg({msgID = self.gName..'.canStart', b = true})
  end
end

function pDesk:canStartGame()
  if (not self.play) and
    self:isAllPrepare() and
    self:getChairCnt() >= 2
  then
    return true
  end
  return false
end


function pDesk:prepare(agent)
  if self.play then
    return
  end
  self:sendPrepareMsg(agent)
  if self:canStartGame() then
    if not self.played then
      -- 第一盘 房主开始游戏
      -- self.allChairs[1].agent:sendMsg({msgID = self.gName..'.canStart', b = true})
      self:requestOwnerStart()
      self:sendMsg({
        msgID = self.gName..'.waitOwnerStart',
        ownerInfo = 
          {
            uid = self.ownerUid,
            playerId = self.owner,
            nickname = self.ownerName
          }
      })

    else
      -- 之后单局 全员准备开始
      print('all is prepare', self:isAllPrepare())
      self:gameStart(self.nextBanker)
    end
  else
    local agent = self.allChairs[1].agent
    if agent then
      agent:sendMsg({msgID = self.gName..'.canStart', b = false})
    end
  end
end

function pDesk:resetRoomInfo()
end

function pDesk:doDelayLogic(dt)
  self.delay = self.delay + dt
  if self.delay >= self.delayTime * 1000 then
    self:setState('delayOver')
    if self.delayCall then
      self.delayCall()
    end
  end
end

function pDesk:setOtherMode(path)
  local otherMode = require(path)
  for i, v in pairs(otherMode) do
    self[i] = v
  end
end




function pDesk:onPut(player, score)
  if self.play then
    return self.play:on(player, {msgID=self.gName..'.puts', score=score})
  end
end

function pDesk:onQiang(player, number)
  if self.play then
    return self.play:on(player, {msgID=self.gName..'.qiang', number=number})
  end
end

function pDesk:onChoosed(player, cards)
  if self.play then
    return self.play:on(player, {msgID=self.gName..'.choosed', cards=cards})
  end
end

function pDesk:checkOverAction()
  local count = 0
  local allChoose = true
  for _, v in pairs(self.overSuggest.result) do
    if v == 1 then
      count = count + 1
    elseif v == 0 then
      allChoose = false
    end
  end

  if self.needDestroy then
    print("====> checkOverAction return")
    return
  end
  --local min = math.floor(self:getChairCnt() * 3 / 4)
  local min = self:getChairCnt()
  local msg = {}
  msg.msgID = self.gName..'.overgameResult'
  if count >= min then
      print("====> checkOverAction overgame")
      msg.over = true
      msg.record = self.playerRecord
      msg.fsummay = self:getFsummary()
      self:overRecords()
      self:sendMsg(msg)
      self:destroy()
  else
    if allChoose then
      msg.over = false
      self:sendMsg(msg)
    end
  end
  if allChoose then
    self.overSuggest = nil
  end
end

function pDesk:overActon(player, result)

  repeat
    if self:isPlayer(player) then break end
    if player:getUid() == self.ownerUid then break end
    print("overActon return")
    return
  until true

  if self.played and self.overSuggest then
    --[[if self.overSuggest.result[player:getUid()] == 1 or self.overSuggest.result[player:getUid()] == 2 then
      print('has suggest!',player:getUid())
      return
    end]]
    
    print(string.format("msg overgame: %s", result))

    if result == 2 then
      -- 停止解散倒计时
      print("msg overgame refuse")
      self.nOverGameCountdownStatus = self.tabOverGameConfig.eStop
      for i, v in pairs(self.overSuggest.result) do
        if v == 0 then
          self.overSuggest.result[i] = 1
        end
      end
    end

    self.overSuggest.result[player:getUid()] = result
    local msg = {}
    msg.msgID = self.gName..'.overgame'
    msg.data = self.overSuggest
    msg.dataEx = {
      countDown = self.tabOverGameConfig.nCheckTime,
      countDownStatus = self.nOverGameCountdownStatus
    }
    self:sendMsg(msg)
    self:checkOverAction()
    dump(msg)
  end
end

-- 发起解散房间
function pDesk:overgame(player)
  print("overgame", player:getUid(), player:getNickname(), "owneruid", self.ownerUid)
  repeat
    if self:isPlayer(player) then break end
    if player:getUid() == self.ownerUid then break end
    print("overgame return")
    return
  until true

  -- 开始过游戏的房间
  if self.played or self.play then
    if not self.overSuggest then
      self.overSuggest = {}

      self.overTimeOver = 0
      self.nOverGameCountdownStatus = self.tabOverGameConfig.eRun
      self.nOverGameCountdown = 0

      self.overSuggest.uid = player:getUid()
      self.overSuggest.result = {}
      self.overSuggest.result[player:getUid()] = 1

      for i = 1,#self.allChairs do
        if self.allChairs[i].agent then
          local uid = self.allChairs[i].agent:getUid()
          if not self.overSuggest.result[uid] then
            self.overSuggest.result[uid] = 0
          end
        end
      end
    end

    local msg = {}
    msg.msgID = self.gName..'.overgame'
    msg.data = self.overSuggest

    local countDown = self.tabOverGameConfig.nCheckTime
    if self.nOverGameCountdownStatus == self.tabOverGameConfig.eRun then
      countDown = self.tabOverGameConfig.nCheckTime - self.nOverGameCountdown
    end

    msg.dataEx = {
      countDown = countDown,
      countDownStatus = self.nOverGameCountdownStatus
    }
    self:sendMsg(msg)
  else
    -- 没有玩过游戏的房间
    if player.user.playerId == self.owner and not self.needDestroy then
      local msg = {}
      msg.msgID = self.gName..'.overgameResult'
      msg.over = true
      msg.record = self.playerRecord
      msg.fsummay = self:getFsummary()
      self:overRecords()
      self:sendMsg(msg)
      self:destroy()
    end
  end
end

function pDesk:init(app, deskInfo, deskId, ownerInfo)
  self.app = app
  self.deskId = deskId
  self.number = 1
  self.deskInfo = deskInfo
  self.allChairs = {}
  self.voiceList = {}
  self.checkTime = 0
  

  self.readyMaxTick = 8500 -- 自动准备时间
  self.readyTick = 0 

  --self.ownerInfo = table.copy(ownerInfo)
  print("=============> deskinfo")
  dump(self.deskId)

  self.tabPayRecord = {}    -- 支付记录

  -- 对局记录
  self.playerRecord = {}
  self.tabGameRecord = {} -- 每盘游戏的对局信息

  -- 解散
  self.tabOverGameConfig = {
    nCheckTime = 60 * 1000, -- 确认时间
    nGameOverTime = 3600* 1000, -- 游戏超时时间
    eRun = 1, -- 开始倒计时
    eStop = 0, --结束倒计时
    }
  self.nOverGameCountdownStatus = self.tabOverGameConfig.eStop
  self.nOverGameCountdown = 0

  -- 旁观者
  self.tabAllWatcher = {}

  if not self.deskInfo.maxPeople then
    self.deskInfo.maxPeople = 4
  else
    if type(self.deskInfo.maxPeople) ~= 'number' or
      self.deskInfo.maxPeople > 6 then
        self.deskInfo.maxPeople = 6
    end
  end
  self:initChair(self.deskInfo.maxPeople)
  self.state = nil

  self.allFunction = {
    delayState = function(dt)
      self:doDelayLogic(dt)
    end,
  }
end

function pDesk:isLeaveLimit()
  return (self.play or self.played)
end

function pDesk:finalizeAgent(agent)
  self:sendMsg({ msgID = self.gName..'.somebodyLeave', uid = agent:getUid()})
  agent:finalize()
end

function pDesk:leaveAction(agent, dropLine)
  if self:isLeaveLimit() or dropLine then
    print("玩家 | 掉线 | ",agent:getNickname())
    self:sendMsg({ msgID = self.gName..'.dropLine', uid = agent:getUid()})
    agent:setLeaved(true)
    agent:startTrusteeship()  -- 进入托管 
    return false
  else
    print("玩家 | 离开 | ",agent:getNickname())
    self:finalizeAgent(agent)
    return true
  end
end

function pDesk:clearRobotRoom()
  if self:isAllAgentIsRobot() then
    self:destroy()
  end
end

function pDesk:leave(agent, dropLine)
  self:setActiveTime(os.time())

  if agent == self.horse then                     -- 买马玩家
    if self:leaveAction(agent, dropLine) then
      self.horse = nil
      --self:clearRobotRoom()
    end
  elseif agent:getWatcher() then                  -- 旁观者
    -- remove watcher
    print("旁观者 | 离开 | ",agent:getNickname())
    self:removeWatcher(agent)
    agent:finalize()  
  else                                            -- 玩家
    for i = 1,#self.allChairs do
        if self.allChairs[i].agent and self.allChairs[i].agent == agent then
          if self:leaveAction(agent, dropLine) then
            self.allChairs[i].agent = nil
            self.nextBanker = nil
            --self:clearRobotRoom()
          end
          break
        end
      end
  end

end

function pDesk:initChairData(idx,agent)
  agent:setChairID(idx)
  self.allChairs[idx].agent = agent
end

function pDesk:genBot()
  local robot = self.app.robotMng:getRobot()
  if robot then
    robot.deskId = self.deskId
    local agent = self:sitdown(robot,robot:getUid())
    if agent then
     agent:prepareToPlay()
    end
  end
end

function pDesk:botPrepare()
  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent then
      local isBot = agent:isBot()
      local isprepare = agent:getPrepare()
      if isBot and (not isprepare) then
        agent:prepareToPlay()
      end
    end
  end
end

function pDesk:createAgent(user)
  local Agent = require('niuniu.'..self.gName..'.Agent')
  local agent = Agent(self.app,user)
  user:setAgent(agent)
  agent:setDesk(self)

  return agent
end

-- watcher 
function pDesk:getWatcher(uid)
  for idx, VAgent in pairs(self.tabAllWatcher) do
    if VAgent:getUid() == uid then
      return true, VAgent
    end
  end
  return false
end

function pDesk:addWatcher(agent)
  agent:setWatcher(true)
  table.insert( self.tabAllWatcher, agent)
end

function pDesk:removeWatcher(agent)
  agent:setWatcher(false)
  table.removebyvalue(self.tabAllWatcher, agent, true)
end

function pDesk:getWatcherCount(agent)
  return table.nums(self.tabAllWatcher)
end

function pDesk:sendMsgToWatcher(msg, exceptUid)
  for idx, VAgent in pairs(self.tabAllWatcher) do
    if exceptUid and exceptUid == VAgent:getUid() then

    else
      VAgent:sendMsg(msg)
    end
  end
end

function pDesk:isPlayer(agent)
  for i, v in pairs(self.allChairs) do
    if v.agent and v.agent:getUid() == agent:getUid() then
      return true
    end
  end
  return false
end

function pDesk:isUserExist(uid)
  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent then
      if agent:getUid() == uid then
        return true, agent
      end
    end
  end
  return false
end

function pDesk:canBeHorse()
  if (self.deskInfo.enter.buyHorse == 0) or self.horse then
    return false
  end
  return true
end

function pDesk:setHorse(user)
  if not user:isGameLegal() then
    user:clearGames()
    return nil
  end
  if self.horse then
    user:setAgent(self.horse)

    self.horse:setLeaved(false)
    self.horse:setTrusteeship(false)

    self.horse:setDesk(self)
  else
    self.horse = self:createAgent(user)
  end
  local rep = self:package()
  rep.msgID = self.gName..'.synDeskData'    -- 买马
  self.horse:sendMsg(rep)
  local rep2 = {}
  rep2.msgID = self.gName..'.enterHorse'
  rep2.horse = {}
  rep2.horse.uid = self.horse:getUid()
  rep2.horse.nickName = self.horse.user.nickName
  rep2.horse.money = self.horse:getMoney()
  if self.play then
    self.play:setHorse(self.horse)
  end
  self:sendMsg(rep2)
end

function pDesk:showRoomInfo()
  local info = self:packageInfo()
  return info
end

-- 进入桌子-旁观者
function pDesk:enterDesk(user)
  local uid = user.uid
  local isPlayer = false

  if not user:isGameLegal() then
    user:clearGames()
    return nil
  end

  -- set desk status
  self:setActiveTime(os.time())


  local function deskInfo(agent)
    local rep = self:package(uid)
    rep.msgID = self.gName..'.synDeskData'        -- 桌子数据
    rep.watcherInfo = {count = self:getWatcherCount()}
    rep.reload = false
    agent:sendMsg(rep)

    if isPlayer then
      rep = {}
      rep.msgID = self.gName..'.somebodySitdown'
      rep.userData = agent:package()
      self:sendMsg(rep,uid)
    else
      rep = {}
      rep.msgID = self.gName..'.somebodyEnterDesk'  -- 进入桌子
      rep.watcherInfo = {count = self:getWatcherCount()}
      self:sendMsg(rep,uid)
    end

    if self.ownerUid == agent:getUid() and self:canStartGame() and (not self.played)then
      self:requestOwnerStart()
    end
  end
  

  local exist, agent = nil, nil
  repeat
    -- 坐下玩家重连
    exist, agent = self:isUserExist(uid)
    if exist then 
      agent:setWatcher(false)
      agent:stopTrusteeship()
      isPlayer = true
      break 
    end

    -- 旁观者进入
    exist, agent = self:getWatcher(uid)
    if not exist then
      agent = self:createAgent(user)
      self:addWatcher(agent)
    end
    isPlayer = false
    agent:setWatcher(true)
  until true

  -- set user status
  user:setAgent(agent)
  -- set agent status
  agent:setLeaved(false)
  agent:setTrusteeship(false)
  agent:setDesk(self)
  deskInfo(agent, true) -- send msg 2 c
  return agent  
end


-- 用户重连 发送桌子数据
function pDesk:onReloadData(agent)
    local rep = self:package(agent:getUid())
    rep.msgID = self.gName..'.synDeskData'
    rep.watcherInfo = {count = self:getWatcherCount()}
    rep.reload = true
    print("用户重连",agent:getNickname())
    agent:sendMsg(rep)
end


function pDesk:onRequestSitdown(agent)
  local uid = agent:getUid()
  self:setActiveTime(os.time())

  local function responseSitdown(errCode)
    --[[
      1: 坐满
      2: 已经坐下
      3: 房卡不够
    ]]
    errCode = errCode or 1
    local rep = {}
    rep.msgID = self.gName..".responseSitdown"
    rep.errCode = errCode
    print(self.gName..".responseSitdown", agent:getNickname(), errCode)
    agent:sendMsg(rep)
  end

  local function deskInfo(agent)
    local rep = self:package(uid)
    rep.msgID = self.gName..'.synDeskData'
    rep.watcherInfo = {count = self:getWatcherCount()}
    rep.reload = false
    agent:sendMsg(rep)

    rep = {}
    rep.msgID = self.gName..'.somebodySitdown'
    rep.userData = agent:package()
    self:sendMsg(rep,uid)
  end

  if not agent:getWatcher() then
    responseSitdown(2)
    return
  end

  -- 坐满情况
  local chairId = self:getFreeChair()
  if not chairId then
    responseSitdown(1)
    return
  end
  
  -- AA模式房卡检测
  if self.deskInfo.roomPrice == 2 and self:checkUserAAPay(uid) then
    local user = self.app.users[agent:getUid()]
    local diamond = 0

    if user then
      diamond = user:getRes('diamond') or 0
    end
    
    local cost = self.cost/3
    print("AA房卡检测", agent:getNickname(), "需要:", cost, "拥有:", diamond)
    if cost > diamond then
      responseSitdown(3)
      return
    end
  end

  -- 成功坐下
  responseSitdown(0)

  -- set agent status
  agent:setLeaved(false)
  agent:setTrusteeship(false)
  agent:setWatcher(false)
  agent:setDesk(self)

  self:initChairData(chairId,agent)     -- 设置椅子信息

  if not self.play then
    if self:getWatcher(uid) then          -- 清除旁观
      self:removeWatcher(agent)
    end
    agent:setInMatch(true)
  else
    agent:setInMatch(false)
  end

  print("当前玩家:")
  for i, v in pairs(self.allChairs) do
    local agent = v.agent
    if agent then
      print(i, agent:getNickname(), agent:getUid())
    end
  end

  print("当前旁观者:")
  for i, v in pairs(self.tabAllWatcher) do
    print(i, v:getNickname(), v:getUid())
  end

  deskInfo(agent, false)                -- 发送数据

  local freeChair = self:getFreeChair()
  if not freeChair then
    self:setState('delayOver')
  end
  
end

function pDesk:sitdown(user)
  self:enterDesk(user)
end

function pDesk:sitdown_org(user)
  local uid = user.uid
  if not user:isGameLegal() then
    user:clearGames()
    return nil
  end
  self:setActiveTime(os.time())
  local function deskInfo(agent)
    local rep = self:package(uid)
    rep.msgID = self.gName..'.synDeskData'
    agent:sendMsg(rep)

    rep = {}
    rep.msgID = self.gName..'.somebodySitdown'
    rep.userData = agent:package()
    self:sendMsg(rep,uid)
  end

  local exist, agent = self:isUserExist(uid)

  if exist then
    user:setAgent(agent)

    agent:setLeaved(false)
    agent:setTrusteeship(false)

    agent:setDesk(self)
    deskInfo(agent, true)
    return agent
  else
    local chairId = self:getFreeChair()
    if chairId then
      agent = self:createAgent(user)
      self:initChairData(chairId,agent)
      deskInfo(agent, false)

      local freeChair = self:getFreeChair()

      if freeChair then
        local t = 40 -- hedi
        if self.deskInfo.robot then
          if type(self.deskInfo.robot) == 'number' then
            t = self.deskInfo.robot
          end
        end
        print(string.format("===> 机器人个数: %s", t)) -- hedi

        -- self:delayAction(function()
        --   self:genBot()
        -- end, t)

        if self.played or self.play then
          if agent:getMoney() >= self.cost then
            print("===============> onUserSitDown")
            dump(agent)
            self:userPay(agent:getUid(), agent.user.playerId, agent.user.nickName, self.cost)
          else
            local rMsg = {}
            rMsg.msgID = 'createRoom'
            rMsg.errorCode = 1
            user:sendMsg(rMsg)
          end
        end
      else
        self:setState('delayOver')
      end
      return agent
    else
      user:clearGames()
    end
  end
end

function pDesk:getChairCnt()
  local ret = 0

  for i = 1,#self.allChairs do
    if self.allChairs[i].agent then
      ret = ret + 1
    end
  end

  if self.horse then
    ret = ret + 1
  end

  return ret
end

function pDesk:sendPrepareMsg(agent)
  local rep = {}
  rep.msgID = self.gName..'.somebodyPrepare'
  rep.uid = agent:getUid()
  self:sendMsg(rep)
end

function pDesk:isAllPrepare()
  local allPrepare = true
  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent ~= nil then
      if not agent:getPrepare() then
        allPrepare = false
      end
    end
  end

  return allPrepare
end

function pDesk:setOwner(playerId, nickName, cost, uid)
  self.owner = playerId
  self.ownerUid = uid
  self.ownerName = nickName
  self.cost = cost
end

function pDesk:packageInfo()
  local info = {}
  info.deskInfo = self.deskInfo
  info.number = self.number
  info.deskId = self.deskId
  info.ownerName = self.ownerName
  info.voiceList = self.voiceList
  info.played = self.played
  info.isPlaying = (self.play) and true or false

  info.readyTick = 0
  info.readyTimerStart = false
  if self.played and nil == self.play then
    info.readyTick = self.readyTick
    info.readyTimerStart = true
  end


  print("===> packageInfo: base")
  if self.horse then
    print("===> packageInfo: horse")
    info.horse = {
      uid = self.horse:getUid(),
      nickName = self.horse.user.nickName,
      money = self.horse:getMoney()
    }
  end

  if self.play then
    print("===> packageInfo: play")
    local game = self.play:package()
    dump(game)
    for i, v in pairs(game) do
      info[i] = v
    end
    info.overSuggest = self.overSuggest
    info.gameTick = self.play.wait or 0
  end


  print(string.format("info.isPlaying: %s", info.isPlaying))
  print(string.format("info.played: %s", info.played))
  return info
end

function pDesk:package(ex)
  local bPlayer = false

  local data = {}
  data.allUsers = {}

  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent ~= nil then
      local uid = agent:getUid()
      if ex and ex == uid then
        data.myData = agent:package(true)
        bPlayer = true
      else
        data.allUsers[#data.allUsers + 1] = agent:package()
      end
    end
  end

  local isOwner = false
  if ex and ex == self.ownerUid then
    isOwner = true
  end

  data.isOwner  = isOwner
  data.isPlayer = bPlayer
  data.info = self:packageInfo()

  return data
end

function pDesk:getFreeChair()
  for i = 1,#self.allChairs do
    if self.allChairs[i].agent == nil then
      return i
    end
  end
end

function pDesk:userPay(uid, playerId, name, cost)
  print("========> 用户支付房卡", uid, playerId, name, cost)
  local mongo = self.app.mongo
  if cost > 0 then
    local user = self.app.users[uid]
    if user then
      user:updateRes('diamond', -cost)
    else
      if uid then
        mongo:update('user',{uid = uid}, {['$inc'] = {diamond = -cost}},nil,true, function()end)
      end
    end
    table.insert( self.tabPayRecord, {uid = uid, pay = cost, name = name})
  end

  local insert = {}
  insert.playerId = playerId
  insert.name = name
  insert.cost = cost
  insert.time = os.time()
  insert.type = "openRoom"
  mongo:insert("consume", insert, nil, function(err, _)
    if err then
      print('create record err', err)
    end
  end)
end

function pDesk:checkUserAAPay(uid)
  if self.tabPayRecord then
    for j, k in pairs(self.tabPayRecord) do
      if k.uid == uid then
        return false
      end
    end
  end
  return true
end

-- 单局游戏结算时 检测房卡支付状态
function pDesk:checkPay(checkMode)
  checkMode = checkMode or false
  local needPay = false

  if self.deskInfo and self.deskInfo.roomPrice then
    if self.deskInfo.roomPrice == 2 then
      -- aa
      for i, v in pairs(self.allChairs) do
        if v.agent then
          local playerUid = v.agent:getUid()
          local playerId = v.agent.user.playerId
          local playerName = v.agent:getNickname()

          local isPayed = false
          for j, k in pairs(self.tabPayRecord) do
            if k.uid == playerUid then
              isPayed = true
            end
          end
          if not isPayed then
            needPay = true
            if not checkMode then
              self:userPay(playerUid, playerId, playerName, self.cost/3)
            end
          end
        end
      end
    else
      -- 房主
      if not self.played then -- 第一局游戏 扣房卡
        --local own = self.ownerInfo
        needPay = true
        if not checkMode then
          self:userPay(self.ownerUid, self.owner, self.ownerName, self.cost)
        end
      end
    end
  end
  return needPay
end


function pDesk:payMoney()

  if self.deskInfo and self.deskInfo.roomPrice then
    print("=============> roomPrice")
    print(self.deskInfo.roomPrice)
  end

  if self.deskInfo.roomPrice == 2 then
    print("=============> AA 模式")
    --AA
    for i = 1,#self.allChairs do
      local agent = self.allChairs[i].agent
      if agent then
        self:userPay(agent:getUid(), agent.user.playerId, agent.user.nickName, self.cost/3)
      end
    end

  else
    print("=============> 房主 模式")
    --房主
    for i = 1,#self.allChairs do
      local agent = self.allChairs[i].agent
      if agent and agent.user.playerId == self.owner then
        self:userPay(agent:getUid(), agent.user.playerId, agent.user.nickName, self.cost)
      end
    end
  end

end

function pDesk:gameStart(banker)
  print("game start!!")
  self:resetRoomInfo()

  local players = {}
  local defaultBanker = nil

  -- 初始化玩家
  for i = 1, #self.allChairs do
    if self.allChairs[i].agent and self.allChairs[i].agent:getPrepare() then
      if not defaultBanker then defaultBanker = self.allChairs[i].agent end
      
      self.allChairs[i].agent:setInMatch(true)

      table.insert(players, self.allChairs[i].agent)

      if self:getWatcher(self.allChairs[i].agent:getUid()) then
        print("gameStart ===> 清除旁观者", self.allChairs[i].agent:getNickname())
        self:removeWatcher(self.allChairs[i].agent)
      end
    end
  end

  if not banker then
    print("game start!! banker333333")
    banker = array.max(players, function (a, b)
      return a:getMoney() < b:getMoney()
    end)
    self:setNextBanker(banker)
  end

  local Gameplay = require('niuniu.'..self.gName..'.Gameplay')
  self.play = Gameplay(players, self.deskInfo, self.app)
  if self.horse then
    self.play:setHorse(self.horse)
  end

  self.play:setWatcher(self.tabAllWatcher)

  if not banker then
    banker = defaultBanker
  end
  --print("庄家:", banker:getNickname(), banker:getUid())
  self.play:setDeskStatus({number = self.number})
  self.play:start(banker)
end

function pDesk:chatInGame(uid, data)
  local msg = {}
  msg.msgID = 'chatInGame'
  msg.uid = uid
  msg.type = data.type
  msg.msg = data.msg

  self:sendMsg(msg)
end

function pDesk:getAgentBy(uid)
  for _, v in ipairs(self.allChairs) do
    if v.agent and v.agent:getUid() == uid then
      return v.agent
    end
  end
  if self.horse then
    if self.horse:getUid() == uid then
      return self.horse
    end
  end
end

function pDesk:setState(state)
  self.delay = 0
  self.state = state
end

function pDesk:sendMsg(msg,except)
  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent then
      local flag = true
      if except then
        if agent:getUid() == except then
          flag = false
        end
      end

      if flag then
        agent:sendMsg(msg)
      end
    end
  end
  if self.horse then
    self.horse:sendMsg(msg)
  end

  self:sendMsgToWatcher(msg, except)
end

function pDesk:initChair(maxPeople)
  for i = 1,maxPeople do
    self.allChairs[i] = {}
  end
end

function pDesk:gameOver(overMsg)
  local msg = {}
  msg.msgID = self.gName..'.gameOver'
  if overMsg then
    for i,v in pairs(overMsg) do
      msg[i] = v
    end
  end

  self:sendMsg(msg)
  self:resetUsersState()
  self:resetRoomInfo()

  self:delayAction(function()
    self:botPrepare()
    end, 5)
end

function pDesk:resetUsersState()
  for i = 1,#self.allChairs do
    local agent = self.allChairs[i].agent
    if agent then
      agent:setPrepare(false)
      agent:setTrusteeship(false)
    end
  end
end

function pDesk:recordGameData(uid, niuCnt, score)
  if not self.playerRecord[uid] then
    self.playerRecord[uid] = {
      winCnt = 0,
      loseCnt = 0,
      hasNiu = 0,
      noNiu = 0,
      score = 0,
    }
  end

  if niuCnt == 0 then
    self.playerRecord[uid]['hasNiu'] = self.playerRecord[uid]['hasNiu'] + 1
  else
    self.playerRecord[uid]['noNiu'] = self.playerRecord[uid]['noNiu'] + 1
  end
  if score > 0 then
    self.playerRecord[uid]['winCnt'] = self.playerRecord[uid]['winCnt'] + 1
  else
    self.playerRecord[uid]['loseCnt'] = self.playerRecord[uid]['loseCnt'] + 1
  end

  self.playerRecord[uid].score = self.playerRecord[uid].score + score
end

function pDesk:getFsummary()
  local fsummay = {}
  for _, v in ipairs(self.allChairs) do
    local p = {}
    if v.agent then
      p.nickName = v.agent.user.nickName
      p.money = v.agent:getMoney()
      p.uid = v.agent:getUid()
      p.playerId = v.agent.user.playerId
      p.avatar = v.agent.user.avatar
      table.insert(fsummay, p)
    end
  end

  if self.horse then
    local p = {}
    p.nickName = self.horse.user.nickName
    p.money = self.horse:getMoney()
    p.avatar = self.horse.user.avatar
    p.playerId = self.horse.user.playerId
    table.insert(fsummay, p)
  end

  return fsummay
end

function pDesk:overRecords()
  if table.empty(self.playerRecord) then
    return
  end
  local insert = {}
  insert.uids = {}
  insert.player = {}
  insert.gameRecord = self.tabGameRecord            -- 对局详情
  insert.time = os.time()
  insert.deskId = self.deskId
  insert.round = self.deskInfo.round
  insert.base = self.deskInfo.base
  insert.ownerName = self.ownerName
  insert.gameplay = self.deskInfo.gameplay
  for i, v in pairs(self.playerRecord) do
    table.insert(insert.uids, i)
    local agent = self:getAgentBy(i)
    local p = {}
    p.result = v.score
    p.avatar = agent.user.avatar
    p.playerId = agent.user.playerId
    p.nickName = agent.user.nickName
    p.uid = i
    table.insert(insert.player, p)
  end

  local mongo = self.app.mongo
  mongo:insert("records", insert, nil, function(err, _)
    if err then
      print('create record err', err)
    end
  end)
end

function pDesk:isPlayOver()
  if self.number > self.deskInfo.round then
    return true
  end
end



function pDesk:summary(data, gameOver)
  self:checkPay()

  if not self.played then
    self.played = true
    --self:payMoney()
  end

  self.app.mongo:update('rooms',{deskId=self.deskId}, {['$set'] = {round = self.number}},nil,nil, function()end)

  local insert = {}
  insert.uids = {}
  insert.player = {}

  -- 记录每盘对局详情
  if data then
    local tmpTab = table.copy(data)
    self.tabGameRecord[#self.tabGameRecord + 1] = tmpTab
    print("===> pdesk tabGameRecord | count: %s ", #self.tabGameRecord)
    dump(self.tabGameRecord[#self.tabGameRecord])
  end

  for i, v in pairs(data) do
    self:recordGameData(i, v.niuCnt, v.score)
    local agent = self:getAgentBy(i)
    if not agent:isBot() then
      agent.user:updateWinRate(v.score > 0)
    end
  end

  ----单局结算 推送给客户端
  local msg = {}
  msg.msgID = self.gName..'.summary'
  msg.data = data
  if self.horse then
    msg.horse = msg.data[self.horse:getUid()]
    msg.data[self.horse:getUid()] = nil
  end

  if self:isPlayOver() or gameOver then
    msg.record = self.playerRecord
    msg.fsummay = self:getFsummary()
    self:overRecords()
    self:sendMsg(msg)
    ----最终结算，销毁房间
    ----推送给客户端
    self:destroy()
  else
    self:sendMsg(msg)
  end
end

function pDesk:setNextBanker(nextBanker)
  self.nextBanker = nextBanker
end


function pDesk:setAllPrepare()
  for i, v in pairs(self.allChairs) do
    local agent = v.agent
    if agent then
      agent:prepareToPlay()
    end
  end
end

function pDesk:update(dt)

  -- GamePlay 刷新
  if self.play then
    if not self.play:done() then
      self.play:checkState()
      self.play:update(dt)
      self.readyTick = self.readyMaxTick
    else
      self:setNextBanker(self.play.game.nextBanker)
      self.number = self.number + 1
      local summary = self.play:summary()
      local gameOver = self.play.game.gameOver
      self.play = nil
      self:summary(summary, gameOver)
      -- clear the play
      -- self.overSuggest = nil
      self:resetUsersState()
      -- 比赛桌子不能清理机器人
      self:botPrepare()
    end
  end

  if self.played and nil == self.play then
    if self.readyTick <= 0 then
      self.readyTick = self.readyMaxTick
      self:setAllPrepare()
    elseif self.nOverGameCountdownStatus == self.tabOverGameConfig.eStop then
      self.readyTick = self.readyTick - dt
    end
  end

  local call = self.allFunction[self.state]
  if call then
    call(dt)
  end

  -- 用户刷新
  for i = 1,#self.allChairs do
    if self.allChairs[i].agent then
      self.allChairs[i].agent:update(dt)
    end
  end

  -- 自动解散不活跃房间
  self.checkTime = self.checkTime + dt
  if self.checkTime > 1000 then
    self.checkTime = 0
    self:checkTimeOut()
  end

  -- 发起解散倒计时
  if self.overSuggest then
    self.overTimeOver = self.overTimeOver + dt
    if self.overTimeOver > self.tabOverGameConfig.nGameOverTime then  -- 自动解散房间
      self.overTimeOver = 0
      for i, v in pairs(self.overSuggest.result) do
        if v == 0 then
          self.overSuggest.result[i] = 1
        end
      end
      self:checkOverAction()
    end
    -- 解散倒计时
    self.nOverGameCountdown = self.nOverGameCountdown + dt
    if self.nOverGameCountdownStatus == self.tabOverGameConfig.eRun and
      self.nOverGameCountdown > self.tabOverGameConfig.nCheckTime
    then
      self.nOverGameCountdownStatus = self.tabOverGameConfig.eStop
      self.nOverGameCountdown = 0
      for i, v in pairs(self.overSuggest.result) do
        if v == 0 then
          self.overSuggest.result[i] = 1
        end
      end
      self:checkOverAction()
    end
  end

end

function pDesk:setActiveTime(t)
  self.activeTime = t
end

function pDesk:checkTimeOut()
  if self:getChairCnt() == 0 then
    local passTime = os.time() - self.activeTime
    if passTime > 1800 then
      self:destroy()
    end
  end
end

function pDesk:destroy()
  self.needDestroy = true
  self.play = nil
  for _, v in ipairs(self.allChairs) do
    if v.agent then
      self:finalizeAgent(v.agent)
      v.agent = nil
    end
  end

  if self.horse then
    self:finalizeAgent(self.horse)
    self.horse = nil
  end
  self.tabPayRecord = {}
end

function pDesk:isAllAgentIsRobot()
  for i = 1,#self.allChairs do
    if self.allChairs[i].agent then
      if not self.allChairs[i].agent:isBot() then
        return false
      end
    end
  end

  return true
end

function pDesk:playVoice(uid,msg)
  msg.uid = uid
  local cache = {}
  cache.filename = msg.filename
  cache.total = msg.total
  cache.uid = msg.uid
  table.insert(self.voiceList, cache)
  self:sendMsg(msg)
end

function pDesk:onCancelTrusteeship(uid,msg)
  self:sendMsg({
          msgID = self.gName..'.somebodyCancelTrusteeship',
          uid = uid,
        })
end

function pDesk:onRequestTrusteeship(uid,msg)
  self:sendMsg({
          msgID = self.gName..'.somebodyTrusteeship',
          uid = uid,
        })
end

return pDesk
