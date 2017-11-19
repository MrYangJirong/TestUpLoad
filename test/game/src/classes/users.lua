local class = require('middleclass')
local safety = require('./safety')
local Users = class('Users')
local safe = require('game.src.safe')
local helper = require('game.src.helper')
local json = require "json"

function Users:initialize(app)
  self.app = app

  app:on('getFreeCoin',function(socketID,msg)
    self:getFreeCoin(socketID,msg)
  end)

  app:on('modifyUserInfo',function(socketID,msg)
    self:modifyUserInfo(socketID,msg)
  end)

  app:on('queryOrder',function(socketID,msg)
    self:queryOrder(socketID,msg)
  end)

  app:on('getSignPrize',function(socketID,msg)
    self:getSignPrize(socketID,msg)
  end)

  app:on('updateInfo',function(conn,msg)
    self:updateInfo(conn,msg)
  end)

  app:on('getMailPrize',function(conn,msg)
    self:getMailPrize(conn,msg)
  end)

  app:on('getInfoByUids',function(conn,msg)
    self:getInfoByUids(conn,msg)
  end)

  app:on('shareWithMoney',function(conn,msg)
    self:shareWithMoney(conn,msg)
  end)

  app:on('createRoom',function(socketID,msg)
    self:createRoom(socketID,msg)
  end)

  app:on('enterRoom',function(socketID,msg)
    self:enterRoom(socketID,msg)
  end)

  app:on('listRooms',function(socketID,msg)
    self:listRooms(socketID,msg)
  end)

  app:on('checkGame',function(socketID,msg)
    self:checkGame(socketID,msg)
  end)

  app:on('listRecords',function(socketID,msg)
    self:listRecords(socketID,msg)
  end)

  app:on('listPlayRecords',function(socketID,msg)
    self:listPlayRecords(socketID,msg)
  end)

  app:on('listRankLists',function(socketID,msg)
    self:listRankLists(socketID,msg)
  end)

  app:on('chatInGame',function(socketID,msg)
    self:chatInGame(socketID,msg)
  end)

  app:on('playVoice',function(socketID,msg)
    self:playVoice(socketID,msg)
  end)

  app:on('enterGoldRoom',function(socketID,msg)
    self:enterGoldRoom(socketID,msg)
  end)

  app:on('exchange',function(socketID,msg)
    self:exchange(socketID,msg)
  end)

  app:on('paySuccess',function(socketID,msg)
    self:paySuccess(socketID,msg)
  end)

  app:on('giveRes',function(socketID,msg)
    self:giveRes(socketID,msg)
  end)

  app:on('getNotify',function(socketID,msg)
    self:getNotify(socketID,msg)
  end)

  app:on('ping', function(socketID,msg)
    self:ping(socketID,msg)
  end)

  app:on('dumpRoomInfo',function(socketID,msg)
    self:dumpRoomInfo(socketID,msg)
  end)

  app:on('queryInviteNumber',function(socketID,msg)
    self:queryInviteNumber(socketID,msg)
  end)

  app:on('inputInvitePlayerId',function(socketID,msg)
    self:inputInvitePlayerId(socketID,msg)
  end)

  app:on('queryQiandao',function(socketID,msg)
    self:queryQiandao(socketID,msg)
  end)

  app:on('queryInvokePrize',function(socketID,msg)
    self:queryInvokePrize(socketID,msg)
  end)

  app:on('inputAgent',function(socketID,msg)
    self:inputAgent(socketID,msg)
  end)

  app:on('synGPS',function(socketID,msg)
    self:synGPS(socketID,msg)
  end)

  app:on('queryContact',function(socketID,msg)
    self:queryContact(socketID,msg)
  end)

  app:on('runZhuanpan',function(socketID,msg)
    self:runZhuanpan(socketID,msg)
  end)

  app:on('shareSuccessPrize',function(socketID,msg)
    self:shareSuccessPrize(socketID,msg)
  end)

  app:on('queryJiuJiJin',function(socketID,msg)
    self:queryJiuJiJin(socketID,msg)
  end)

  app:on('searchUser',function(socketID,msg)
    self:searchUser(socketID,msg)
  end)

  app:on('queryPayOrder',function(socketID,msg)
    self:queryPayOrder(socketID,msg)
  end)
