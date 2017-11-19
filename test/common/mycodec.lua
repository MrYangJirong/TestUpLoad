local mycodec = {}
local netfoxpack = require('netfoxpack')
function mycodec.create()
	local handle = netfoxpack.CodecData()
	return handle
end

function mycodec.process(handle,data,call,errorCall)
	netfoxpack.process(handle,data,function(package,size,main,sub)
		--print('receive',size,main,sub)
		--print('receive',package)
		--print('receive',#package)
		if call then
			call(package)
		end
	end,function()
		if errorCall then
			errorCall()
		end
	end)
end

function mycodec.createPackage(data)
	return netfoxpack.createPackage(data)
end

function mycodec.doTest()
  local handle = mycodec.create()
	local data = ''
	for _ =	1,85898 do
		data = data..'a'
	end

	--for _ = 1,1000 do
		--print('send',data)
		print('send',#data)

		local msg = mycodec.createPackage(data)
		--print('package send',msg)
		print('package send',#msg)
		mycodec.process(handle,msg)
	--end
end

--mycodec.doTest()

--[[
local Key_Value = 'ABcde34gdbbddddd'
local g_dwDelta = 0xA55AA55A
local SOCKET_VER = 0x66
local bit = require('bit')
local Buffer = require('buffer').Buffer

-- Decrypt
local function DecryptTEA(first,second)
	local dwXorKey = Buffer:new(Key_Value)

  local dwXorKey_0 = dwXorKey:readUInt32LE(1)
  local dwXorKey_1 = dwXorKey:readUInt32LE(5)
  local dwXorKey_2 = dwXorKey:readUInt32LE(9)
  local dwXorKey_3 = dwXorKey:readUInt32LE(13)

	local sum
	local  y =  first
	local  z =  second
	local  dwDelta = g_dwDelta

	sum = bit.lshift(g_dwDelta,5)

	for _ = 1,32 do
    z = z - bit.bxor(bit.bxor((bit.lshift(y,4) + dwXorKey_2),(y + sum)),(bit.rshift(y,5) + dwXorKey_3))
    y = y - bit.bxor(bit.bxor((bit.lshift(z,4) + dwXorKey_0),(z + sum)),(bit.rshift(z,5) + dwXorKey_1))

    sum = sum - dwDelta
	end

  return y,z
end

--Encrypt
local function EncryptTEA(first,second)
	local y = first
	local z = second
	local sum = 0

  local key = Buffer:new(Key_Value)
  local key_0 = key:readUInt32LE(1)
  local key_1 = key:readUInt32LE(5)
  local key_2 = key:readUInt32LE(9)
  local key_3 = key:readUInt32LE(13)

	local dwDelta = g_dwDelta

	for _ = 1,32 do
		sum = sum + dwDelta
    y = y + bit.bxor(bit.bxor((bit.lshift(z,4) + key_0) ,(z + sum)),(bit.rshift(z,5) + key_1))
    z = z + bit.bxor(bit.bxor((bit.lshift(y,4) + key_2),(y + sum)),(bit.rshift(y,5) + key_3))
	end

  return y,z
end

--Decrypt
local function DecryptBuffer(msg,wDataSize)
  local buffer = Buffer:new(msg)
  local loopCnt = wDataSize / 8

  --print('loopCnt ',loopCnt)
  --print('msg ',msg)
  local offset = 1

	for _ = 1,loopCnt do
    local first = buffer:readUInt32LE(offset)
    local second = buffer:readUInt32LE(offset + 4)

		first,second = DecryptTEA(first, second)
    buffer[offset + 0] = bit.band(bit.rshift(first,0),0xff)
    buffer[offset + 1] = bit.band(bit.rshift(first,8),0xff)
    buffer[offset + 2] = bit.band(bit.rshift(first,16),0xff)
    buffer[offset + 3] = bit.band(bit.rshift(first,24),0xff)

    buffer[offset + 4 + 0] = bit.band(bit.rshift(second,0),0xff)
    buffer[offset + 4 + 1] = bit.band(bit.rshift(second,8),0xff)
    buffer[offset + 4 + 2] = bit.band(bit.rshift(second,16),0xff)
    buffer[offset + 4 + 3] = bit.band(bit.rshift(second,24),0xff)

    offset = offset + 8
	end

  return tostring(buffer)
end

-- Encrypt
local function EncryptBuffer(msg, wDataSize)
  local buffer = Buffer:new(msg)
  local loopCnt = wDataSize / 8
  local offset = 1

	for _ = 1,loopCnt do
    local first = buffer:readUInt32LE(offset)
    local second = buffer:readUInt32LE(offset + 4)

		first,second = EncryptTEA(first, second)
    buffer[offset + 0] = bit.band(bit.rshift(first,0),0xff)
    buffer[offset + 1] = bit.band(bit.rshift(first,8),0xff)
    buffer[offset + 2] = bit.band(bit.rshift(first,16),0xff)
    buffer[offset + 3] = bit.band(bit.rshift(first,24),0xff)

    buffer[offset + 4 + 0] = bit.band(bit.rshift(second,0),0xff)
    buffer[offset + 4 + 1] = bit.band(bit.rshift(second,8),0xff)
    buffer[offset + 4 + 2] = bit.band(bit.rshift(second,16),0xff)
    buffer[offset + 4 + 3] = bit.band(bit.rshift(second,24),0xff)

    offset = offset + 8
  end

  return tostring(buffer)
end

function mycodec.create()
  local handle = {
    _readStep = 0,
    _currentReadSize = 0,
    mainID = 0,
    subID = 0,
    _needReadTotalSize = 8,
    _readBuffer = ''
  }

  return handle
end


local function _read_head_ok(handle)
	local header = handle._readBuffer
	header = DecryptBuffer(header, #handle._readBuffer)
  local headerBuffer = Buffer:new(header)
  local cbVersion = headerBuffer:readUInt8(1)
  local cbCheckCode = headerBuffer:readUInt8(2)
  local wPacketSize = headerBuffer:readUInt16LE(3)

	if cbVersion ~= 0x66 then
		print('Decrypt error version is not 0x66')
		return 0
	end

	if cbCheckCode ~= 0x02 then
		print('Decrypt error checkcode is not 0x02')
		return 0
	end

	handle._needReadTotalSize = wPacketSize - 8
	handle._readStep = 1
	handle._currentReadSize = 0

	handle.mainID = headerBuffer:readUInt16LE(5)
	handle.subID = headerBuffer:readUInt16LE(7)

	--print('mainID subID',handle.mainID,handle.subID)

  handle._readBuffer = ''

	return 1
end

local function _read_body_ok(handle,call)
	local tmpBuffer = ''
  tmpBuffer = tmpBuffer .. handle._readBuffer

	if call then
  	call(tmpBuffer)
	end

	handle._readBuffer = ''
	handle._readStep = 0
	handle._needReadTotalSize = 8
	handle._currentReadSize = 0
end

function mycodec.process(handle,data,call,errorCall)
  local nread = #data

  local willReadBytes
	local big
	local readSize
	local ok
	local read_bytes = nread
	local total_size = 0
	local headIsOk

	local needNext = true
  while true do
  	willReadBytes = handle._currentReadSize + read_bytes
  	big = 0
  	ok = 0

  	if willReadBytes >= handle._needReadTotalSize then
  		big = willReadBytes - handle._needReadTotalSize
  		ok = 1

			needNext = false
  	end

  	readSize = read_bytes - big
    handle._readBuffer = handle._readBuffer .. data:sub(1 + total_size,total_size + readSize)
  	total_size = total_size + readSize
  	handle._currentReadSize = handle._currentReadSize + readSize

  	if handle._readStep ==  0 then
  		if ok == 1 then
  			headIsOk = _read_head_ok(handle)
  			if headIsOk ~= 1  then
  				print('head is error')
					if errorCall then
						errorCall()
					end
  				return
  			end
  		end
    elseif handle._readStep == 1 then
      if ok == 1 then
        _read_body_ok(handle,call)
      end
    end

  	if big > 0 then
  		read_bytes = big
    else
      break
  	end
  end

	if needNext then
		print('read data is ',#data)
	end
end

function mycodec.createPackage(data)
  local wMainCmdID = 99
  local wSubCmdID = 99

  local head = Buffer:new(8)

  head[1] = SOCKET_VER
  head[2] = 0x02

  local len = 8 + #data
  head[3] = bit.band(bit.rshift(len,0),0xff)
  head[4] = bit.band(bit.rshift(len,8),0xff)

  -- set the cmd id
  head[5] = bit.band(bit.rshift(wMainCmdID,0),0xff)
  head[6] = bit.band(bit.rshift(wMainCmdID,8),0xff)
  head[7] = bit.band(bit.rshift(wSubCmdID,0),0xff)
  head[8] = bit.band(bit.rshift(wSubCmdID,8),0xff)

	local headMsg = EncryptBuffer(tostring(head), 8)
  local msg = headMsg .. data

  return msg
end

function mycodec.doTest()
  local handle = mycodec.create()
  local msg = mycodec.createPackage('hahaha fdsfsadfasdf fdsaf fdsafasdf fdsaf ')
  mycodec.process(handle,msg)
end]]

return mycodec
