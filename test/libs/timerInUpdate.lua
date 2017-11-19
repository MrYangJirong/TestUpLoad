local class = require('middleclass')
local TimerInUpdate = class('Group')

function TimerInUpdate:initialize()
    self.tabTimer = {}
end

function TimerInUpdate:addTimer(msg, args, callBack)
    self.tabTimer[msg] = {
        callBack = callBack, 
        tick = 0,
        mode = args.mode,
        time = args.time,
        }
end

function TimerInUpdate:delTimer(msg)
    self.tabTimer[msg] = nil
end

function TimerInUpdate:update(dt)
    local function onTimeup(key)
        if mode == 'repeat' then -- 重复
            self.tabTimer[key].tick = 0
        elseif mode == 'once' then -- 一次
            self.tabTimer[key] = nil
        end
    end 

    for key, v in pairs(self.tabTimer) do
        v.tick = v.tick + dt
        if v.tick >= v.time then
            v.callBack(key)
            onTimeup(key)
        end
    end
end

function TimerInUpdate:finalize()
    self.tabTimer = {}
end


return TimerInUpdate