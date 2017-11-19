local GroupStruct = {}

-- 用户信息
function GroupStruct.userInfo(playerId, nickname, uid, avatar)
    return {
        playerId = playerId or 000000,
        nickname = nickname or "",
        uid = uid or "",
        avatar = avatar or "",
    }
end

function GroupStruct.userInfo_user(user)
    user = user or {}
    return {
        playerId = user.playerId or 000000,
        nickname = user.nickName or "",
        uid = user.uid or "",
        avatar = user.avatar or "",
    }
end

-- userInfo:GroupStruct.userInfo
function GroupStruct.adminMsg(type, userInfo)
    return {
        msgType = type or '',
        userInfo = userInfo,
    }
end

return GroupStruct