end

function Users:queryPayOrder(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:queryPayOrder(msg)
  end
end

function Users:searchUser(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    self.app.mongo:findOne("user", {playerId = msg.playerId},{nickName = 1, avatar = 1}, nil, safe(function(err, dbUser)
      if not err then
        local rep = {}
        if dbUser then
          rep.user = dbUser
          user:sendMsg(rep)
        else
          rep.errCode = 2
          user:sendMsg(rep)
        end
      else
        local rep = {}
        rep.errCode = 1
        user:sendMsg(rep)
      end
    end))
  end
end

function Users:queryJiuJiJin(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:queryJiuJiJin(msg)
  end
end

function Users:shareSuccessPrize(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:shareSuccessPrize(msg)
  end
end

function Users:runZhuanpan(socketID, msg)
  local user = self.app.actives[socketID]
  if user then
    user:runZhuanpan(msg)
  end
end

function Users:queryContact(socketID, msg)
  local user = self.app.actives[socketID]
  if user then
    self.app.mongo:findOne("qq", {qq = 'qq'},{content = 1}, nil, safe(function(err, dbqq)
      if not err then
        if dbqq then
          msg.content = dbqq.content
          user:sendMsg(msg)
        else
          msg.content = '暂未设置联系人'
          user:sendMsg(msg)
        end
      else
        msg.content = '获取联系人失败'
        user:sendMsg(msg)
      end
    end))
  end
end

function Users:synGPS(socketID, msg)
  local user = self.app.actives[socketID]
  if user then
    user:synGPS(msg)
  end
end

function Users:ping(socketID)
  local user = self.app.actives[socketID]
  if user then
    user:sendMsg({msgID = 'ping'})
  end
end

function Users:queryQiandao(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:queryQiandao(msg)
  end
end

function Users:queryInvokePrize(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:queryInvokePrize(msg)
  end
end

function Users:inputAgent(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:inputAgent(msg)
  end
end

function Users:inputInvitePlayerId(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:inputInvitePlayerId(msg)
  end
end

function Users:queryInviteNumber(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:queryInviteNumber(msg)
  end
end

function Users:getNotify(socketID)
  local user = self.app.actives[socketID]
  if user then
    self.app.mongo:find("bbs", {
	      ['$query'] = {
	        type = "user"--{['$elemMatch'] = {["$eq"] = user.uid}}
	      },
      ['$orderby'] = {
        time=-1
      }
    },{}, nil, 1, safe(function(err, res)
			if not err then
				if #res > 0 then
					local msg = {msgID = 'getNotify'}
					msg.title = res[1].title
					msg.content = res[1].content
          user:sendMsg(msg)
				end
			end
		end))
  end
end

function Users:giveRes(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:giveRes(msg.resName, msg.playerId, msg.value)
  end
end

function Users:paySuccess(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:paySuccess(msg)
  end
end

function Users:exchange(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    user:exchange(msg.number)
  end
end

function Users:enterGoldRoom(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    local game = self.app.gameMgr:getGame(msg.gameIdx)
    if game then
      game:enterGoldRoom(user, msg)
    end
  end
end

function Users:playVoice(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:playVoice(msg)
  end
end

function Users:chatInGame(socketID,msg)
  local user = self.app.actives[socketID]
  if user and user.agent then
    user.agent:chatInGame(msg)
  end
end

function Users:listRankLists(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    local User = require('game.src.model.user')

    local rank_day,rank_week,rank_total = User.getRankNames()

    local col
    if msg.type == 'day' then
      col = rank_day
    elseif msg.type == 'week' then
      col = rank_week
    else
      col = rank_total
    end

    self.app.mongo:find(col, {
      ['$query'] = {},
      ['$orderby'] = {
        gold=-1
      }
    },{
      playerId = 1,
      gold = 1,
      avatar = 1,
      nickName = 1
    }, nil, 50, safe(function(err, res)
      print(err, res)
      if not err then
        local rep = {}
        rep.msgID = 'listRankLists'
        rep.ranks = {}
        if #res > 0 then
          rep.ranks = res
        end
        user:sendMsg(rep)
      end
    end))
  end
end

function Users:listPlayRecords(socketID, msg)
  local user = self.app.actives[socketID]
  if user then
    self.app.mongo:find("playRecords", {
      ['$query'] = {
        uids = {['$elemMatch'] = {["$eq"] = user.uid}},
        deskId = msg.deskId
      },
      ['$orderby'] = {
        time=-1
      }
    },{}, nil, 30, safe(function(err, res)
      if not err then
        user:sendMsg({msgID = 'beganRecords'})

        if #res > 0 then
          for _, v in ipairs(res) do
            local rep = {}
            rep.msgID = 'listPlayRecords'
            rep.records = v.record
            user:sendMsg(rep)
          end
        else
          user:sendMsg({msgID = 'listPlayRecords', records = {}})
        end
        user:sendMsg({msgID = 'endRecords'})
      end
    end))
  end
end

-- function Users:listRecords(socketID)
--   local user = self.app.actives[socketID]
--   if user then
--     self.app.mongo:find("records", {
--       ['$query'] = {
--         uids = {['$elemMatch'] = {["$eq"] = user.uid}}
--       },
--       ['$orderby'] = {
--         time=-1
--       }
--     },{}, nil, 15, safe(function(err, res)
--       print(err, res)
--       if not err then
--         local rep = {}
--         rep.msgID = 'listRecords'

--         rep.records = {}
--         if #res > 0 then
--           for _, v in ipairs(res) do
--             local r = {}
--             for key, val in pairs(v) do
--               if key ~= "_id" then
--                 r[key] = v[key]
--               end
--             end

--             -- r.player = v.player
--             -- r.deskId = v.deskId
--             -- r.ownerName = v.ownerName
--             -- r.gName = v.gName
--             -- r.time = v.time
            
--             table.insert(rep.records, r)
--           end
--           user:sendMsg(rep)
--         else
--           user:sendMsg(rep)
--         end
--       end
--     end))
--   end
-- end

function Users:listRecords(socketID)
  local user = self.app.actives[socketID]
  if user then
    self.app.mongo:find("records", {
      ['$query'] = {
        uids = {['$elemMatch'] = {["$eq"] = user.uid}}
      },
      ['$orderby'] = {
        time=-1
      }
    },{}, nil, 20, safe(function(err, res)
      print(err, res)
      if not err then

        local rep = {}
        rep.msgID = 'listRecords'
        rep.records = {}
        
        if #res > 0 then
          user:sendMsg({msgID = "beganlistRecords"})

          for _, v in ipairs(res) do
            local r = {}
            for key, val in pairs(v) do
              if key ~= "_id" then
                r[key] = v[key]
              end
            end
            -- r.player = v.player
            -- r.deskId = v.deskId
            -- r.ownerName = v.ownerName
            -- r.gName = v.gName
            -- r.time = v.time
            user:sendMsg({msgID = "listRecords", record = r})
            --table.insert(rep.records, r)
          end
          user:sendMsg({msgID = "endlistRecords"})
        else
          user:sendMsg({msgID = "nonelistRecords"})
        end
      end
    end))
  end
end

function Users:checkGame(socketID)
  local function pacakageInfo(user, desk)
    local info  = {}
    info.goldId = user.goldId
    info.deskId = user.deskId
    info.isPlay = (desk.play ~= nil) or desk.played
    info.isPlayed = desk.played
    local players = {}
    for i, v in ipairs(desk.allChairs) do
      if v.agent then
        players[i] = v.agent:package(true)
      end
    end
    info.players = players
    info.uid = user.uid
    return info
  end

  local user = self.app.actives[socketID]
  if user then
    if user.deskId then
      local desk = self.app.gameMgr:findDeskBy(user.deskId)
      if desk then
        if user.buyHorse then
          desk:setHorse(user)
        else
          --if not desk:sitdown(user) then
          if not desk:enterDesk(user) then
            local info  = pacakageInfo(user, desk)
            helper.writeLog("enter room Id error!! "..json.encode(info))
          end
        end
      else
        local info  = {}
        info.deskId = user.deskId
        info.agent = (user.agent ~= nil)
        if user.agent and user.agent.desk then
          info.agentInfo = user.agent:package()
          info.desk = user.agent.desk:packageInfo()
        end
        --helper.writeLog("can't find desk!! "..json.encode(info))
        user:clearGames()
      end
    elseif user.goldId then
      local desk = self.app.gameMgr:findGoldDeskBy(user.goldId)
      if desk then
        if user.buyHorse then
          desk:setHorse(user)
        else
          --if not desk:sitdown(user) then
          if not desk:enterDesk(user) then
            local info  = pacakageInfo(user, desk)
            helper.writeLog("enter room Id error!! "..json.encode(info))
          end
        end
      else
        helper.writeLog("can't find gold desk!! "..user.goldId)
        user:clearGames()
      end
    else
      --[[local desk, isGold = self.app.gameMgr:findPlayerInDesks(user.uid)
      if desk then
        if isGold then
          user.goldId = desk.deskId
        else
          user.deskId = desk.deskId
        end
        if desk:sitdown(user) then
          local info  = pacakageInfo(user, desk)
          helper.writeLog("player in desk but can't enter rooms "..json.encode(info))
        else
          helper.writeLog("not id sitdown err!!, Id is"..desk.deskId)
        end
      else]]
        local rep = {msgID = 'notInDesk'}
        user:sendMsg(rep)
      --end
    end
  end
end

function Users:dumpRoomInfo(_,msg)
  local desk = self.app.gameMgr:findDeskBy(msg.deskId)
  if desk then
    local data = desk:showRoomInfo()
    local result = json.ecode(data)

    local filename = 'logDump'
    local fs = require "fs"
    local fd = fs.openSync('logs/'..filename,'w')
    fs.writeSync(fd,0,result)
    fs.close(fd)
  end
end

function Users:enterRoom(socketID,msg)
  local user = self.app.actives[socketID]
  if user then
    local deskId = msg.deskId
    local desk, gameIdx = self.app.gameMgr:findDeskBy(deskId)
    local retCode = self.app.groupMgr:canEnterGroupRoom(deskId, user.playerId)

    print('enterRoom', retCode)

    local rep = {}
    if desk and retCode ~= 2 then
      rep.gameIdx = gameIdx
      rep.deskId = msg.deskId
      rep.buyHorse = msg.buyHorse
      rep.mode = msg.mode
      if msg.buyHorse then                  -- 买马
        if not desk:canBeHorse() then
          rep.errorCode = 3
        end
      else
        -- 默认观战情况 不限制人数
        -- if not desk:getFreeChair() then     -- 正常模式
        --   rep.errorCode = 1
        -- end
      end
    elseif retCode == 2 then
      rep.errorCode = 4
    else
      rep.errorCode = 2
    end
    rep.msgID = 'enterRoom'
    user:sendMsg(rep)
  end
end

--gameIdx
function Users:createRoom(socketID,msg)
  if safety.paramLose({'options'}, msg) then return end
  local user = self.app.actives[socketID]
  local game = self.app.gameMgr:getGame(msg.gameIdx)
  if user and game then
    game:createDesk(user, msg)
  end
end

function Users:listRooms(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:listRooms(msg)
  end
end

function Users:shareWithMoney(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:shareWithMoney(msg)
  end
end

function Users:getInfoByUids(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:getInfoByUids(msg.uids)
  end
end

function Users:bindPhone(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:bindPhone(msg)
  end
end

function Users:getSignPrize(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:getSignPrize(msg)
  end
end

function Users:modifyUserInfo(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:modifyUserInfo(msg)
  end
end

function Users:getFreeCoin(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:getFreeCoin(msg)
  end
end

function Users:updateInfo(socketID,msg)
  local user = self.app.actives[socketID]

  if user then
    user:updateInfo(msg)
  end
end

function Users:getMailPrize(socketID,msg)
  local user = self.app.actives[socketID]

  if user and user.mail then
    user.mail:getMailPrize(msg)
  end
end

return Users
