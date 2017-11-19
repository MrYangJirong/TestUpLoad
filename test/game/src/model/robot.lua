local class = require('middleclass')
local user = require('./user')
local robot = class('robot',user)
local Mongo = require('luvit-mongodb')

function robot:initialize(app)
  local uid = tostring('R'..tostring(Mongo.ObjectId.new()))
  user.initialize(self,app,uid)
  self.avatar = (math.random(4) - 1)..''

  self.diamond = 0
  self.money = 200000
  self.playerId = 99999
end

function robot:isBot()
  return true
end

function robot:clearGames()
  self.deskId = nil
  self.buyHorse = nil
  self.goldId = nil
  self:setAgent(nil)
  self:setBusy(false)
end

function robot:getUid()
  return self.uid
end

function robot:isBusy()
  return self._isBusy
end

function robot:setBusy(b)
  self._isBusy = b
end

function robot:onDelete()
end

--function robot:onAgentFinalize()
--  self.emitter:emit('onAgentFinalize')
--end

function robot:updateRes(key, value)
  self[key] = self[key] + value
  if self[key] < 0 then
    self[key] = 0
  end
end

function robot:isOnline()
  return true
end

function robot:postSummary()
  user.postSummary(self)
end

return robot
