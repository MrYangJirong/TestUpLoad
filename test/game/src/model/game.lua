
local HasSignals = require('../HasSignals')
local class = require('middleclass')
local Game = class('Game'):include(HasSignals)
local safe = require('game.src.safe')

function Game:initialize(app, setting, coinCfg, gameMgr)
  HasSignals.initialize(self)
  self.app = app
  self.gameMgr = gameMgr
  self.type = setting.type
  self.name = setting.name
  self.createList = {}
  self.allDesks = {}
  self.goldDesks = {}
  self:initListen(setting)
  self.setting = setting
  self.coinCfg = coinCfg
  self.deskIdRange = setting.deskIdRange
end

function Game:initListen(setting)
  local listen = require(setting.type..'.'..setting.game..'.Listen')
  if listen then
    self.app[setting.game] = listen(self.app)
  else
    print('listen ',setting.type,setting.game,' error!!')
  end
end

function Game:initDataFromDB()
  self.app.mongo:find("rooms", {game = self.setting.game},{}, nil, nil, safe(function(err, res)
    if not err then
      if #res > 0 then
        for _, v in ipairs(res) do
          local desk = require(self.setting.type..'.'..self.setting.game..'.Desk')
          local newDesk = desk(self.app, v.options, v.deskId)
          newDesk:setActiveTime(os.time())
          newDesk:setOwner(v.owner, v.nickName, v.cost, v.ownerUid)
          self.allDesks[v.deskId] = newDesk
        end
      end
    end
  end))
end

function Game:enterGoldRoom(user, msg)
  if user:isPlaying() then
    print('now player in other gold room!')
    return
  elseif (not self.coinCfg) then
    print('not this gold rooms')
    return
  end

  local cfg = table.copy(self.coinCfg)

  if msg.robot then
    cfg.robot = msg.robot
  end
  if msg.btmCost then
    cfg.btmCost = msg.btmCost
  end
  if msg.enterLimit then
    cfg.enterLimit = msg.enterLimit
  end
  if msg.leaveLimit then
    cfg.leaveLimit = msg.leaveLimit
  end

  local ownRes = user:getRes('gold')
  if cfg.enterLimit > 0 and ownRes <= cfg.enterLimit then
    print('gold not enough!!!')
    local rep = {}
    rep.msgID = 'enterGoldRoom'
    rep.errorCode = 1
    user:sendMsg(rep)
    return
  end
  for k, v in pairs(self.goldDesks) do
    if v:getPlayMode().gameIdx == msg.gameIdx then
      if (4 - v:getChairCnt()) > 0 then
        print(cfg.robot, v.deskInfo.robot)
        if cfg.robot == v.deskInfo.robot and cfg.btmCost == v.deskInfo.btmCost then
          user.goldId = k
          v:sitdown(user)
          return
        end
      end
    end
  end

  local k = tostring(os.time())
  if not self.goldDesks[k] then
    local desk = require(self.setting.type..'.'..self.setting.game..'.Desk')
    local newDesk = desk(self.app, cfg, k)
    newDesk:setOtherMode(self.setting.type..'.jbDesk')
    newDesk:setPlayMode({gameIdx = msg.gameIdx})
    self.goldDesks[k] = newDesk
    user.goldId = k
    newDesk:sitdown(user)
  end
end

