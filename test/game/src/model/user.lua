local class = require('middleclass')
local HasSignals = require('game/src/HasSignals')
local User = class('User'):include(HasSignals)
local Mail = require('game/src/model/mail')
local robotName = require('game/src/model/robotName')
local Mongo = require('luvit-mongodb')
local safe = require('game.src.safe')

function User:initialize(app,uid)
  HasSignals.initialize(self)

  self.app = app
  self.uid = uid
  self.nickName = uid
  self.avatar = ""
  self.sex = 0
  self.diamond = 10
  self.gold = 1000
  self.win = 0
  self.lose = 0
  self.winrate = 0
  self.buyDiamondCnt = 0
  self.sendDiamond = 0
  self.todaySendCount = 0
  self.todaySends = {}
  self.secondsFrom1970 = 0
  self.invitePrize = 0
  self.status = "1"
  self.mail = Mail(self)
  self.vip = 0

  self.lastSharePrizeWeek = -1

  self.signPrizeForDay = true

  ---not used
  self.zhuanpan = true

  local firstName = robotName.firstName[math.random(#robotName.firstName)]
  local lastName = robotName.lastName[math.random(#robotName.lastName)]
  local name = firstName..lastName
  self.nickName = name
end

function User:runZhuanpan(msg)
  self.zhuanpan = false
  if not msg.noZhuan then
    local rep = {
      msgID = 'runZhuanpan',
      number = math.random(12)
    }
    self:sendMsg(rep)
  end
  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {zhuanpan = self.zhuanpan}},nil,true, function()end)
end

function User:exchange(number)
  if number < 0 then
    return
  end
  local rep = {msgID = 'exchange'}
  if self.diamond < number then
    rep.errorCode = 1
    self:sendMsg(rep)
  else
    self:updateRes('diamond', -number)
    self:updateRes('gold', number * 1000)
  end
end

local vip_map = {
  {0,0},
  {1000,0.02},
  {2000,0.05},
  {5000,0.1},
  {10000,0.15},
  {20000,0.2},
  {50000,0.3},
}

function User:getVIPFactorByVip()
  if not self.vip then return end

  local factor = vip_map[self.vip+1][2]
  return factor
end

function User:calcVIP()
  local buyDiamondCnt = self.buyDiamondCnt
  for i = #vip_map,1,-1 do
    local data = vip_map[i]

    if buyDiamondCnt >= data[1] then
      return data[2],i
    end
  end

  return 0
end

function User:getVIPLevel()
  local _,vipIdx = self:calcVIP()
  local vip = vipIdx - 1
  if self.vip and self.vip > vip then
    vip = self.vip
  end

  return vip
end

function User:paySuccess(msg)
  local gem = msg.gem
  local factor = self:calcVIP()
  local factor1 = self:getVIPFactorByVip()
  if factor1 then
    if factor1 > factor then
      factor = factor1
    end
  end

  local addByVIP = math.floor(gem * factor)
  gem = gem + addByVIP

  self:updateRes('diamond', math.floor(gem))
  self:updateBuyDiamondCnt(msg.rmb)
end

function User:getUid()
  return self.uid
end

function User:listRooms()
  local rep = {
      msgID = 'listRooms'
    }

  local tabDeskId = {}
  local tabQuery = {}
  -- todo:联表查询


  local function getRooms()
    self.app.mongo:find("rooms", tabQuery,{}, nil, nil, function(err, res)
        if not err then
          if #res > 0 then
            local rooms = {}
            for _,v in ipairs(res) do
              local room = {}
              room.deskId = v.deskId
              room.round = v.round
              room.maxActors = v.maxActors
              room.game = v.game
              room.options =  v.options
              local desk = self.app.gameMgr:findDeskBy(v.deskId)
              if desk then
                room.actors = desk:getChairCnt()
              else
                room.actors = 0
              end
              table.insert(rooms, room)
            end
            rep.rooms = rooms
            self:sendMsg(rep)
            return
          end
          self:sendMsg(rep)
          return
        end
      end)
  end


  self.app.mongo:find(
    "joinRecord",
    {playerUid = self.uid},
    {},nil,nil,
    function(err, res)
      if not err then
        for _,v in ipairs(res) do
          table.insert(tabDeskId, v.deskId)
        end
      end

      if #tabDeskId >0 then
        tabQuery = {
          ['$or'] = {
            {owner = self.playerId},
            {deskId = {['$in'] = tabDeskId}}
          }
        }
      else
        tabQuery = {owner = self.playerId}
      end
      getRooms()
    end
  )
end

function User:clearReq(uid)
  local info = nil
  for i,v in ipairs(self.reqFriends) do
    if v.uid == uid then
      table.remove(self.reqFriends, i)
      info = v
    end
  end

  if info then
    self:opMongo({uid=self.uid}, {['$pull'] = {reqFriends = {uid = uid}}}, function(_,err)
      if err and err ~= "" then
        print(err)
      end
    end)
  end

  return info
end

function User:giveRes(resName, playerId, value)
  if not self[resName] then
    print('not this res')
    return
  end

  local rep = {
    msgID = 'giveRes',
  }

  if self[resName] < value then
    print('res not enough')
    rep.errorCode = 1
    self:sendMsg(rep)
    return
  end


  local sendLimit = {800,1200,2200,5000,10000,20000}
  local sendSingleLimit = {50,80,160,220,280,360}
  local _, vipIdx = self:calcVIP()
  if self.vip and self.vip+1 > vipIdx then
    vipIdx = self.vip+1
  end

  vipIdx = vipIdx - 1
  if vipIdx >= 1 then
    if self.todaySendCount + value > sendLimit[vipIdx] then
      print('big limit!!')
      rep.errorCode = 3
      self:sendMsg(rep)
      return
    end

    if self.todaySends[playerId] then
      if self.todaySends[playerId] + value > sendSingleLimit[vipIdx] then
        print('big single limit!!')
        rep.errorCode = 4
        self:sendMsg(rep)
        return
      end
    else
      self.todaySends[playerId] = 0
    end
  else
    return
  end

  self.app.mongo:findOne("user", {playerId = playerId},{nickName = 1, uid = 1, [resName]=1}, nil, function(err, dbuser)
    if not err then
      if dbuser then
        if self.app.users[dbuser.uid] then
          local msg = {msgID = 'somebodyGive', nickName = dbuser.nickName,
          resName = resName, now = dbuser[resName] + value, inc = value}
          self.app.users[dbuser.uid]:sendMsg(msg)
        end
        self.app.mongo:update('user',{playerId=playerId}, {['$set'] = {[resName] = dbuser[resName] + value}},nil,true, function(_)
        end)
        self:updateRes(resName, -value)

        self.todaySendCount = self.todaySendCount + value
        self.todaySends[playerId] = self.todaySends[playerId] + value
        self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {todaySendCount = self.todaySendCount}},nil,true, function(_)
        end)

        self:sendMsg(rep)
      else
        rep.errorCode = 2
        self:sendMsg(rep)
      end
    end
  end)
