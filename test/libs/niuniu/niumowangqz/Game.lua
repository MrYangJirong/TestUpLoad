local class = require('middleclass')
local pGame = require('libs.niuniu.pGame')
local Game = class('Game', pGame)

function Game:initialize(players, option)
	pGame.initialize(self)
	self.gName = 'niumowangqz'
	self:baseInit(players, option)
end

function Game:getBaseScore(p1, p2)
	local putScore
	if p1.hand.putScore then
		putScore = p1.hand.putScore
	elseif p2.hand.putScore then
		putScore = p2.hand.putScore
	end
	
	return putScore
end

function Game:bigThanThree(_, _, p1S, p2S)
	if p1S > p2S then
		return true
	else
		return false
	end
end

function Game:updateMoney()
	
	-- local cfg = {
	--   niuniu = {['1/2'] = 10, ['2/4'] = 20, ['4/8'] = 40},
	--   niu9 = {['1/2'] = 9, ['2/4'] = 18, ['4/8'] = 32},
	--   niu78 = {['1/2'] = 5, ['2/4'] = 12, ['4/8'] = 24},
	--   niu16 = {['1/2'] = 10, ['2/4'] = 20, ['4/8'] = 16},
	-- }
	local tabMaxBaseScore = {
		['1/2'] = 2,
		['2/4'] = 3,
		['4/8'] = 8,
		['5/10'] = 10,
	}
	
	local tabCfgPutScore = {
		['1/2'] = {
			[1] = {
				{{0, 0}, {6}},
				{{1, 3}, {12}},
				{{4, 10}, {20}},
			},
			[2] = {
				{{0, 0}, {6}},
				{{1, 3}, {12}},
				{{4, 10}, {20}},
			},
		},
		
		['2/4'] = {
			[2] = {
				{{0, 0}, {6}},
				{{1, 3}, {12}},
				{{4, 10}, {20}},
			},
			[4] = {
				{{0, 0}, {6}},
				{{1, 3}, {12}},
				{{4, 10}, {20}},
			},
		},
		
		['4/8'] = {
			[4] = {
				{{0, 0}, {12}},
				{{1, 3}, {24}},
				{{4, 10}, {40}},
			},
			[8] = {
				{{0, 0}, {12}},
				{{1, 3}, {24}},
				{{4, 10}, {40}},
			},
		},
		
		['5/10'] = {
			[5] = {
				{{0, 0}, {20}},
				{{1, 3}, {30}},
				{{4, 10}, {50}},
			},
			[10] = {
				{{0, 0}, {20}},
				{{1, 3}, {30}},
				{{4, 10}, {50}},
			},
		},
	}

	local function getNextPut(configTab, niuCnt, specialType, putScore)
		niuCnt = niuCnt or 0
		specialType = specialType or 0
		local niuCfgTab = configTab[putScore]
		if not niuCfgTab then return nil end
		
		print("上盘押注: ", putScore, " 当前牛牛: ", niuCnt, " 当前特殊牌: ", specialType)
		
		local cnt =(specialType > 0) and 10 or niuCnt
		for i, v in pairs(niuCfgTab) do
			if cnt >= v[1] [1] and cnt <= v[1] [2] then
				dump(v[2])
				return v[2]
			end
		end
		return nil
	end

	local function getNextPut2(setting, score, maxBet, putmoney)
		-- 推注模式
		local tabNextPutMul = {
			9999, -- 不封顶
			5,
			8,
			10,
		}
		local mul = tabNextPutMul[setting] or 999
		local maxPut = mul * maxBet
		local nextput = score + putmoney
		
		if nextput > maxPut then
			nextput = maxPut
			return 	{nextput}
		elseif nextput <= maxPut and nextput > maxBet then
			return 	{nextput}
		else
			return nil
		end
	end
	
	for _, v in ipairs(self.players) do
		local uid = v:getUid()
		v:moneyChange(self.summary[uid].score)
		self.summary[uid].money = v:getMoney()
		
		-- 下盘推注
		local maxBaseScore = tabMaxBaseScore[self.option.base]
		local cfg_putScore = tabCfgPutScore[self.option.base]
		v.nextPut = nil
		repeat
			if cfg_putScore == nil then break end
			-- 不推注模式
			if self.option.advanced[1] ~= 1 then break end 
			-- 庄家处理
			if v == self.banker then break end
			
			-- 输的人不能推注
			if self.summary[uid].score <= 0 then break end
			
			-- 这盘推注下盘不能推注
			if maxBaseScore and v.hand.putScore > maxBaseScore then break end
			
			-- v.nextPut = getNextPut(cfg_putScore, v.hand.niuCnt, v.hand.specialType, v.hand.putScore)
			
			v.nextPut = getNextPut2(self.option.putmoney, self.summary[uid].score, maxBaseScore, v.hand.putScore)

		until true
		
		v.hand = nil
	end
end

function Game:getScore(hand, baseScore)
	
	if self.option.gameplay == 6 then
		baseScore = baseScore * self.option.fixedBase
		baseScore = baseScore * self.option.pubBase
	end
	
	-- 特殊牌
	if hand.specialType > 0 then
		local tabMul = {
			WUXIAO = 8,
			WUHUA_J = 8,
			STRAIGHT = 8,
			TONGHUA = 8,
			HULU = 8,
			BOOM = 8,
		}
		local tabMul1 = {
			WUXIAO = 10,
			BOOM = 10,
			HULU = 10,
			WUHUA_J = 10,
			WUHUA_Y = 10,
			TONGHUA = 10,
			STRAIGHT = 10,
		}
		local name, type = hand:getSpecialType()
		if name then
			baseScore = baseScore * tabMul[name]
			if self.option.gameplay == 7 then
				baseScore = baseScore * tabMul1[name]
			end
			print("SPECIALTYPE", name, hand.specialType, baseScore)
		end
		return baseScore
	end
	
	local cnt = hand.niuCnt
	if self.option.gameplay == 7 then
		-- 疯狂牛牛
		local mulNum = cnt
		if cnt == 0 then
			mulNum = 1
		end
		print('疯狂牛牛 mul:', mulNum, 'niucnt: ', cnt)
		return baseScore * mulNum
	else
		-- 其他模式
		if self.option.multiply == 1 then
			if cnt < 7 then
				return baseScore
			elseif cnt == 7 then
				return baseScore * 2
			elseif cnt == 8 then
				return baseScore * 3
			elseif cnt == 9 then
				return baseScore * 4
			else
				return baseScore * 5
			end
		else
			if cnt < 8 then
				return baseScore
			elseif cnt == 8 then
				return baseScore * 2
			elseif cnt == 9 then
				return baseScore * 2
			else
				return baseScore * 3
			end
		end
	end
end

function Game:done()
	local count = 0
	for _, v in ipairs(self.players) do
		if v.hand:ishupai() then
			count = count + 1
		end
	end
	return(count >= 1)
end

function Game:gameSummary()
	self:baseGameSummary()
end

return Game
