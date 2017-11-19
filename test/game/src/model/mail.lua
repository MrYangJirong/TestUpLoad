local class = require('middleclass')
local HasSignals = require('game/src/HasSignals')
local Mail = class('Mail'):include(HasSignals)

function Mail:initialize(user)
  HasSignals.initialize(self)

  self.user = user
  self.mails = {}

  --[[
  self:pushMail({
    content = 'test test',
    title = 'test'
  })]]
end

function Mail:send(data,dontDB)
  return self:pushMail(data,dontDB)
end

function Mail:packageForDB(insert) -- luacheck: ignore
end

function Mail:packageForNet(package)
  package.mails = self.mails
end

function Mail:initFromDB(db)
  if db.mails then self.mails = db.mails end

  if self.mails then
    for i = 1,#self.mails do
      self.mails[i].oid = tostring(self.mails[i].oid)
    end
  end
end

function Mail.push2db(mongo,uid,mail)
  mongo:update('user',{uid=uid}, {['$push'] = {mails = mail}},false,true, function()
  end)
end

function Mail.syn2DB(mongo,uid,mails)
  mongo:update('user',{uid=uid}, {['$set'] = {mails = mails}},false,true, function()
  end)
end

function Mail:pushMail(mail,dontDB)
  local mongo = self.user.app.mongo
  mail.oid = tostring(mongo.ObjectId.new())
  mail.isread = false

  self.mails[#self.mails + 1] = mail
  if not dontDB then
    Mail.push2db(mongo,self.user.uid,mail)
  end

  return mail
end

function Mail:pullMail(idx)
  local mail = self.mails[idx]
  if mail then
    table.remove(self.mails,idx)
    self.user.app.mongo:update('user',{uid=self.user.uid}, {['$pull'] = {mails = {oid=mail.oid}}},false,true, function()
    end)
  end
end

function Mail:getMailByOid(oid)
  for i = 1,#self.mails do
    if self.mails[i].oid == oid then
      return self.mails[i],i
    end
  end
end

function Mail:readMail(msg)
  local oid = msg.oid
  local ok = false
  if oid then
    local mail,idx = self:getMailByOid(oid)
    if mail then
      mail.isread = true
      if not mail.bean and not mail.diamond then
        self:pullMail(idx)
        ok = true
      else
        Mail.syn2DB(self.user.app.mongo,self.user.uid,self.mails)
      end
    end
  end

  local rep = {
    msgID = 'readMail',
    ok = ok,
    oid = oid
  }

  self.user:sendMsg(rep)
end

function Mail:getMailPrize(msg)
  local mailIdx = msg.mailIdx
  local mail = self.mails[mailIdx]
  if mail then
    if mail.bean then
      self.user:addMoney(mail.bean)
    end

    if mail.diamond then
      self.user:updateRes('diamond',mail.diamond)
    end

    self:pullMail(mailIdx)
  end

  local rep = {
    msgID = 'getMailPrize',
    money = self.user.money,
    diamond = self.user.diamond
  }

  self.user:sendMsg(rep)
end

return Mail