end

function User:getInfoByUids(uids)
  if next(uids) == nil then
    local msg = {
      msgID = 'getInfoByUids',
      data = {}
    }

    self:sendMsg(msg)
    return
  end

  local idx = 1
  local rep  = {}

  local function queryFromDB(uid)
    self.app.mongo:find("user", {uid = uid},{uid=1,nickName=1,avatar=1,weekWinBean=1}, nil, nil, function(err, res)
      local data = {
        nickName = '',
        avatar = '0',
        weekWinBean = 0,
        uid = uid
      }
      if not err and #res > 0 then
        data = res[1]
      end

      rep[idx] = data

      idx = idx + 1
      if idx < #uids then
        queryFromDB(uids[idx].uid)
      else
        local msg = {
          msgID = 'getInfoByUids',
          data = rep
        }

        self:sendMsg(msg)
      end
    end)
  end

  queryFromDB(uids[idx].uid)
end

function User.pushFriednRequset2db()
end

function User:setWeekWinBean(num,dontdb)
  self.weekWinBean = num

  if not dontdb then
    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {weekWinBean = self.weekWinBean}},nil,true, function()
    end)
  end
end

function User:rankTodayWin(num)
  self.todayWinBean = self.todayWinBean + num
  self.weekWinBean = self.weekWinBean + num

  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {todayWinBean = self.todayWinBean,weekWinBean = self.weekWinBean}},nil,true, function()
  end)

  if not self.isBot() then
    self.app.leaderboard:updatePlayerScore(self.uid,self.nickName,self.avatar,self.todayWinBean)
  end
end

