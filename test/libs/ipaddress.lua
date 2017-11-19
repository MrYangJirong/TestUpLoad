
local familys = {
  v4 = 'inet',
  v6 =  'inet6'
}
local ipaddress = {}
function ipaddress.get(version)
  local family = familys[version or 'v4']
  local ips = {}
  for k, v in pairs(require('uv').interface_addresses()) do
    if not k:find('bridge%d*') then
      for _, iface in ipairs(v) do
        if iface.internal == false and iface.family == family then
          ips[#ips+1] = iface.ip
        end
      end
    end
  end
  return ips
end

setmetatable(ipaddress, { __call = function(_, ...) return ipaddress.get(...) end })

return ipaddress
