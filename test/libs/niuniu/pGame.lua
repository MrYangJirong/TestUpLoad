local class = require('middleclass')
local pGame = class('pGame')
local table = require('table.addons')

function pGame:baseInit(players, option)
  local uids = {}
  for i, p in ipairs(players) do
    if not p:getUid() then error(('#%s player has no uid'):format(i)) end
    uids[p:getUid()] = p
  end
  self.uids = uids
  self.option = option
  self.turn = 0

  for i = 1, #players do
    if i == #players then
      players[i].next = players[1]
      players[1].prev = players[i]
    else
      players[i].next = players[i + 1]
      players[i + 1].prev = players[i]
    end

    if players[i + 2] then
      players[i].mate = players[i + 2]
      players[i + 2].mate = players[i]
    end
  end
  self.players = players
  self.summaryEnd = false
end

function pGame:getActPlayers(except)
  local p = {}
  for _, v in ipairs(self.players) do
    if v ~= except and not v.hand:ishupai() then
      table.insert(p, v:getUid())
    end
  end
  return p
end

function pGame:overTurn()
  self.turn = self.turn + 1
end

function pGame:allIsChoosed()
  local allcsd = true
  for _, v in ipairs(self.players) do
    if not v.hand:isChoosed() then
      allcsd = false
    end
  end
  return allcsd
end

function pGame:getTurn()
  return self.turn
end

function pGame:setWatcher(watcher)
  self.watcher = watcher
end

function pGame:numberOfPlayers()
  return #self.players
end

function pGame:initSummary()
  local summary = {}
  for _, v in ipairs(self.players) do
    local uid = v:getUid()
    summary[uid] = {}
    summary[uid].score = 0
    summary[uid].hand = v.hand['#']
    summary[uid].niuCnt = v.hand.niuCnt
    summary[uid].bIsBanker = (v == self.banker)
    summary[uid].nPutScore = (v == self.banker) and 0 or v.hand.putScore
    summary[uid].specialType = v.hand.specialType
  end

  if self.horse then
    local uid = self.horse:getUid()
    summary[uid] = {}
    summary[uid].score = 0
  end

  return summary
end

function pGame:getScore(hand, baseScore)
  local cnt = hand.niuCnt
  if cnt >= 0 and cnt <= 5 then
    return baseScore
  elseif cnt >= 6 and cnt <= 9 then
    return baseScore * 2
  else
    return baseScore * 4
  end
end

function pGame:getBaseScore()
  return 1
end

function pGame:bigThanThree(p1, _, _, _)
  if p1 == self.banker then
    return true
  else
    return false
  end
end

