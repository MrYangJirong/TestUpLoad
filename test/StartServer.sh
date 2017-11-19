#!/usr/bin/env bash
#killall luvit 

#./luvit master !>/dev/null &

#./luvit game !>/dev/null &

#./luvit connector -h=116.62.221.119 !>/dev/null &

#gnome-terminal -t "nys_server_master" -x bash -c "sh ./master.sh;exec bash;"

gnome-terminal -x bash -c "./luvit master"

gnome-terminal -x bash -c "./luvit game"

gnome-terminal -x bash -c "./luvit connector -h=192.168.0.65"
