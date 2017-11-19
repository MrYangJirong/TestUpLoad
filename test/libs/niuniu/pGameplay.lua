--[[

 -> 服务器单独发消息给单个玩家
 <- 玩家发给服务器
 => 服务器单独发消息给牌局中的所有玩家
 缩进表示事件、消息有先后顺序

Starting: 开局洗牌

Dealing: 发牌

Bidding: 补充亮主，顶主，定主的时间

Swapping: 扣底

Trumping: 显示主牌

Rewarding: 亮主成功玩家获得底牌中的主牌

Playing: 开始打牌

Ending: 结束

]]
local class = require('middleclass')
local Stateful = require('Stateful')

local safe = require('safe')

local pGameplay = class('pGameplay'):include(Stateful)

local SHUFFLING_TIME = 500
local ENDING_TIME = 5000
local DEALING_INTERVAL = 2000

function pGameplay:baseInit(players, option, app)
  local Game = require('niuniu.'..self.gName..'.Game')
  local Card = require('niuniu.'..self.gName..'.card')
  self.Card = Card()
  self.Card:setOption(option)
  self.game = Game(players, option)
  self.app = app
  self.tabCheatInfo = {}
  self.firstPlayer = nil          -- 开始发牌玩家
  self.deskStatus = {}
end

function pGameplay:update() -- luacheck: ignore self
end

-- 桌子状态
function pGameplay:setDeskStatus(tabData)
  self.deskStatus = tabData
end

function pGameplay:broadcast( msgid, args, exclude)
  args = args or {}
  args.msgID = msgid
  for _, p in ipairs(self.game.players) do
    if p ~= exclude then
      --print(('send %s to %s'):format(msgid, p:getUid()))
      p:sendMsg(args)
    end
  end

  if self.game.horse then
    self.game.horse:sendMsg(args)
  end

  if self.game.watcher then
    for _,v in pairs(self.game.watcher) do
      v:sendMsg(args)
    end
  end
end

function pGameplay:send(player, msgid, args)
  args = args or {}
  args.msgID = msgid
  player:sendMsg(args)
end

function pGameplay:timeup(dt, reset)
  if not self.wait then
    return false
  end

  self.wait = self.wait - dt
  local r = self.wait <= 0
  if r then
    self.wait = reset
  end
  return r
end

function pGameplay:bad(player, what, e, gamestate)
  print('error', player:getUid(), what, "on", gamestate)
  self:send(player, 'error', {what=what})
  dump(e)
  --print(debug.traceback())
end

function pGameplay:on(p, e) -- luacheck: ignore
  self:bad(p, 'bad pGameplay state', e, 'none')
end

--[[
Starting:
  =>start {banker=id, ranks={uid='A', uid='2', uid='A', uid=2} timeout=milliseconds}
]]
local Starting = pGameplay:addState('Starting')

function pGameplay:getDealCards()
  self.cards = self.Card.shuffle(self.Card:newDecks(2))
end