function pGame:bigThan(p1, p2)

  repeat
    -- 特殊牌判断
    if p1.hand.specialType > p2.hand.specialType then
      return true
    elseif p1.hand.specialType < p2.hand.specialType then
      return false
    end

    if p1.hand.specialType > 0 and p2.hand.specialType > 0 then
      break
    end

    -- 普通牛牛
    if p1.hand.niuCnt > p2.hand.niuCnt then
      return true
    elseif p1.hand.niuCnt < p2.hand.niuCnt then
      return false
    end
  until true

  -- 牌型相同情况
  local value = {
    ['A'] = 1,['2'] = 2,['3'] = 3,['4'] = 4,['5'] = 5,
    ['6'] = 6,['7'] = 7,['8'] = 8,['9'] = 9,
    ['T'] = 12,['J'] = 13,['Q'] = 14,['K'] = 15,
    ['☆'] = 10, ['★'] = 11
  }

  local suitValue = {
    ['♠'] = 4,['♥'] = 3,['♣'] = 2,['♦'] = 1
  }

  -- 比较 牛牛 五花牛 五小牛
  local function caseNIUNIU()
    local maxValue1 = 0
    local maxSuit1 = 0
    for i, _ in pairs(p1.hand['#']) do
      local tmpVal = value[p1.hand.Card:rank(i)]
      local tmpSuit = suitValue[p1.hand.Card:suit(i)]
      if tmpVal > maxValue1 or
        (tmpVal == maxValue1 and tmpSuit > maxSuit1)
      then
        maxValue1 = tmpVal
        maxSuit1 = tmpSuit
      end
    end

    local maxValue2 = 0
    local maxSuit2 = 0
    for i, _ in pairs(p2.hand['#']) do
      local tmpVal = value[p2.hand.Card:rank(i)]
      local tmpSuit = suitValue[p2.hand.Card:suit(i)]
      if tmpVal > maxValue2 or
        (tmpVal == maxValue2 and tmpSuit > maxSuit2)
      then
        maxValue2 = tmpVal
        maxSuit2 = tmpSuit
      end
    end

    if maxValue1 > maxValue2 then                           -- 比牌值
      return true
    elseif maxValue1 < maxValue2 then
      return false
    else
      --return self:bigThanThree(p1, p2, maxSuit1, maxSuit2)    -- 比花色
      return (maxSuit1 > maxSuit2)
    end
  end
  
  -- 比较炸弹
  local function caseBoom()
    local function getKeyCardVal(cardData)
      local lastVal = 0
      for i, _ in pairs(cardData) do
        local cardVal = value[p1.hand.Card:rank(i)]
        if cardVal == lastVal then
          return cardVal
        end
        lastVal = cardVal
      end
      return 0
    end

    local keyCardVal1 = getKeyCardVal(p1.hand['#'])
    local keyCardVal2 = getKeyCardVal(p2.hand['#'])

    return keyCardVal1 > keyCardVal2
  end

  if p1.hand.specialType == 2 then
    return caseBoom()
  else
    return caseNIUNIU()
  end
end

function pGame:compare(p1, p2)
  if self:bigThan(p1, p2) then
    local score = self:getScore(p1.hand, self:getBaseScore(p1, p2))
    if self.option.gameplay == 4 or self.option.gameplay == 7 then
      score = score * p1.hand.qiangCnt
    end
    self.summary[p1:getUid()].score = self.summary[p1:getUid()].score + score
    self.summary[p2:getUid()].score = self.summary[p2:getUid()].score - score
  else
    local score = self:getScore(p2.hand, self:getBaseScore(p1, p2))
    if self.option.gameplay == 4 or self.option.gameplay == 7 then
      score = score * p1.hand.qiangCnt
    end
    self.summary[p2:getUid()].score = self.summary[p2:getUid()].score + score
    self.summary[p1:getUid()].score = self.summary[p1:getUid()].score - score
  end
end

function pGame:compareResult()
  for _, v in ipairs(self.players) do
    if v ~= self.banker then
      self:compare(self.banker, v)
    end
  end
end

function pGame:updateMoney()
  for _, v in ipairs(self.players) do
    local uid = v:getUid()
    v:moneyChange(self.summary[uid].score)
    self.summary[uid].money = v:getMoney()
    v.hand = nil
  end
end

function pGame:baseGameSummary()
  dump(self.record)
  self.summary = self:initSummary()
  self:compareResult()

  self:updateMoney()
  --[[if self.horse then
    local uid = self.horse:getUid()
    self.horse:moneyChange(self.summary[uid].score)
    self.summary[uid].money = self.horse:getMoney()
  end]]
  print("=========结算=========")
  dump(self.summary)
  self.summaryEnd = true
end

function pGame:allQiang()
  local isAll = true

  for _, v in ipairs(self.players) do
    if not v.hand:isQiang() then
      isAll = false
    end
  end
  return isAll
end

function pGame:start(banker)
  assert(self:validPlayer(banker), ('players with uid %s are not in game'):format(banker:getUid()))
  self.banker = banker
  self.record = {}
  local Hand = require('niuniu.'..self.gName..'.Hand')

  for _, p in ipairs(self.players) do
    p.hand = Hand(self.option)
  end
end

function pGame:updateBanker(p)
  self.nextBanker = p
end

function pGame:validPlayer(player)
  return player ~= nil and player:getUid() ~= nil and self.uids[player:getUid()] ~= nil
end

function pGame:starter()
  local banker = assert(self.banker)
  return banker
end

return pGame
