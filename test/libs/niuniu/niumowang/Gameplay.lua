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
local pGameplay = require('niuniu.pGameplay')
local Gameplay = class('Gameplay', pGameplay)
local table = require('table.addons')

local TIME_QZ = 6000  --抢庄时间限制
local TIME_PUTMONEY = 9000
local TIME_PLAYING = 8000



function Gameplay:initialize(players, option, app)
  pGameplay.initialize(self)
  self.gName = 'niumowang'
  self.CARD_COUNT = 5
  self.minCardCnt = 0
  self:baseInit(players, option, app)
end

function Gameplay:getDealCards()
  self.cards = self.Card.shuffle(self.Card:newDecks(1))
end

function Gameplay:bad(player, what, e, gamestate)
  print('error', player:getUid(), what, "on", gamestate)
  self:send(player, 'error', {what=what})
  dump(e)
  --print(debug.traceback())
end

function Gameplay:on(p, e) -- luacheck: ignore
  self:bad(p, 'bad Gameplay state', e, 'none')
end

function Gameplay:gotoFirstState()
  if self.game.option.gameplay == 3 then
    self:gotoState('QiangZhuang')
  else
    self:gotoState('PutMoney')
  end
end

---------------------
-----QiangZhuang state
---------------------
local QiangZhuang = Gameplay:addState('QiangZhuang')

function QiangZhuang:enteredState()
  self.state = 'QiangZhuang'
  print('now need qiang zhuang!!')
  self:broadcast( self.gName..'.qiangZhuang' )
  self.wait = TIME_QZ
end

