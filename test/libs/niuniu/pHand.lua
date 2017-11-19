local table = require('table.addons')
local class = require('middleclass')
local array = require('array')
local pHand = class('pHand') -- cards in hand and analyzes

function pHand:baseInit(option)
  local Card = require('niuniu.'..self.gName..'.card')
  self.Card = Card()
  self.total = 0
  self['#'] = {}
  self.option = option
  self.Card:setOption(option)
  self.SPECIAL_EMUN = {
      WUXIAO = 7,
      BOOM = 6,
      HULU = 5,
      WUHUA_J = 2,
      WUHUA_Y = -1,
      TONGHUA = 3,
      STRAIGHT = 1,
  }
  self.CLIENT_SETTING = {
      WUXIAO = 7,
      BOOM = 6,
      HULU = 5,
      WUHUA_J = 2,
      WUHUA_Y = -1,
      TONGHUA = 3,
      STRAIGHT = 1,
  }
end

function pHand:addTo(arr, c)
  if not c then print(debug.traceback()) end
  arr[c] = not arr[c] and 1 or (arr[c]+1)
end

function pHand:setQiang(number)
  self.qiangCnt = number
end

function pHand:isQiang()
  return self.qiangCnt
end

function pHand:add(c, notNew)

  local function _add(sc, nNew)
    if nNew == nil then
      self.new = sc
    end
    self:addTo(self['#'], sc)
    self.total = self.total + 1
  end

  if type(c) ~= 'table'  then
    _add(c, notNew)
    return
  end
  for i=1,#c do
    _add(c[i], notNew)
  end
end

function pHand:rmForm(arr, c)
  arr[c] = arr[c] - 1
  if arr[c] == 0 then arr[c] = nil end
end

function pHand:remove(c)
  local function _rm(sc)
    local reg = self['#']
    if reg[sc] and reg[sc] > 0 then
      self:rmForm(reg, sc)
      self.new = nil
      self.total = self.total - 1
    end
  end

  if type(c) ~= 'table'  then
    _rm(c)
    return
  end
  for i=1,#c do
    _rm(c[i])
  end
end

function pHand:basePackage(ex)
  local hand = {}
  if ex then
    hand.hand = self['#']
  end
  hand.choosed = self.choosed or false
  hand.isQiang = self.qiangCnt or false

  return hand
end

function pHand:empty()
  return table.empty(self['#'])
end

function pHand:size()
  return self.total
end

function pHand:all()
  return self.Card.hashCountsToArray(self['#'])
end

function pHand:tostring(hash)
  return table.concat(self.Card:sort(self.Card.hashCountsToArray(hash)))
end

function pHand:isNiuniu(card)
  if #card > 3 then
    return false
  end
  local value = 0
  for _, v in ipairs(card) do
    if type(v) ~= 'string' then
      return false
    end
    value = value + self.Card:getVaule(v)
  end
  return (value % 10 == 0)
end

function pHand:findNiuniu()
  local cards = self.Card.hashCountsToArray(self['#'])
  local niunius = {}
  local cnt = #cards
  for i = 1, cnt - 2 do
    for j = i + 1, cnt - 1 do
      for x = j + 1, cnt do
        local value = self.Card:getVaule(cards[i]) + self.Card:getVaule(cards[j]) + self.Card:getVaule(cards[x])
        if (value % 10) == 0 then
          table.insert(niunius, {cards[i],cards[j],cards[x]})
        end
      end
    end
  end

  if table.empty(niunius) then
    return nil
  else
    return niunius
  end
end

function pHand:isChoosed()
  return self.choosed
end

function pHand:setChoosed(csd)
  if table.empty(csd) then
    self.choosed = csd
    self.niuCnt = 0
    return
  end
  self.choosed = csd
  local hand = table.copy(self['#'])
  for _, v in ipairs(self.choosed) do
    self:rmForm(hand, v)
  end

  self.niuCnt = 0
  for i, v in pairs(hand) do
    self.niuCnt = self.niuCnt + self.Card.CARDS[i] * v
  end

  self.niuCnt = self.niuCnt % 10
  if self.niuCnt == 0 then
    self.niuCnt = 10
  end

  if self.option['5flower5'] == 1 then
    local allFlower = true
    for i, _ in pairs(self['#']) do
      if not (self.Card:getVaule(i) == 10 and self.Card:rank(i) ~= 'T') then
        allFlower = false
      end
    end
    if allFlower then
      self.niuCnt = 11
    end
  end
