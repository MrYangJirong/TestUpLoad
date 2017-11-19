local class = require('middleclass')
local social = class('social')

function social:initialize(app)
  self.app = app
  app:on('getFriends',function(socketID,msg)
    self:getFriends(socketID,msg)
  end)
  app:on('deleteFriend',function(socketID,msg)
    self:deleteFriend(socketID,msg)
  end)
  app:on('addFriend',function(socketID,msg)
    self:addFriend(socketID,msg)
  end)
  app:on('acceptFriend',function(socketID,msg)
    self:acceptFriend(socketID,msg)
  end)
  app:on('refuseFriend',function(socketID,msg)
    self:refuseFriend(socketID,msg)
  end)
end
function social:getFriends(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:getFriends(msg)
  end
end

function social:acceptFriend(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:acceptFriend(msg.uid)
  end
end

function social:refuseFriend(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:refuseFriend(msg.uid)
  end
end

function social:addFriend(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:addRequeset(msg.uid)
  end
end
function social:deleteFriend(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:deleteFriend(msg.uid)
  end
end

return social
