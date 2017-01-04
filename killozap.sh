#!/bin/bash
# Hunts for consul or etcd instances, shuts them all down, nukes their storage, the restarts them
# Presumes PCF job name patterns
# Useful for quorum loss

if [[ ($1 == "consul-all") || ($1 == "consul-restart") || ($1 == "etcd" ) || ($1 == "bbs" ) || ($1 == "ripley") || ($1 == "cells") ]]
        then
                echo "Kill-o-Zapping your current CF deployment... "
        else
                echo "Usage: $0 [consul ([all|)|bbs|etcd|ripley]"
		echo ""
                echo "consul-all will stop all consul_agent processes globally, delete /var/vcap/store/consul_agent/* recursively, and restart them"
                echo "consul-restart will restart all consul_agent processes globally"
                echo "bbs will stop all diego bbs etcd processes, delete /var/vcap/store/etcd/* recursively, and restart them"
                echo "etcd will stop all non-diego-bbs etcd job processes, delete /var/vcap/store/etcd/* recursively, and restart them"
                echo "cells will stop all diego_cell consul_agent job processes, delete /var/vcap/store/consul_agent/* recursively, and restart them"
                echo "ripley will nuke the site from orbit; aka stop, delete, restart all etcd and consul_agent processes"
                exit 1
fi


restartProcesses() {
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }'| awk -F '(' '{ print $1 }')
     if [ -z $instanceId ]; then
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Restarting: $jobId Instance: $instanceId Process $processId
       bosh ssh $jobId $instanceId "sudo -s /var/vcap/bosh/bin/monit restart $processId"
     fi
  done
}

nukeProcesses() {
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }'| awk -F '(' '{ print $1 }')
     if [ -z $instanceId ]; then
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Stopping: $jobId Instance: $instanceId Process $processId
       bosh ssh $jobId $instanceId "sudo -s /var/vcap/bosh/bin/monit stop $processId"
     fi
  done
  for x in $jobVMs; do 
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }'| awk -F '(' '{ print $1 }')
     if [ -z $instanceId ]; then
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Deleting: $jobId Instance: $instanceId Directory /var/vcap/store/$processId
       bosh ssh $jobId $instanceId "sudo -s rm -rf /var/vcap/store/$processId/*"
     fi
  done
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }'| awk -F '(' '{ print $1 }')
     if [ -z $instanceId ]; then
       continue
     fi 
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Starting: $jobId Instance: $instanceId Process $processId
       bosh ssh $jobId $instanceId "sudo -s /var/vcap/bosh/bin/monit start $processId"
     fi
  done
}




if [ $1 == "consul-all" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }')
 nukeProcesses consul_agent
fi

if [ $1 == "consul-restart" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }')
 restartProcesses consul_agent
fi

if [ $1 == "etcd" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }'| grep etcd_server)
 nukeProcesses etcd
fi

if [ $1 == "cells" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }'| grep diego_cell)
 nukeProcesses consul_agent
fi

if [ $1 == "bbs" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }'| grep diego_database)
 nukeProcesses etcd
fi

if [ $1 == "ripley" ]; then
 jobVMs=$(bosh instances --ps | awk -F "|" 'RS="\\+\\-\\-" {gsub(/ /, "", $0); for (i=2; i<= NF; i+=6) printf "%s\n", (i>2) ? $2 "," $i : "" }')
 nukeProcesses consul_agent
 nukeProcesses etcd
fi

