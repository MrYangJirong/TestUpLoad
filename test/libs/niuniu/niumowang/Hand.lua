local class = require('middleclass')
local pHand = require('libs.niuniu.pHand')
local Hand = class('Hand', pHand) -- cards in hand and analyzes

function Hand:initialize(option)
  pHand.initialize(self)
  self.gName = 'niumowang'
  self:baseInit(option)
end

function Hand:package(ex)
  local hand = self:basePackage(ex)
  hand.putScore = self.putScore
  return hand
end

function Hand:setChoosed()
  self:setSpecialType()
  local cards = self:findNiuniu()
  if cards then
    self.choosed = cards[1]
    self.niuCnt = self:getMaxNiuCnt()
    -- for _, v in ipairs(cards) do
    --   local hand = table.copy(self['#'])
    --   for _, u in ipairs(v) do
    --     self:rmForm(hand, u)
    --   end
    --   local max = 0
    --   for i, u in pairs(hand) do
    --     max = max + self.Card.CARDS[i] * u
    --   end
    --   max = max % 10
    --   if not self.niuCnt then
    --     self.niuCnt = max
    --     self.choosed = v
    --   elseif max > self.niuCnt then
    --     self.niuCnt = max
    --     self.choosed = v
    --   end
    --   if self.niuCnt == 0 then
    --     self.niuCnt = 10
    --   end
    -- end
  else
    self.choosed = {}
    self.niuCnt = 0
  end
end

function Hand:setScore(score)
  self.putScore = score
end

return Hand