function Game:createDesk(user, msg, resultCallBack)
  local cost = self.setting.cost[tostring(msg.options.round)]
  local roomPrice = cost
  if msg.options.roomPrice and msg.options.roomPrice == 2 and cost then
    roomPrice = cost / 3
  end
  if not cost then
    print("not this cost for ", msg.options.round)
    return
  end
  if user.createing and (os.time() - user.createing) < 10 then
    print('createing..')
    return
  end
  user.createing = os.time()
  self.app.mongo:findOne("qq", {title = 'free'},{content = 1}, nil, function(err, qq)
    user.createing = nil
    if not err then
      -- test hedi
      if qq and qq.content then
        cost = 0
        print(string.format("===> 创建房间 qq: ture"))
      end
      print(string.format("===> 创建房间 费用: %s 用户钻石: %s", cost, user:getRes('diamond')))

      if cost > 0 and user:getRes('diamond') < roomPrice then
        local rMsg = {}
        rMsg.msgID = msg.msgID
        rMsg.errorCode = 1
        user:sendMsg(rMsg)
        return
      end

      local deskId
      math.randomseed(os.time())
      for tryCnt = 1, 9999 do
        deskId = tostring(string.format("%06d", math.random(self.deskIdRange[1],self.deskIdRange[2])))
        if not self.allDesks[deskId] and 
          not self.createList[deskId] 
        then
          self.createList[deskId] = true
          print("创建房间|deskID:", deskId, "尝试次数:", tryCnt)
          break
        end
      end
 
      if not msg.options.enter then
        msg.options.enter = {
          enterOnCreate = 1,
          buyHorse = 0,
        }
      end
      if not msg.options.double then
        msg.options.double = 99999
      end

      -- owner info
      local insert = {}
      insert.owner = user.playerId
      insert.ownerUid = user.uid
      insert.nickName = user.nickName
      insert.cost = cost
      insert.round = 0
      insert.maxActors = 4
      insert.options = msg.options
      insert.game = self.setting.game
      dump(insert)

      local deskClass = require(self.setting.type..'.'..self.setting.game..'.Desk')
      local newDesk = deskClass(self.app, msg.options, deskId, insert)
      newDesk:setActiveTime(os.time())
      newDesk:setOwner(user.playerId, user.nickName, cost, user.uid)
      self.allDesks[deskId] = newDesk
      local rMsg = {}
      rMsg.msgID = msg.msgID
      rMsg.enterOnCreate = msg.options.enter.enterOnCreate
      rMsg.deskId = deskId
      user:sendMsg(rMsg)

      self.createList[deskId] = nil
      -- owner info
      insert.deskId = deskId

      -- 结果回调函数
      if resultCallBack then
          resultCallBack(insert)
      end

      local mongo = self.app.mongo
      mongo:insert("rooms", insert, nil, safe(function(rerr, _)
        if not rerr then
          print('create new room')

        end
      end))
    end
  end)
end

function Game:update(dt)
  for i, v in pairs(self.allDesks) do
    if v.needDestroy then
      -- 移除加入记录
      self.app.mongo:remove('joinRecord',{deskId=v.deskId}, false, function(err)
        print('clear joinRecord err is', err)
      end)
      -- 移除房间记录
      self.app.mongo:remove('rooms',{deskId=v.deskId}, 1, function(err)
        print('clear room err is', err)
      end)
      self.emitter:emit('onDelDesk', v.deskId)
      self.allDesks[i] = nil
    else
      v:update(dt)
    end
  end

  for i, v in pairs(self.goldDesks) do
    if v.needDestroy then
      self.goldDesks[i] = nil
    else
      v:update(dt)
    end
  end

  --------test---------------
    --[[self.play:update(dt)
    for _, v in pairs(self.players) do
        v:update(dt)
    end]]
  --------test---------------
end

function Game:sitdown(user,msg)
  if user:isPlaying() then
    print('user is in other desk!', user.deskId, user.goldId)
    return
  end

  if self.allDesks[msg.deskId] then
    print('sitdown success')
    local desk = self.allDesks[msg.deskId]
    if msg.buyHorse then---买马模式
      if desk:canBeHorse() then
        user.deskId = msg.deskId
        user.buyHorse = true
        self.app.mongo:update('user',{uid=user.uid}, {['$set'] = {deskId = msg.deskId, buyHorse = true}},nil,true, safe(function()
        end))
        

        desk:setHorse(user)
      else
        local data = {}
        data.success = false
        data.msgID = msg.msgID
        user:sendMsg(data)
      end
    else
    --[[
      -- 原 进入坐下逻辑
      user.deskId = msg.deskId
      self.app.mongo:update('user',{uid=user.uid}, {['$set'] = {deskId = msg.deskId}},nil,true, safe(function()
      end))
      user.agent = self.allDesks[msg.deskId]:sitdown(user)
    ]]
      -- 进入默认观战
      user.deskId = msg.deskId
      local desk = self.allDesks[msg.deskId]
      local ownerUid = desk.ownerUid

      self.app.mongo:update('user',{uid=user.uid}, {['$set'] = {deskId = msg.deskId}},nil,true, safe(function()
      end))

      if ownerUid ~= user.uid then
        -- 创建加入记录
        self.app.mongo:update("joinRecord", 
          {
            deskId = tostring(msg.deskId),
            playerUid = tostring(user.uid)       
          },
          {
            ['$set'] = 
              {
                deskId = msg.deskId,
                playerUid = tostring(user.uid),
                ownerUid = tostring(ownerUid)
              }
          },
          true, -- upsert 
          false, -- multi 
          safe(function()
          end)
        )
      end

      user.agent = desk:enterDesk(user)
    end
  else
    local data = {}
    data.success = false
    data.msgID = msg.msgID
    user:sendMsg(data)
  end
end

return Game
