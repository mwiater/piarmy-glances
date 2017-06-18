#!/bin/bash
### BEGIN INIT INFO
# Provides:          glances
# Required-Start:    
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: The glances daemon
# Description:       The glances daemon
### END INIT INFO

# sudo cp /home/pi/projects/piarmy-glances/glances_boot.sh /etc/init.d/glances.sh && \
#   sudo chmod +x /etc/init.d/glances.sh && \
#   sudo update-rc.d glances.sh defaults 100

# FIX:
# Don't use dash: https://ubuntuforums.org/showthread.php?t=1377218
# sudo dpkg-reconfigure dash

# WS TEST:
# . send_ws_message.sh '{"msgType":"loadStatus", "msgData":{"node":"piarmy01","status":"red"}}' && \
#   sleep 1 && \
#   . send_ws_message.sh '{"msgType":"loadStatus", "msgData":{"node":"piarmy01","status":"yellow"}}' && \
#   sleep 1 && \
#   . send_ws_message.sh '{"msgType":"loadStatus", "msgData":{"node":"piarmy01","status":"green"}}' && \
#   sleep 1 && \
#   . send_ws_message.sh '{"msgType":"loadStatus", "msgData":{"node":"piarmy01","status":"off"}}'

hostname=$(hostname)

ps -ef | grep "nc " | grep -v grep | awk '{print $2}' | xargs kill -9

if pgrep -x "glances" > /dev/null ; then
    echo "Process: glances is already running..."
else
  if [ ! -e "/usr/local/bin/glances" ] ; then
    #echo "Process: starting glances..."
    sudo /home/pi/.local/bin/glances -w -p 81 >/dev/null 2>&1 &
  else
    #echo "Process: starting glances..."
    sudo /usr/local/bin/glances -w -p 81 >/dev/null 2>&1 &
  fi
fi

sysInfo=/home/pi/projects/piarmy-glances/data/sysInfo-$hostname.json
tmpFile=/home/pi/projects/piarmy-glances/data/tmp.json

if [ ! -e $sysInfo ] ; then
  touch $sysInfo
  chmod 777 $sysInfo
fi

if [ ! -e $tmpFile ] ; then
  touch $tmpFile
  chmod 777 $tmpFile
fi

# float number comparison
# http://stackoverflow.com/questions/11541568/how-to-do-float-comparison-in-bash
fcomp (){
  awk -v n1=$1 -v n2=$2 'BEGIN {if (n1<n2) exit 0; exit 1}'
}

while true; do
  sysinfo=$(curl -s http://$hostname:81/api/2/all)

  if [ "${sysinfo}" == "" ] ; then
    echo "No response from server, sleeping for 10..."
    sleep 10
  else 
    sysinfo=$(echo $sysinfo | jq -c 'del(.processlist)')

    curl -s http://$hostname:81/api/2/all | jq -c 'del(.processlist)' | tee $tmpFile >/dev/null 2>&1 && \
      cp $tmpFile $sysInfo

    hostCPU=$(curl -s http://$hostname:81/api/2/quicklook/cpu | jq '.cpu')
    hostCPU=${hostCPU%.*}

    hostRAM=$(curl -s http://$hostname:81/api/2/quicklook/mem | jq '.mem')
    hostRAM=${hostRAM%.*}

    status=0

    if [[ "$status" -lt "$hostCPU" ]] ; then
      status=${hostCPU}
    fi

    if [[ "$hostCPU" -lt "$hostRAM" ]] && [[ "$status" -lt "$hostRAM" ]] ; then
      status=${hostRAM}
    fi

    if [ "$status" -gt 75 ]; then
      . /home/pi/projects/piarmy-glances/send_ws_message.sh "{\"msgType\":\"loadStatus\", \"msgData\":{\"node\":\"$hostname\",\"status\":\"red\"}}"
    elif [ "$status" -gt 50 ]; then
      . /home/pi/projects/piarmy-glances/send_ws_message.sh "{\"msgType\":\"loadStatus\", \"msgData\":{\"node\":\"$hostname\",\"status\":\"yellow\"}}"
    else
      . /home/pi/projects/piarmy-glances/send_ws_message.sh "{\"msgType\":\"loadStatus\", \"msgData\":{\"node\":\"$hostname\",\"status\":\"green\"}}"
    fi
  fi
done