local class = require('middleclass')
local robot = require('../model/robot')
local robotMng = class('robotMng')
local MaxCount = 210

function robotMng:initialize(app)
  self.app = app
  self.allRobot = {}
  self.robotCount = 0
end

function robotMng:generateRobot()
  self.robotCount = self.robotCount + 1
  local trobot = robot(self.app)
  table.insert(self.allRobot, trobot)
  return trobot
end

function robotMng:getRobot()
  for _, trobot in ipairs(self.allRobot) do
    if (not trobot:isBusy()) then
      trobot:setBusy(true)
      return trobot
    end
  end

  if self.robotCount < MaxCount then
    local trobot = self:generateRobot()
    trobot:setBusy(true)
    return trobot
  end

  return nil
end

return robotMng
