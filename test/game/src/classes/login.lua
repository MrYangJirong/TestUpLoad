local class = require('middleclass')
local User = require('../model/user')
local Login = class('Login')
local Mongo = require('luvit-mongodb')
local safe = require('game.src.safe')
local Versions = require('../setting/versions')

function Login:initialize(app)
  self.app = app

  app:on('genUid',function(socketID, _)
    self:genUid(socketID)
  end)

  app:on('signin',function(socketID,msg)
    self:signin(socketID,msg)
  end)
end

function Login:genUid(socketID)
  local msg = {
    msgID = 'genUid',
    uid = tostring(Mongo.ObjectId.new())
  }

  self.app:sendMsg(socketID,msg)
end

function Login:signinError(socketID,errorCode)
  local rep = {
    msgID = 'signinResult',
    success = false,
    errorMsg = errorCode
  }

  self.app:sendMsg(socketID,rep)
end

function Login:reponse2Client(socketID,user,msg)
  local rep = {
    msgID = 'signinResult',
    success = true
  }
  if user.socketID and user.socketID ~= socketID then
    self.app:disconnectPeer(user.socketID)
  end
  -- self.app.actives[socketID] = user
  self.app:addActives(socketID, user)
  user.socketID = socketID
  if msg.nickName then
    user.nickName = msg.nickName
  end
  if msg.sex then
    user.sex = msg.sex
  end
  if msg.avatar then
    user.avatar = msg.avatar
  end
  self.app.mongo:update('user',{uid=user.uid},
    {['$set'] = {loginTime = os.time(), online = true, sex = user.sex,nickName = user.nickName,avatar = user.avatar}},
    nil,true, safe(function()
  end))

  local package = {}
  package.user = {}
  package.allGames = {}

  user:packageForNet(package.user)

  rep.package = package
  if msg.new then
    rep.new = true
  end
  self.app:sendMsg(socketID,rep)
end

function Login:signin(socketID,msg)
  local uid = msg.uid

  if not uid then
    return
  end

  -- 首先检测版本号
  if msg.channel and msg.cppVersion then
    local version = Versions[msg.channel]
    if version then
      if version ~= msg.cppVersion then
        self:signinError(socketID,'版本不匹配，请下载最新的安装包')
        return
      end
    end
  end

  local user = self.app.users[msg.uid]
  local mongo = self.app.mongo
  local query = {uid = uid}

  mongo:findOne("user", query,nil, nil, safe(function(err, dbuser)
    if not err then
      if dbuser and dbuser.status and dbuser.status == "-1" then
        self.app:disconnectPeer(socketID)
        return
      end
      if user then
        user:initFromDB(dbuser)
        self:StatisticsLogin(uid,user.channel,user.nickName)
        self:reponse2Client(socketID,user,msg)
      else
        if not dbuser  then
          self:newUser(socketID,uid,function(tuser)
            msg.new = true
            self:reponse2Client(socketID,tuser,msg)
          end)
        else
          user = User(self.app,uid)
          user:initFromDB(dbuser)

          self.app.users[uid] = user
          self:reponse2Client(socketID,user,msg)
          self:StatisticsLogin(uid,user.channel,user.nickName)
        end
      end
    end
  end))
end

function Login:newUser(socketID,uid,call)
  if self.app.users[uid] then
    print('user exist!')
    return
  end
  local user = User(self.app,uid)
  self.app.users[uid] = user
  self.app.actives[socketID] = self.app.users[uid]
  -- self.app:addActives(socketID, self.app.users[uid])
  user.socketID = socketID

  local insert = {}
  user:packageForDB(insert)
  local mongo = self.app.mongo

  mongo:findOne("citySetting", {key='citySetting'}, nil, nil, safe(function(err, res)
    if not err then
      if not res then
        mongo:insert("citySetting", {key = 'citySetting', registCount = 100000}, nil, safe(function(cerr, _)
          if not cerr then
            insert.playerId = 100000
            mongo:insert("user", insert, nil, function(uerr, _)
              if not uerr then
                user.playerId = 100000
                call(user)
              end
            end)
          end
        end))
      else
        res.registCount = res.registCount + 1

        mongo:update("citySetting",{key='citySetting'}, {["$set"] = {registCount = res.registCount}}, true,nil, safe(function(cerr, _)
          if not cerr then
            insert.playerId = res.registCount
            mongo:insert("user", insert, nil, safe(function(uerr, _)
              if not uerr then
                user.playerId = res.registCount
                call(user)
              end
            end))
          end
        end))
      end
    end
  end))
  self:StatisticsRegister(uid,user.channel)
end

function Login:StatisticsRegister(uid,channel)
  local mongo = self.app.mongo
  mongo:insert("register", {uid = uid,create_at=os.time(),channel=channel}, nil, safe(function(_, _)end))
end

function Login:StatisticsLogin(uid,channel,nickName)
  local mongo = self.app.mongo
  mongo:insert("login", {uid = uid,create_at=os.time(),nickName=nickName,channel=channel}, nil, safe(function(_, _)end))
end

return Login
