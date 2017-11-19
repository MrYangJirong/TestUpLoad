--[[
Addon functions to table.

Usage:

local table = require('table.addons')

table.keys(t)

]]
local table = table

function table.keys(t)
  local r = {}
  for k in pairs(t) do
    r[#r+1] = k
  end
  return r
end

function table.values(t)
  local r = {}
  for _, v in pairs(t) do
    r[#r+1] = v
  end
  return r
end

function table.empty(t)
  return next(t) == nil
end


-- Counts the number of elements which equal value.
function table.count(a, value)
  local n = 0
  for _,v in pairs(a) do
    if v == value then
      n = n + 1
    end
  end
  return n
end

function table.contain(t, value)
  for _,v in pairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

function table.copy(t)
  local n = {}
  for k, v in pairs(t) do
    if type(v) == 'table' then
      n[k] = table.copy(v)
    else
      n[k] = v
    end
  end
  return n
end
return table
