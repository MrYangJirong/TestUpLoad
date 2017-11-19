// add cheat user

// args
var arg_playerId = NumberInt(100016); // playerId uid int32


// logic
var user = db.user.find({'playerId':arg_playerId});
while(user.hasNext()){
    r = user.next();
    db.cheat.update({'playerId':arg_playerId},
    {$set:
        {
            'playerId':r['playerId'],
            'nickName':r["nickName"],
            'uid':r['uid']
        }
     },
     {'upsert':true,'multi':false}
     );   
    break;
}