function User:updateSendDiamond()
  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {sendDiamond = self.sendDiamond}},nil,true, function()
  end)
end

function User:updateRes(key, value)
  if value == 0 then
    return
  end
  self[key] = self[key] + value
  if self[key] < 0 then
    self[key] = 0
  end
  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {[key] = self[key]}},nil,true, function(_)
  end)
  local rep = {msgID = 'updateRes', key = key, value = self[key]}
  self:sendMsg(rep)
end

function User:updateBuyDiamondCnt(add)
  self.buyDiamondCnt = self.buyDiamondCnt + add
  local _,vipIdx = self:calcVIP()
  if vipIdx-1 > self.vip then
    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {['buyDiamondCnt'] = self.buyDiamondCnt,vip=vipIdx-1}},nil,true, function(_)
    end)
  end

  local rep = {
    msgID = 'buyDiamondCntUpdate',
    buyDiamondCnt = self.buyDiamondCnt
  }
  self:sendMsg(rep)
end

function User:getRes(key)
  return self[key]
end

function User:onDelete()
  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {online = false}},nil,true, function()
  end)
  self.emitter:emit('onLogout')
end

function User:opMongo(who, act, rcall)
  self.app.mongo:update("user", who, act, nil, true,function(_, _)
    rcall()
  end)

  --[[
  local bsonObj = Mongodb.new()
  Mongodb.initQuery(bsonObj,who)
  Mongodb.initOp(bsonObj, act)
  Mongodb.update(bsonObj,rcall)]]
end

function User:sendMsg(msg)
  if self.socketID then
    self.app:sendMsg(self.socketID,msg)
  else
    print("user:sendMsg socketID nil")
    dump(msg)
  end
end

function User:synGPS(msg)
  self.xpos = msg.x
  self.ypos = msg.y
end

function User:initFromDB(db)
  if db.uid ~= nil then self.uid = db.uid end
  if db.nickName ~= nil then self.nickName = db.nickName end
  if db.avatar ~= nil then self.avatar = db.avatar end
  if db.sex ~= nil then self.sex = db.sex end
  if db.diamond ~= nil then self.diamond = db.diamond end
  if db.buyDiamondCnt ~= nil then self.buyDiamondCnt = db.buyDiamondCnt end
  if db.gold ~= nil then self.gold = db.gold end
  if db.secondsFrom1970 ~= nil then self.secondsFrom1970 = db.secondsFrom1970 end
  if db.win ~= nil then self.win = db.win end
  if db.lose ~= nil then self.lose = db.lose end
  if db.winrate ~= nil then self.winrate = db.winrate end
  if db.playerId ~= nil then self.playerId = db.playerId end
  if db.deskId ~= nil then self.deskId = db.deskId end
  if db.buyHorse ~= nil then self.buyHorse = db.buyHorse end
  if db.invite ~= nil then self.invite = db.invite end
  if db.sendDiamond ~= nil then self.sendDiamond = db.sendDiamond end
  if db.todaySendCount ~= nil then self.todaySendCount = db.todaySendCount end
  if db.signPrizeForDay ~= nil then self.signPrizeForDay = db.signPrizeForDay end
  if db.zhuanpan ~= nil then self.zhuanpan = db.zhuanpan end
  if db.invitePrize ~= nil then self.invitePrize = db.invitePrize end
  if db.vip ~= nil then self.vip = tonumber(db.vip) end
  if db.lastSharePrizeWeek ~= nil then self.lastSharePrizeWeek = db.lastSharePrizeWeek end

  self.mail:initFromDB(db)
end

function User:addRankScore(score)
  self.rankSocre = self.rankSocre + score
  self.app.mongo:update("user", {uid = self.uid}, {["$set"] = {rankSocre = self.rankSocre}}, nil, true,function(_, _)end)
end

function User:statisticsCompetition(cnt,winCnt)
  self.rankCnt = self.rankCnt + cnt
  self.rankWinCnt = self.rankWinCnt + winCnt

  self.app.mongo:update("user", {uid = self.uid}, {["$set"] = {rankCnt = self.rankCnt,rankWinCnt = self.rankWinCnt}}, nil, true,function(_, _)end)

  if self:isOnline() and not self:isBot() then
    local msg = {
      msgID = 'StatisticsCompetition',
      rankCnt = self.rankCnt,
      rankWinCnt = self.rankWinCnt
    }

    self:sendMsg(msg)
  end
