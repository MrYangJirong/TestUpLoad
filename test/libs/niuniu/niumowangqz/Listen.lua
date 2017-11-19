local class = require('middleclass')
local mjcommon = require('niuniu.pListen')
local Listen = class('Listen', mjcommon)
function Listen:initialize(app)
  mjcommon.initialize(self)
  self.app = app
  self.pre = 'niumowangqz.'
  self:listen(app)
end

return Listen
