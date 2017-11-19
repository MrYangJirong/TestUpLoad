local class = require('middleclass')
local mjAgent = require('niuniu.pAgent')
local Agent = class('Agent', mjAgent)

function Agent:initialize(app,user)
  mjAgent.initialize(self)
  self.gName = 'niumowang'
  self:init(app, user)
end

return Agent
