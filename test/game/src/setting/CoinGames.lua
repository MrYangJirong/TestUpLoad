local allGames = {
  ['1'] = {--血战
    diangang = 1,
    double = 4,
    zimo = 1,
    enter = {
      buyHorse = 0
    },
    ewai = {
      daiyaojiu = 0,
      huansanzhang = 0,
      tiandihu = 0,
    },
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 1,
  },
  ['3'] = {--云南麻将
    zimo = {
      yaojilaizi = 1
    },
    double = 999,
    enter = {
      buyHorse = 0
    },
    timeout = true,
    enterLimit = 300,
    leaveLimit = 300,
    btmCost = 50,
    startCost = 50,
    robot = 35,
  },
  ['5'] = {---广州推倒胡
    choupai = 0,
    dianpaohu_or_zimo = 0,
    ewai = {
      hongzhonglaizi = 0,
      kehu7dui = 0,
      useFeng = 0,
      zhuangxian = 0,
    },
    number = 4,
    qianggangquanbao = 0,
    base = 1,
    zimo = 0,
    double = 2,
    enter = {
      buyHorse = 0
    },
    zhama = 1,
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 35,
  },
  ['8'] = {---血流成河
    diangang = 1,
    ewai = {
      daiyaojiu = 0, huansanzhang = 1, tianhu = 0, xiapiao = 0
    },
    base = 1,
    zimo = 0,
    double = 999,
    enter = {
      buyHorse = 0
    },
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 35,
  },
  ['19'] = {--闽北
    diangang = 1,
    zhama = 0,
    zimo = 1,
    base = 1,
    double = 9999,
    timeout = true,
    enter = {
      buyHorse = 0
    },
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 35,
  },
  ['20'] = {--起源十三水
    maxPeople = 5,
    diangang = 1,
    base = 1,
    double = 9999,
    enter = {
      buyHorse = 0
    },
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 35,
  },
  ['23'] = {---绍兴麻将
    maxPeople = 4,
    moshi1 = {
      diwuhua   = 0,
      tiandi    = 0,
      wulonghua = 0,
    },
    moshi2 = {
      keqianggang   = 0,
      longgang    = 0,
      longzimo    = 0,
      qinghun = 0,
    },
    moshi3 = {
      jianpai   = 0,
      long    = 0,
      menqing    = 0,
      tianhu = 0,
    },
    moshi4 = 1,
    moshi5 = 1,
    base = 1,
    double = 9999,
    enter = {
      buyHorse = 0
    },
    enterLimit = 0,
    leaveLimit = 0,
    btmCost = 1,
    startCost = 0,
    robot = 35,
  },
}

return allGames
