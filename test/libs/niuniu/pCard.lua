local class = require('middleclass')
local pCard = class('pCard')
local array = require('array')
local table = require('table.addons')

local SUIT_UTF8_LENGTH = 3 -- length of '大', '小' are all 3 bytes in utf-8.

function pCard:setOption(option)
  self.option = option
end

function pCard:rank(c)
  if not c then print(debug.traceback()) end
  if c == '☆' or c == '★' then
    return c
  end
  return #c > SUIT_UTF8_LENGTH and c:sub(SUIT_UTF8_LENGTH + 1, -1) or nil
end

function pCard:suit(c)
  if not c then print(debug.traceback()) end
  if c == '☆' or c == '★' then
    return c
  else
    return #c > SUIT_UTF8_LENGTH and c:sub(1, SUIT_UTF8_LENGTH) or nil
  end
end

function pCard.hashCountsToArray(hash)
  local a = {}
  for k, v in pairs(hash) do
    for _=1,v do
      a[#a + 1] = k
    end
  end
  return a
end

function pCard.shuffle(cards)
  array.shuffle(cards)
  return cards
end

function pCard:exist(c)
  return self.CARDS[c]
end

function pCard:sort(cards)
  local function orderTractorLess(a, b)
    return self.CARDS[a] < self.CARDS[b]
  end
  table.sort(cards, orderTractorLess)
  return cards
end

function pCard:all()
  return table.keys(self.CARDS)
end

function pCard:newDecks(n, option)
  return array.dup(self:all(option), n)
end

function pCard:getVaule(c)
  return self.CARDS[c]
end

return pCard
