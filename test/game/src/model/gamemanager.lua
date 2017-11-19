local HasSignals = require('../HasSignals')
local class = require('middleclass')
local GameManager = class('GameManager'):include(HasSignals)
local Game = require('../model/game')

function GameManager:initialize(app)
  HasSignals.initialize(self)
  self.app = app
  self.allGamesCfg = require('../setting/AllGames')
  self.coinCfg = require('../setting/CoinGames')
  self.allGames = {}
  self:initGames()
end

function GameManager:initDataFromDB()
  for _, v in pairs(self.allGames) do
    v:initDataFromDB()
  end
end

function GameManager:initGames()
  for i, v in pairs(self.allGamesCfg) do
    self.allGames[i] = Game(self.app, v, self.coinCfg[i], self)
    self:registerListener(self.allGames[i])
  end
end

function GameManager:registerListener(game)
  local function onDelDesk(deskId)
    self.emitter:emit('onDelDesk', deskId)
  end
  game:on('onDelDesk', onDelDesk)
end

function GameManager:getGame(idx)
  local game = self.allGames[tostring(idx)]
  if game then
    return self.allGames[tostring(idx)]
  else
    print('not this game for index is', idx)
  end
end

function GameManager:findDeskBy(id)
  for i, v in pairs(self.allGames) do
    local desk = v.allDesks[id]
    if desk then
      return desk, tonumber(i)
    end
  end
end

function GameManager:findPlayerInDesks(uid)
  for _, v in pairs(self.allGames) do
    for _, desk in pairs(v.allDesks) do
      for _, sit in ipairs(desk.allChairs) do
        if sit.agent and sit.agent:getUid() == uid then
          return desk, false
        end
      end
      if desk.horse then
        if desk.horse:getUid() == uid then
          return desk, false
        end
      end
    end

    for _, desk in pairs(v.goldDesks) do
      for _, sit in ipairs(desk.allChairs) do
        if sit.agent and sit.agent:getUid() == uid then
          return desk, true
        end
      end
    end
  end
end

function GameManager:findGoldDeskBy(id)
  for i, v in pairs(self.allGames) do
    local desk = v.goldDesks[id]
    if desk then
      return desk, tonumber(i)
    end
  end
end

function GameManager:update(dt)
  for _, v in pairs(self.allGames) do
    v:update(dt)
  end
end

function GameManager:sitdown(user,msg)
  local game = self.allGames[tostring(msg.gameIdx)]
  if game then
    game:sitdown(user,msg)
  else
    print(msg.gameIdx, ' game index not exist!!')
  end
end

function GameManager:createDesk(user, msg)
  
end

return GameManager