--local count = 1
function Starting:enteredState(banker)
  self.state = 'Starting'
  assert(self.game:validPlayer(banker))
  
  if self.game.option.gameplay == 1 and self.game.nextBanker then
    banker = self.game.nextBanker
  end
  
  self.wait = SHUFFLING_TIME
  self.game:start(banker)
  if self.game.horse then
    local horseBuy = self.game:horseBuy()
    self:broadcast(self.gName..'.horseBuy', {uid= horseBuy})
  end
  self:getDealCards()

  self.cards = {
    --8                           --7
    '♦A','♦Q','♦J','♦9','♦6',  '♦6','♥A','♠A','♣A','QA',
    --6                           --5
    '♦5','♦6','♦7','♦8','♣9',  '♦A','♦3','♦5','♦7','♦9',
    --4                           --3
    '♣J','♣K','♦K','♣Q','♦Q',  '♣Q','♥Q','♠K','♣K','♦K',
    --2                           --1
    '♥J','♥Q','♠Q','♣Q','♦Q',  '♦2','♥A','♠A','♣A','♦A',
  }


  self.firstPlayer = banker -- 发牌起始玩家

  -- 初始化作弊信息
  local function initCheatInfo(tabCards, gameBanker)
    local tabCheatInfo = {}
    local idx = #tabCards
    local curUser = gameBanker
    print("============ chear info ============")
    repeat
      local tabInfo = {}
      --tabInfo.bIsBanker = (curUser == banker)
      tabInfo.nChairIdx = curUser.chairIdx
      tabInfo.sNickName = curUser:getNickname()
      tabInfo.tabCards = {}
      for i = idx, idx - 4, -1 do
        table.insert(tabInfo.tabCards, tabCards[i])
      end
      idx = idx - 5
      tabCheatInfo[curUser:getUid()] = tabInfo
      curUser = curUser.next
    until(curUser == banker)
    dump(tabCheatInfo)
    return tabCheatInfo
  end
  self.tabCheatInfo = initCheatInfo(self.cards, self.firstPlayer)

  -- 发送作弊信息
  self:notifyCheatUser(self.tabCheatInfo)

  -- self.cards = {
  --   '♦A','♦Q','♦J','♦9','♦6','♦6','♦7','♦4','♦6','♦7',
  --   '♦A','♦Q','♦J','♦9','♦6','♦6','♦7','♦4','♦6','♦7',
  --   '♦A','♦Q','♦J','♦9','♦6','♦6','♦7','♦4','♦6','♦7',
  --   '♦A','♦Q','♦J','♦9','♦6','♦6','♦7','♦4','☆','★'
  -- }

  -- self.cards = {
  --   --8                           --7
  --   '♦A','♦Q','♦J','♦9','♦6',  '♦6','♥A','♠A','♣A','QA',
  --   --6                           --5
  --   '♦5','♦6','♦7','♦8','♣9',  '♦A','♦3','♦5','♦7','♦9',
  --   --4                           --3
  --   '♣J','♣K','♦K','♣Q','♦Q',  '♣Q','♥Q','♠K','♣K','♦K',
  --   --2                           --1
  --   '♥J','♥Q','♠Q','♣Q','♦Q',  '♦2','♥A','♠A','♣A','♦A',
  -- }

  self:broadcast(self.gName..'.start', {
    banker = banker:getUid(), 
    timeout = SHUFFLING_TIME, 
    curRound = self.deskStatus.number,
    })
end


function pGameplay:notifyCheatUser(tabCheatInfo)
  local mongo = self.app.mongo 
  if nil == mongo then return end
  for _, v in ipairs(self.game.players) do
    local cheatInfo = tabCheatInfo
    local uid = v:getUid()
    local nickname = v:getNickname()
    mongo:findOne("cheat", {uid = uid}, nil, nil, safe(function(err, dbuser)
      if (not err) and dbuser then
        print(string.format("===> send cheat info to uid: %s | name: %s", uid, nickname))
        self:send(v, self.gName..'.cheat', {cheatInfo = cheatInfo})
      end
    end))
  end
end


function pGameplay:runAllPlayersTrusteeship()
  for _, player in ipairs(self.game.players) do
    player:runTrusteeshipLogic(nil, true, true)
  end
end

function pGameplay:setWatcher(watcher)
  self.game:setWatcher(watcher)
end

function pGameplay:gotoFirstState()
  self:gotoState('Dealing')
end

function Starting:update(dt)
  if self:timeup(dt) then
    self:gotoFirstState()
  end
end

---------------------
-----Dealing state
---------------------
local Dealing = pGameplay:addState('Dealing')

function Dealing:enteredState()
  self.state = 'Dealing'
  self:broadcast(self.gName..'.deal')
  self.wait = 0
  --self.current = self.game.banker
  self.current = self.firstPlayer
end

