local array = {}

-- Returns a copy of given array.
function array.exist(t, s)
  for _, v in ipairs(t) do
    if v == s then
      return true
    end
  end
  return false
end

-- Returns a copy of given array.
function array.copy(a, first, last)
  first, last = first or 1, last or #a
  local cp = {}
  for i=first,last,1 do
    cp[#cp+1] = a[i]
  end
  return cp
end

-- Returns a new array containing all elements of ary for which the given function returns a true value.
function array.copyif(a, f)
  local cp = {}
  for i, v in ipairs(a) do
    if f(v, i) then
      cp[#cp+1] = v
    end
  end
  return cp
end

-- Reverses the array in place.
function array.reverse(a)
  local f, t = 1, #a
  while f < t do
    a[f],a[t] = a[t], a[f]
    f = f+1
    t = t-1
  end
end

-- Invokes the given function once for each element of self.
-- Creates a new array containing the values returned by the given function f.
function array.map(a, f)
  local n = {}
  for i,v in ipairs(a) do
    n[i] = f(v, i)
  end
  return n
end

-- Counts the number of elements which equal value.
function array.count(a, value)
  local n = 0
  for _,v in ipairs(a) do
    if v == value then
      n = n + 1
    end
  end
  return n
end

-- Counts the number of elements for which the f returns a true value.
function array.countif(a, f)
  local n = 0
  for i,v in ipairs(a) do
    if f(v, i) then
      n = n + 1
    end
  end
  return n
end

-- Returns an new array conatins the first n element(s) of given array.
function array.first(a, n)
  local c = {}
  for i=1, math.min(n,#a) do
    c[i] = a[i]
  end
  return c
end

-- Returns an new array conatins the last n element(s) of given array.
function array.last(a, n)
  local c = {}
  for i=math.max(#a-n+1, 1),#a do
    c[#c+1] = a[i]
  end
  return c
end

--[[
Returns the index of the first object for which the f returns true.
Returns nil if no match is found.
]]

function array.index(a, f)
  for i, v in ipairs(a) do
    if f(v) then
      return i
    end
  end
  return nil
end

--Returns the index of the first object in arrray such that the object is == to value.
-- Returns nil if no match is found.
function array.indexof(a, value)
  for i, v in ipairs(a) do
    if v == value then
      return i
    end
  end
  return nil
end


-- Joins arrays into a new array.
function array.join(...)
  local r = {}
  for ai=1,select('#', ...) do
    local a = select(ai, ...)
    for i=1,#a do
      r[#r+1] = a[i]
    end
  end
  return r
end

-- Duplicates array n times into a new array.
function array.dup(a, n)
  local r = {}
  local l = #a
  local beg = (n-1)*l
  for ia=l,1,-1 do
    local e = a[ia]
    for ir=beg+ia,1,-l do
      r[ir] = e
    end
  end
  return r
end


-- Duplicates array n times into a new array.
function array.shuffle(a)
  local rand = math.random
  for i = #a, 2, -1 do
    local n = rand(i)
    a[i], a[n] = a[n], a[i]
  end
end

local function _less(a, b) return a < b end

function array.max(a, fn)
  fn = fn or _less
  if #a == 0 then return nil, nil end
  local value, key = a[1], 1
  for i = 2, #a do
      if fn(value, a[i]) then
          value, key = a[i], i
      end
  end
  return value, key
end
array.concat = table.concat
array.insert = table.insert
array.remove = table.remove
array.sort = table.sort


return array
