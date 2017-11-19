local table = require('table.addons')
local class = require('middleclass')
local pCard = require('libs.niuniu.pCard')
local card = class('card', pCard)

function card:initialize()
  pCard.initialize(self)
  self.gName = 'niumowang'

  self.CARDS = { -- nature order, used to find tractors
    ['♦A'] = 1,['♦2'] = 2,['♦3'] = 3,['♦4'] = 4,['♦5'] = 5,
    ['♦6'] = 6,['♦7'] = 7,['♦8'] = 8,['♦9'] = 9,
    ['♦T'] = 10,['♦J'] = 10,['♦Q'] = 10,['♦K'] = 10,
    ['♣A'] = 1,['♣2'] = 2,['♣3'] = 3,['♣4'] = 4,['♣5'] = 5,
    ['♣6'] = 6,['♣7'] = 7,['♣8'] = 8,['♣9'] = 9,
    ['♣T'] = 10,['♣J'] = 10,['♣Q'] = 10,['♣K'] = 10,
    ['♥A'] = 1,['♥2'] = 2,['♥3'] = 3,['♥4'] = 4,['♥5'] = 5,
    ['♥6'] = 6,['♥7'] = 7,['♥8'] = 8,['♥9'] = 9,
    ['♥T'] = 10,['♥J'] = 10,['♥Q'] = 10,['♥K'] = 10,
    ['♠A'] = 1,['♠2'] = 2,['♠3'] = 3,['♠4'] = 4,['♠5'] = 5,
    ['♠6'] = 6,['♠7'] = 7,['♠8'] = 8,['♠9'] = 9,
    ['♠T'] = 10,['♠J'] = 10,['♠Q'] = 10,['♠K'] = 10,
    --['☆'] = 10, ['★'] = 10,
  }
end

return card