end

function User:packageForDB(insert)
  insert.phone = self.phone
  insert.uid = self.uid
  insert.nickName = self.nickName
  insert.avatar = self.avatar
  insert.sex = self.sex
  insert.diamond = self.diamond
  insert.buyDiamondCnt = self.buyDiamondCnt
  insert.gold = self.gold
  insert.secondsFrom1970 = self.secondsFrom1970
  insert.win = self.win
  insert.lose = self.lose
  insert.winrate = self.winrate
  insert.todaySendCount = self.todaySendCount
  insert.status = self.status
  insert.vip = self.vip

  self.mail:packageForDB(insert)
end

function User:packageForNet(package)
  package.phone = self.phone
  package.uid = self.uid
  package.nickName = self.nickName
  package.avatar = self.avatar
  package.sex = self.sex
  package.diamond = self.diamond
  package.buyDiamondCnt = self.buyDiamondCnt
  package.gold = self.gold
  package.win = self.win
  package.lose = self.lose
  package.winrate = self.winrate
  package.playerId = self.playerId
  package.ip = self.socketID.sockname.ip
  package.invite = self.invite
  package.vip = self.vip
  package.rtnotify = self.app.rtnotify
  package.zhuanpan = self.zhuanpan

  self.mail:packageForNet(package)

  package.serverTime = os.time()

  -- check need reset some data
  local curTime = os.date('*t',os.time())
  local lstTime = os.date('*t',self.secondsFrom1970)

  if curTime.yday ~= lstTime.yday then
    self:resetSomeData(os.time())
  end

  package.secondsFrom1970 = self.secondsFrom1970
end

function User:resetSomeData(curSeconds)
  self.todayWinBean = 0
  self.sendDiamond = 0
  self.signPrizeForDay = true
  self.zhuanpan = true
  self:setSecondsFrom1970(curSeconds)

  self.todaySendCount = 0
  self.todaySends = {}
  self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {todaySendCount = self.todaySendCount}},nil,true, function(_)
  end)
end

function User:setSecondsFrom1970(secondsFrom1970)
  self.secondsFrom1970 = secondsFrom1970

  self:opMongo({uid = self.uid}, {['$set'] = {
    secondsFrom1970 = self.secondsFrom1970,
    todayWinBean = self.todayWinBean,
    sendDiamond = self.sendDiamond,
    signPrizeForDay = self.signPrizeForDay,
    zhuanpan = self.zhuanpan
  }},
  function()
  end)
end

function User:modifyUserInfo(msg)
  self.sex = msg.sex
  self.nickName = msg.nickName
  self.profile = msg.profile

  self:opMongo({uid = self.uid}, {['$set'] = {
    sex = self.sex,
    nickName = self.nickName,
    profile = self.profile
  }},function()end)

  local rep = {
    msgID = 'modifyUserInfoResult',
    sex = self.sex,
    nickName = self.nickName,
    profile = self.profile
  }

  self:sendMsg(rep)
end

function User:updateWinRate(win)
  if win then
    self.win = self.win + 1
  else
    self.lose = self.lose + 1
  end
  self.winrate = math.floor(self.win / (self.win + self.lose) * 100)
  self.app.mongo:update("user", {uid = self.uid}, {["$set"] = {win = self.win,lose = self.lose,winrate = self.winrate}}, nil, true,function()end)
end

function User:updateInfo(msg)
  self.sex = msg.sex
  self.nickName = msg.nickName
  self.avatar = msg.avatar

  self.app.mongo:update("user", {uid = self.uid}, {["$set"] = {sex = self.sex,nickName = self.nickName,avatar = self.avatar}}, nil, true,function()end)
end

