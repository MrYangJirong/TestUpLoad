local function mkargs()
  if arg then
    return arg
  end
  local arg = {}
  for i = 2,#args do
    arg[#arg+1] = args[i]
  end
  return arg
end
return mkargs()