end

function pHand:getMaxNiuCnt()
  local cards = self.Card.hashCountsToArray(self['#'])
  local sum = 0
  for i = 1, #cards do
    sum = sum + self.Card:getVaule(cards[i])
  end
  local niuCnt = sum % 10
  niuCnt = (niuCnt == 0) and 10 or niuCnt
  return niuCnt
end

function pHand:getSpecialType()
  if self.specialType > 0 then
    for key, val in pairs(self.SPECIAL_EMUN) do
      if val == self.specialType then
        return key, self.specialType
      end
    end
  end
end

function pHand:setSpecialType()
  local value = {
    ['A'] = 1,['2'] = 2,['3'] = 3,['4'] = 4,['5'] = 5,
    ['6'] = 6,['7'] = 7,['8'] = 8,['9'] = 9,
    ['T'] = 10,['J'] = 11,['Q'] = 12,['K'] = 13,
    ['☆'] = 14, ['★'] = 15
  }

  local tabHandSort = {}
  local tabHandVal = {} -- 牌值数组
  local tabHandSuit = {}

  local sum = 0   -- 牌值和  
  local isWUXIAO = true
  local isWUHUA_J = true
  local isWUHUA_Y = true
  local isTONGHUA = true

  local prevCard = {-1,""}
  for k,v in pairs(self['#']) do
    local cardVal = value[self.Card:rank(k)]
    local cardSuit = self.Card:suit(k)
    --{ [1]=val, [2]=suit}
    table.insert(tabHandSort, {cardVal, cardSuit})
    sum = sum + cardVal
    if cardVal > 4 then
      isWUXIAO = false
    end
    if cardVal < 11 then
      isWUHUA_J = false
    end
    if cardVal < 10 then
      isWUHUA_Y = false
    end
    if prevCard[2] ~= "" and prevCard[2] ~= cardSuit then
      isTONGHUA = false
    end
    prevCard = {cardVal, cardSuit}
  end

  table.sort(tabHandSort, function(a, b)
    return a[1] > b[1]
  end)

  for k,v in pairs(tabHandSort) do
    table.insert( tabHandVal, v[1] )
    table.insert( tabHandSuit, v[2] )
  end

  print("CARDDATA")
  dump(tabHandVal)
  local function isEnabled(type)
    if type > 0 then
      if self.option.special[type] and self.option.special[type] > 0 then
        return true
      end
    end
    return false
  end

  local set = self.CLIENT_SETTING
  print("CLIENTSETTING")
  dump(set)
  dump(self.option.special)
  local spEmun = self.SPECIAL_EMUN
  local type = 0
  repeat
    -- 五小牛
    if isWUXIAO and sum <= 10 and
    isEnabled(set.WUXIAO)
    then
      type = spEmun.WUXIAO
      break
    end
    
    -- 炸弹牛
    if(tabHandVal[1] == tabHandVal[4] or
    tabHandVal[2] == tabHandVal[5]) and
    isEnabled(set.BOOM)
    then
      type = spEmun.BOOM
      break
    end
    
    -- 葫芦牛
    if((tabHandVal[1] == tabHandVal[3] and tabHandVal[4] == tabHandVal[5]) or
    (tabHandVal[1] == tabHandVal[2] and tabHandVal[3] == tabHandVal[5])) and
    isEnabled(set.HULU)
    then
      type = spEmun.HULU
      break
    end
    
    -- 同花
    if isTONGHUA and
    isEnabled(set.TONGHUA)
    then
      type = spEmun.TONGHUA
      break
    end
    
    -- 五花牛 金牛
    if isWUHUA_J and
    isEnabled(set.WUHUA_J)
    then
      type = spEmun.WUHUA_J
      break
    end
    
    -- 金牛
    if isWUHUA_Y and
    isEnabled(set.WUHUA_Y)
    then
      type = spEmun.WUHUA_Y
      break
    end
    
    -- 顺子
    local t = tabHandVal
    if t[1] == t[2] + 1 and
    t[2] == t[3] + 1 and
    t[3] == t[4] + 1 and
    t[4] == t[5] + 1 and
    isEnabled(set.STRAIGHT)
    then
      type = spEmun.STRAIGHT
      break
    end 

  until true
  

  self.specialType = type
end

return pHand
