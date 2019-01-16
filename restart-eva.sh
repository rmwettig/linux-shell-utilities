#!/bin/bash

# Simple shell script that can be added to crontab to automatize an EVA restart
# Make sure that
#   pgrep searches for the right user
#   the java command uses the right paths
#   this script is added to the same user's crontab that is used for running EVA

# set configuration here if necessary
messageEmail=eva@ingef.de
serviceUser=xeva
instanceFolder=eva_ingef_2018kw31
jar=eva-backend-1.9.0.jar
config=${instanceFolder}.json
instanceType=eva
memoryLimit=150G
instanceHome="/var/eva/running/$instanceFolder"

evaProcess=$(pgrep -a -u $serviceUser java | grep $config)
terminationMessage=""
if [[ $evaProcess != "" ]]
then
  IFS=" " read -ra pinfo <<< $evaProcess
  pid=${pinfo[0]}
  pname=${pinfo[*]}
  sudo kill -15 $pid && \
    terminationMessage="Terminated PID: $pid, Command: $pname" || \
    terminationMessage="Failed to terminate PID: $pid, Command: $pname"
fi

# shell commands cannot be executed within an existing tmux session
# thus, the existing one is removed
tmux -S /var/eva/tmux-sessions/$instanceType kill-session -t 0

restartTime=$(date)
hostname=$(hostname)

# and a new session is created
# the tmux session is created as the eva service user. sudo is required here as su -c requires a password interactively otherwise.
tmuxSocket=/var/eva/tmux-sessions/$instanceType
sudo -H -u $serviceUser bash -c "cd $instanceHome; tmux -S $tmuxSocket new-session -d -s 0 'LC_ALL=de_DE.utf8 java -Xmx$memoryLimit -jar $instanceHome/$jar server $instanceHome/$config'" \
&& { mailx -s "EVA-Restart: Started" $messageEmail << BODY
  $terminationMessage
  Restarting EVA
    on $hostname
    at $restartTime

Instance home: $instanceHome

Tmux
  Socket: $tmuxSocket
  Session: 0
BODY
} \
|| mailx -s "EVA-Restart: Failed" $messageEmail << BODY
Failed to restart $instanceType as $serviceUser
BODY

# remove restart job
crontab -r
