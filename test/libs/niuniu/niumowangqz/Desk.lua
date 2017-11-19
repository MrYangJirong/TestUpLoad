local class = require('middleclass')
local HasSignals = require('game.src.HasSignals')
local mjDesk = require('niuniu.pDesk')
local Desk = class('Desk', mjDesk):include(HasSignals)

function Desk:initialize(app,deskInfo, deskId)
  HasSignals.initialize(self)
  mjDesk.initialize(self)
  self.gName = 'niumowangqz'
  self:init(app, deskInfo,deskId)
end

function Desk:isPlayOver()
  if self.deskInfo.round == 100 then
    if self.number > self.deskInfo.maxPeople * 5 then
      return true
    end
  else
    if self.number > self.deskInfo.round then
      return true
    end
  end
end

return Desk
