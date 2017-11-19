return {
  name = "gamecity.servers",
  version = "0.0.1",
  description = "The Shengji servers based on luvit.",
  tags = { "lua", "lit", "luvit" },
  license = "Copyright 2016 Shininggames.com. All Right Reserved!",
  author = { name = "The Shininggames Team", email = "shininggames.cn@gmail.com" },
  homepage = "https://git.coding.net/xpol/Shengji.servers.git",
  private=true,
  dependencies = {
    "cyrilis/luvit-mongodb",
    "creationix/weblit"
  },
  files = {
    "**.lua",
    "!test*"
  }
}
