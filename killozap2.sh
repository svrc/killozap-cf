#!/bin/bash
# New v2.0!  Only change is it uses bosh v2cli and now requires jq.
# Hunts for consul or etcd instances, shuts them all down, nukes their storage, the restarts them
# Presumes PCF job name patterns
# Useful for quorum loss

export COMMAND=bosh

if [[ ($1 == "consul-all") || ($1 == "consul-servers") || ($1 == "consul-restart") || ($1 == "brain-restart") || ($1 == "etcd" ) || ($1 == "bbs" ) || ($1 == "ripley") || ($1 == "cells") ]]
        then
                echo "Kill-o-Zapping your current CF deployment... "
        else
                echo "Usage: $0 [consul-all | consul-restart | brain-restart | bbs | etcd | cells | ripley]"
		echo ""
		echo "Make sure your BOSH environment variables are all set!  BOSH_DEPLOYMENT , BOSH_ENVIRONMENT, BOSH_CA_CERT at minimum"
		echo ""
                echo "consul-all will stop all consul_agent processes globally, delete /var/vcap/store/consul_agent/* recursively, and restart them"
                echo "consul-servers will stop all consul_server consul_agent processes, delete /var/vcap/store/consul_agent/* recursively, and restart them"
                echo "consul-restart will restart all consul_agent processes globally"
                echo "brain-restart will restart all diego brain processes, may be needed after a consul reset"
                echo "bbs will stop all diego bbs etcd processes, delete /var/vcap/store/etcd/* recursively, and restart them"
                echo "etcd will stop all non-diego-bbs etcd job processes, delete /var/vcap/store/etcd/* recursively, and restart them"
                echo "cells will stop all diego_cell consul_agent job processes, delete /var/vcap/store/consul_agent/* recursively, and restart them"
                echo "ripley will nuke the site from orbit; aka stop, delete, restart all etcd and consul_agent processes"
                exit 1
fi


stopProcesses() {
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }' | awk -F ',' '{ print $1 }')
     if [ $1 == "all" ]; then
       echo Stopping all processes: $jobId Instance: $instanceId 
       $COMMAND ssh $jobId/$instanceId "sudo -s /var/vcap/bosh/bin/monit stop all"
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Stopping: $jobId Instance: $instanceId Process $processId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s /var/vcap/bosh/bin/monit stop $processId"
     fi
  done
}

restartProcesses() {
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }' | awk -F ',' '{ print $1 }')
     if [ -z $instanceId ]; then
       continue
     fi
     if [ "all" == $1 ]; then
       echo Restarting all processes: $jobId Instance: $instanceId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s /var/vcap/bosh/bin/monit restart all"
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Restarting: $jobId Instance: $instanceId Process $processId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s /var/vcap/bosh/bin/monit restart $processId"
     fi
  done
}

startProcesses() {
  for x in $jobVMs; do
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }' | awk -F ',' '{ print $1 }')
     if [ "all" == $1 ]; then
       echo Starting all processes: $jobId Instance: $instanceId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s /var/vcap/bosh/bin/monit start all"
       continue
     fi
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Starting: $jobId Instance: $instanceId Process $processId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s /var/vcap/bosh/bin/monit start $processId"
     fi
  done
}


nukeProcesses() {
  for x in $jobVMs; do 
     jobId=$(echo $x | awk -F "/" '{ print $1 }')
     instanceId=$(echo $x | awk -F "/" '{ print $2 }' | awk -F ',' '{ print $1 }')
     processId=$(echo $x | awk -F "," '{ print $2 }')
     if [ -z $processId ]; then
       continue
     fi
     if [ $processId = $1 ]; then
       echo Deleting: $jobId Instance: $instanceId Directory /var/vcap/store/$processId
       $COMMAND ssh ${jobId}/${instanceId} "sudo -s rm -rf /var/vcap/store/$processId/*"
     fi
  done
}

if [ $1 == "brain-restart" ]; then
 jobVMs=$($COMMAND instances |  awk -F '|' '{ print $2 }' | grep diego_brain)
 restartProcesses all 
fi


if [ $1 == "consul-all" ]; then
 allJobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_agent)
 jobVMs=$allJobVMs
 stopProcesses consul_agent
 nukeProcesses consul_agent
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 # Start the consul server cluster first.
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_server)
 startProcesses consul_agent
 echo Waiting 30 seconds for processes to finish starting
 sleep 30
 jobVMs=$allJobVMs
 startProcesses consul_agent
fi

if [ $1 == "consul-servers" ]; then
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_server)
 stopProcesses consul_agent
 nukeProcesses consul_agent
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 startProcesses consul_agent
fi

if [ $1 == "consul-restart" ]; then
 allJobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_agent)
 jobVMs=$allJobVMs
 stopProcesses consul_agent
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 # Start the consul server cluster first.
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_server)
 startProcesses consul_agent
 echo Waiting 30 seconds for processes to finish starting
 sleep 30
 jobVMs=$allJobVMs
 startProcesses consul_agent
fi

if [ $1 == "etcd" ]; then
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep etcd_server)
 stopProcesses etcd
 nukeProcesses etcd
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep etcd_tls_server)
 stopProcesses etcd
 nukeProcesses etcd
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep etcd_server)
 startProcesses etcd
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep etcd_tls_server)
 startProcesses etcd
fi

if [ $1 == "cells" ]; then
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep diego_cell)
 stopProcesses consul_agent
 nukeProcesses consul_agent
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 startProcesses consul_agent
fi

if [ $1 == "bbs" ]; then
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep diego_database)
 stopProcesses etcd
 nukeProcesses etcd
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 startProcesses etcd
fi

if [ $1 == "ripley" ]; then
 jobVMs=$($COMMAND  instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g')
 allJobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g')
 jobVMs=$allJobVMs
 stopProcesses consul_agent
 nukeProcesses consul_agent
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 # Start the consul server cluster first.
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep consul_server)
 startProcesses consul_agent
 jobVMs=$allJobVMs
 echo Waiting 30 seconds for processes to finish starting
 sleep 30
 startProcesses consul_agent
 stopProcesses etcd
 nukeProcesses etcd
 echo Waiting 30 seconds for processes to finish exiting
 sleep 30
 startProcesses etcd
 jobVMs=$($COMMAND instances -p --json | jq -r '.Tables[0].Rows[] | select(.process != "") | [ .instance, .process ] | @csv' | sed 's/"//g' | grep diego_brain)
 restartProcesses all
fi