function User:inputInvitePlayerId(msg)
  local function response(success, errorCode)
    local rep = {
      msgID = 'inputInvitePlayerId',
      errorCode = errorCode,
      success = success,
      invite = self.invite
    }

    self:sendMsg(rep)
  end

  local playerId = msg.playerId

  if playerId == self.playerId then
    response(false,'邀请人不能是自己')
    return
  end

  local mongo = self.app.mongo
  mongo:findOne("user", {playerId = playerId},{playerId = 1,invitePrize=1,uid=1}, nil, function(err, dbuser)
    if not err then
      if not dbuser then
        response(false,'没有查到对应的玩家')
      else
        mongo:findOne("agent", {playerId = playerId},nil, nil, function(terr, dbagent)
          if not terr then
            if dbagent then
              self.invite = playerId
              self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {invite = self.invite}},nil,true, function()end)
              response(true)

              -- 更新邀请者的奖励
              if not dbuser.invitePrize then
                dbuser.invitePrize = 0
              end

              dbuser.invitePrize = dbuser.invitePrize + 6

              local uid = dbuser.uid
              local tuser = self.app.users[uid]
              if tuser then
                -- 更新cache的数据
                tuser.invitePrize = dbuser.invitePrize

                local push = {
                  msgID = 'someoneSetInvite',
                  nickName = self.nickName
                }

                tuser:sendMsg(push)
              end

              -- 同时更新数据库的邀请奖励
              --self.app.mongo:update('user',{uid=uid}, {['$set'] = {invitePrize = dbuser.invitePrize}},nil,true, function()end)
              local user = self.app.users[self.uid]
              if user then
                user:updateRes('diamond', 6)
              else
                self.app.mongo:update('user',{uid=self.uid}, {['$inc'] = {diamond = 6}}, nil, true, function()end)
              end 
            else
              response(false,'此玩家不是代理')
            end
          else
            response(false,'数据库查询失败')
          end
        end)
      end
    else
      response(false,'数据库查询失败')
    end
  end)
end

function User:queryInvokePrize()
  local function response(success,errorCode)
    local msg = {
      msgID = 'queryInvokePrize',
      success = success,
      errorCode = errorCode
    }

    self:sendMsg(msg)
  end

  if self.invitePrize == 0 then
    response(false,"您已经领取了所有的邀请奖励")
  else
    self:updateRes('diamond', self.invitePrize)

    self.invitePrize = 0
    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {invitePrize = self.invitePrize}},nil,true, function()end)
    response(true)
  end
end

function User:inputAgent(msg)
  local name = msg.name
  local phone = msg.phone
  local wechat = msg.wechat

  self.app.mongo:update('agentQuery',{
    phone = phone
  }, {['$set'] = {
      name = name,
      phone = phone,
      wechat = wechat,
      uid = self.uid,
      playerId = self.playerId,
      status = 'wait'
    }
  },true,true, function(err)
    local rep = {
      msgID = 'inputAgent',
    }

    if err then
      rep.errorCode = '数据库写入失败'
    end
    self:sendMsg(rep)
  end)
end

function User:getSignPrize()
  local function response(success,errorCode)
    local msg = {
      msgID = 'getSignPrize',
      success = success,
      errorCode = errorCode
    }

    self:sendMsg(msg)
  end

  if not self.signPrizeForDay then
    response(false,'今日已经领取过了')
  else
    self.signPrizeForDay = false
    self:updateRes('gold', 1000)

    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {signPrizeForDay = self.signPrizeForDay}},nil,true, function()end)
    response(true)
  end
end

function User:queryQiandao()
  local function response(success,errorCode)
    local msg = {
      msgID = 'queryQiandao',
      success = success,
      errorCode = errorCode
    }

    self:sendMsg(msg)
  end

  if not self.signPrizeForDay then
    response(false,'今日已经领取过了')
  else
    self.signPrizeForDay = false
    self:updateRes('diamond', 3)

    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {signPrizeForDay = self.signPrizeForDay}},nil,true, function()end)
    response(true)
  end
end

function User:queryInviteNumber()
  self.app.mongo:find("user", {invite = self.playerId},{invite = 1}, nil, nil, function(err, res)
    local rep = {
      msgID = 'queryInviteNumber',
    }
    if not err then
      rep.count = #res
    end

    dump(res)

    self:sendMsg(rep)
  end)
end

function User:isOnline()
  return self.socketID ~= nil
end

function User:getAgent()
  return self.agent
end

function User:isPlaying()
  return (self.deskId ~= nil) or (self.goldId ~= nil)
end

function User:clearGames()
  if self.deskId then
    self.deskId = nil
    self.buyHorse = nil
    self.app.mongo:update('user',{uid=self.uid}, {['$unset'] = {deskId = "", buyHorse = ""}},nil,true, function()
    end)
  end
  self.goldId = nil
  self:setAgent(nil)
end

function User:isGameLegal()
  return (self.uid and (self.goldId or self.deskId))
end

function User:isBot()
  return false
end