function Gameplay:findBigBanker()
  math.randomseed(os.clock())
  
  local max
  local maxValue = 0
  local key = 1
  for k, v in ipairs(self.game.players) do
    if v.hand.qiangCnt > maxValue then
      maxValue = v.hand.qiangCnt
      max = v
      key = k
    end
  end

  if maxValue ~= 0 then
    -- 比较是否有最大抢庄数相同的玩家
    local maxE = {}
    maxE[1] = max
    local index = 1
      for k, v in ipairs(self.game.players) do
      if key ~= k then
        if v.hand.qiangCnt == maxValue then
          index = index + 1
          maxE[index] = self.game.players[k]
        end
      end
    end

    print(1234567) 
    print(index)
    if index >= 2 then 
      local idx = math.random(1, #maxE)
      max = maxE[idx]
      print("随机生成的庄家charId为" .. idx)
      print("随机生成的庄家为" ..  max:getNickname())
      print(22222222)
    end
  end

  if not max then
    local idx = math.random(1, #self.game.players)
    max = self.game.players[idx]
    maxValue = 1
    self.game.players[idx].hand.qiangCnt = 1
  end

  self:broadcast( self.gName..'.newBanker', {uid = max:getUid(), number = maxValue} )
  self.game.banker = max
end

function QiangZhuang:on(p, e)
  if e.msgID == self.gName..'.qiang' then
    print(p:getUid(), ' qiang')
    if not e.number then
      e.number = 0
    end
    if p and p.hand then
      p.hand:setQiang(e.number)
      self:broadcast( self.gName..'.somebodyQiang',{uid = p:getUid(), number = e.number} )
    end
  end

  if self.game:allQiang() then
    self:findBigBanker()
    self:gotoState('PutMoney')
  end
end


function QiangZhuang:update(dt)
  if self:timeup(dt) then
    self:runAllPlayersTrusteeship()
  end
end


---------------------
-----PutMoney state
---------------------
local PutMoney = Gameplay:addState('PutMoney')

local function getNextPut(option, p)
  local nextPut
  if option.base == '1/2' then
    nextPut = {1,2}
  elseif option.base == '2/4' then
    nextPut = {1,2,3}
  elseif option.base == '4/8' then
    nextPut = {4,6,8}
  elseif option.base == '5/10' then
    nextPut = {6,8,10}
  elseif option.base == '1' then
    nextPut = {1,1}
  elseif option.base == '2' then
    nextPut = {2,2}
  elseif option.base == '4' then
    nextPut = {4,4}
  elseif option.base == '5' then
    nextPut = {5,5}
  elseif option.base == '8' then
    nextPut = {8,8}
  elseif option.base == '10' then
    nextPut = {10,10}
  end
  if p.nextPut then
    for k,v in pairs(p.nextPut) do
      table.insert( nextPut, v)
    end
    -- table.insert(nextPut, p.nextPut)
  end
  return nextPut
end

function PutMoney:enteredState()
  self.state = 'PutMoney'
  print('now is put money!!')
  self.puts = {}
  self:broadcast( self.gName..'.StartPuting' )

  if self.game.option.gameplay == 5 then
    for _, v in ipairs(self.game.players) do
      self.puts[v:getUid()] = true
      print('turn', v:getUid(), 'putMoney')
      self:send(v, self.gName..'.putMoney', {putInfo = getNextPut(self.game.option, v)})
      v.nextPut = nil
    end
  else
    for _, v in ipairs(self.game.players) do
      if v ~= self.game.banker then
        self.puts[v:getUid()] = true
        print('turn', v:getUid(), 'putMoney')
        self:send(v, self.gName..'.putMoney', {putInfo = getNextPut(self.game.option, v)})
        v.nextPut = nil
      end
    end
  end
  self.wait = TIME_PUTMONEY
end

function PutMoney:exitedState()
  self.puts = nil
end

function PutMoney:on(p, e)
  if not self.puts[p:getUid()] then
    print('not turn ', p:getUid())
    return false
  end
  if e.msgID == self.gName..'.puts' then
    print(p:getUid(), ' put')
    if not e.score or e.score < 0 then
      e.score = 1
    end
    p.hand:setScore(e.score)
    self.puts[p:getUid()] = nil
    self:broadcast( self.gName..'.somebodyPut',{uid = p:getUid(), score = e.score} )
  end

  if table.empty(self.puts) then
    self:gotoState('Dealing')
  end
end

function PutMoney:update(dt)
  if self:timeup(dt) then
    self:runAllPlayersTrusteeship()
  end
end

function Gameplay:dealOver()
  self:gotoState('Playing')
end




---------------------
-----Playing state
---------------------
local Playing = Gameplay:addState('Playing')

function Playing:enteredState()
  self.state = 'Playing'
  print('niu niu start playing')
  self:broadcast( self.gName..'.chooseCard' )
  self.wait = TIME_PLAYING
end

function Playing:exitedState()
end


function Playing:on(p, e)
  if p.hand:isChoosed() then
    print('player has choosed!')
    return
  end

  if e.msgID == self.gName..'.choosed' then
    print(p:getUid(), "choosed!!")
    p.hand:setChoosed()
    print(23232323)
    dump(p.hand.niuCnt)
    dump(self.game.banker)

    

    -- 如果是庄家 且 不是通比模式
    if (self.game.banker:getUid() == p:getUid()) and self.game.option.gameplay ~= 5 then
      print('是庄家, 不发送牌')
      self:broadcast( self.gName..'.someBodyChoosed',{uid = p:getUid()} )
    else
      self:broadcast( self.gName..'.someBodyChoosed',{uid = p:getUid(), cards = p.hand:all(), niuCnt = p.hand.niuCnt, specialType = p.hand.specialType} )
    end

  end
  if self.game:allIsChoosed() then
    self:gotoState('Ending')
  end
end

function Playing:update(dt)
  if self:timeup(dt) then
    self:runAllPlayersTrusteeship()
  end
end


function Gameplay:package()
  local game = self:basepackage()
  if self.state == 'Exchange' then
    game.exInfo = {}
    for _, v in pairs(self.game.players) do
      game.exInfo[v:getUid()] = v.hand:getExchange() and true or nil
    end
  end
  return game
end


return Gameplay