function pGameplay:notifyDeal()
  for _, v in ipairs(self.game.players) do
    self:notifyPlayer(v)
  end
  if self.game.horse then
    self:send(self.game.horse, self.gName..'.dealt', {other = self:getOthers(), cardsCount = #self.cards})
  end

  if self.game.watcher then
    local others = self:getOthers()
    for _, v in pairs(self.game.watcher) do
      self:send(v, self.gName..'.dealt', {other = others, cardsCount = #self.cards})
    end
  end
end

function Dealing:update(dt)
  self:deal(self.current, self.CARD_COUNT)
  self.current = self.current.next
  --if self.current == self.game.banker then
  if self.current == self.firstPlayer then
    self:notifyDeal()

    if self:timeup(dt, DEALING_INTERVAL) then
      self:dealOver()
    end
  end
end

---------------------
-----Delay state
---------------------
local Delay = pGameplay:addState('Delay')
function Delay:enteredState(time, back)
  self.state = 'Delay'
  self.wait, self.back = time, back
end

function Delay:update(dt)
  if self:timeup(dt) then
    self:gotoState(self.back)
  end
end

---------------------
-----Ending state
---------------------
local Ending = pGameplay:addState('Ending')

function Ending:enteredState()
  self.state = 'Ending'
  print('game is over!')

  self.game:gameSummary()
  if self.game.option.gameplay == 1 then
    --self.game:updateBanker(self.game.banker)
    if #self.cards < 20 then
      self.game.option.cards = nil
    else
      self.game.option.cards = self.cards
    end
  elseif self.game.option.gameplay == 2 then
    if #self.cards < 20 then
      self.game.option.cards = nil
      self.game:updateBanker(self.game.banker.next)
    else
      self.game.option.cards = self.cards
      self.game:updateBanker(self.game.banker)
    end
  end

  self.wait = ENDING_TIME
end

function pGameplay:deal(player, count, notNew)
  for _ = 1, count do
    local c = self.cards[#self.cards]
    self.cards[#self.cards] = nil
    player.hand:add(c, notNew)
  end
end

function pGameplay:notifyPlayer(player)
  local uid = player:getUid()
  local other = {}
  for _, v in ipairs(self.game.players) do
    if v:getUid() ~= uid then
      local p = v.hand:package()
      p.uid = v:getUid()
      table.insert(other, p)
    end
  end

  --[[
  local bIsCheatUser = false
  local mongo = self.app.mongo
  if mongo then
    mongo:findOne("cheat", {uid = uid}, nil, nil, safe(function(err, dbuser)
      if not err then
        print(string.format("dbuser %s", dbuser))
        if dbuser then
          print(string.format("dbuser1 %s", dbuser))
          bIsCheatUser = (dbuser.right > 0)
        end
      end

      dump(player.hand:package(true), player:getUid())
      print(string.format("=======> uid: %s | isCheatUser %s", uid, bIsCheatUser))
      print("=======> advancedOption")
      dump(self.game.option.advanced)
      self:send(player,  -- 玩家
        self.gName..'.dealt', -- 游戏消息
          {hand=player.hand:package(true), 
          other = other, 
          cardsCount = #self.cards,
          advancedOption = self.game.option.advanced,
          })
      print("---------------------------------------------------")
    end))
  end
  ]]

  self:send(
    player,  -- 玩家
    self.gName..'.dealt', -- 游戏消息
    {
      hand=player.hand:package(true), 
      other = other, 
      cardsCount = #self.cards,
      advancedOption = self.game.option.advanced,
    }
  )
end

function pGameplay:getOthers()
  local other = {}
  for _, v in ipairs(self.game.players) do
    local p = v.hand:package()
    p.uid = v:getUid()
    table.insert(other, p)
  end

  return other
end

function pGameplay:start(banker)
  self:gotoState('Starting', banker)
end

function pGameplay:setHorse(user)
  self.game:setHorse(user)
end

function pGameplay:done()
  return (self.game.summary ~= nil) and (self.game.summaryEnd)
end

function pGameplay:summary()
  return self.game.summary
end

function pGameplay:basepackage()
  local game = {}
  --game.cardsCount = #self.cards
  game.state = self.state
  --game.hBuy = self.game.hBuy
  game.banker = self.game.banker:getUid()

  if self.current then
    game.cUid = self.current:getUid()
  end

  return game
end

function pGameplay:checkAction(p, c, gangUid)
  local actions = {}
  if (not p) or (not c) then
    print('call check action func error!!')
    return actions
  end

  if p.hand:canPeng(c) then
    if not actions.pList then actions.pList = {} end
    table.insert(actions.pList, c)
  end

  if p.hand:canGang(c, true) and #self.cards > self.minCardCnt then
    if not actions.gList then actions.gList = {} end
    table.insert(actions.gList, c)
  end

  if p.hand:canHu(c, gangUid) then
    print("can hu~~")
    if not actions.hList then actions.hList = {} end
    table.insert(actions.hList, c)
  end

  return actions
end

function pGameplay:checkTurnOver(next)
  if next == self.game.banker then
    self.game:overTurn()
  end
end

function pGameplay:getNext()
  local next = self.current.next
  self:checkTurnOver(next)

  while next.hand:ishupai() do
    next = next.next
    self:checkTurnOver(next)
  end
  return next
end

function pGameplay:turnPrint(player, c)
  print("###############################")
  print('now turn', player:getUid(), "get card",c)
  print('org hand is', player.hand:tostring(player.hand['#']))
  print('hand is', player.hand:tostring(player.hand:getHand()))
  print('peng or gang is')
  for _, v in pairs(player.hand['pg#']) do
    if v.peng then
      print(table.concat(v.peng.cards))
    elseif v.gang then
      print(table.concat(v.gang.cards))
    elseif v.chi then
      for _, k in ipairs(v.chi) do
        print(table.concat(k.cards))
      end
    end
  end
  print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end

return pGameplay