function User:setAgent(agent)
  self.agent = agent
end

function User:shareSuccessPrize()
  local cur = os.time()
  local data = os.date('*t',cur)
  local yue1_day1 = os.time{year=data.year, month=1, day=1}
  local diff = cur - yue1_day1
  local diff_day = math.floor(diff / (24 * 60 * 60))
  -- 算出当前是一年的第几周
  local week = math.floor((diff_day+6) / 7)

  -- 不同的周了
  if self.lastSharePrizeWeek == -1 or self.lastSharePrizeWeek ~= week then
    self.lastSharePrizeWeek = week

    self.app.mongo:update('user',{uid=self.uid}, {['$set'] = {lastSharePrizeWeek = self.lastSharePrizeWeek}},nil,true, function(err)
      if not err then
        self:updateRes('diamond',2)

        local rep = {
          msgID = 'shareSuccessPrize',
          content = '恭喜你获得了2张房卡奖励'
        }

        self:sendMsg(rep)
      end
    end)
  else
    local rep = {
      msgID = 'shareSuccessPrize',
      content = '对不起，你这周已经领取过了啊!~'
    }

    self:sendMsg(rep)
  end
end

function User.getRankNames()
  local cur = os.time()
  local data = os.date('*t',cur)
  local DayOfYear = data.yday
  local DayOfWeek = data.wday
  DayOfWeek = DayOfWeek - 1
  if DayOfWeek == 0 then DayOfWeek = 7 end

  local t = os.time({year=data.year,month=1,day=1})
  local first_data = os.date('*t',t)

  local FirstOfWeek = first_data.wday
  FirstOfWeek = FirstOfWeek - 1
  if FirstOfWeek == 0 then FirstOfWeek = 7 end

  local number_week = (DayOfYear - 1 - (DayOfWeek - FirstOfWeek))/7

  local rank_day = 'rankday_'..data.yday
  local rank_week = 'rankweek_'..number_week
  local rank_total = 'ranktotal'

  return rank_day,rank_week,rank_total
end

function User:statisticsRanklist(number)
  if self:isBot() then return end

  local rank_day,rank_week,rank_total = User.getRankNames()

  local query = {
    owner = self.uid,
    avatar = self.avatar,
    playerId = self.playerId,
    nickName = self.nickName
  }

  local op = {
    ["$inc"] = {
      gold = number
    }
  }

  self.app.mongo:update(rank_day,query, op,true,true, function()end)
  self.app.mongo:update(rank_week,query, op,true,true, function()end)
  self.app.mongo:update(rank_total,query, op,true,true, function()end)
end

function User:queryJiuJiJin()
  local ok = self.diamond < 2 and self.gold < 500
  local success = true
  local errorMsg

  if not ok then
    errorMsg = '钻石必须少于2颗，金币必须少于500'
    success = false
  else
    self:updateRes('diamond', 2)
  end

  local rep = {
    msgID = 'queryJiuJiJin',
    success = success,
    errorMsg = errorMsg
  }

  self:sendMsg(rep)
end

function User:wechatPaySuccess(dbOrder)
  if dbOrder.processed then return end

  local query = {
    order = Mongo.ObjectId.new(tostring(dbOrder._id))
  }

  self.app.mongo:update('wechatorder',query, {['$set'] = {processed = true}},nil,true, safe(function(err)
    if not err then
      local card = dbOrder.card
      local gold = dbOrder.gold

      if card then
        self:updateRes('diamond', card)
      end

      if gold then
        self:updateRes('gold', gold)
      end
    end
  end))
end

function User:queryPayOrder(msg)
  local oid = Mongo.ObjectId.new()

  local insert = {
    uid = self.uid,
    order = oid,
    card = msg.card,
    gold = msg.gold,
    processed = false
  }

  dump(insert)

  self.app.mongo:insert('wechatorder',insert,nil,function(err)
    if not err then
      local rep = {
        msgID = 'queryPayOrder',
        order = tostring(oid)
      }

      self:sendMsg(rep)
    end
  end)
end

function User:chargeResult(resultData, invite)
  invite = invite or -1
  local rep = {
      msgID = 'chargeResult',
      playerId = resultData.playerId,
      diamond = resultData.diamond,
      song = resultData.song,
      orderId = resultData.orderId,
      invite = invite,
  }
  self:sendMsg(rep)
end

return User
