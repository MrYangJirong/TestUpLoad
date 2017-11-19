-- setup luarocks LUA_PATH and LUA_CPATH for current running process.
-- requires luarocks in PATH.

local h = io.popen('luarocks path')
print("hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh")
print(h)
local output = h:read('*a')
h:close()

local luapath = output:match('export LUA_PATH=\'([^\']+)\'')
if not luapath then
  print(output)
  error('error while parse outputs for `luarocks path`')
end
local luacpath = output:match('export LUA_CPATH=\'([^\']+)\'')
if not luacpath then
  print(output)
  error('error while parse outputs for `luarocks path`')
end

package.path = './libs/?.lua;./libs/?/init.lua;'..luapath..';'..package.path
package.cpath = luacpath..';'..package.cpath

return true
