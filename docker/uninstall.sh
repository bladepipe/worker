#!/bin/bash

echo -e "[WARN] Do you really want to uninstall BladePipe Worker (this will remove all metadata as well)? \c"

read -r -e -p "(Y/N):" re

if [[ $re == "N" || $re == "n" ]]; then
   echo -e "Thank you for your mercy. have fun :)"
   exit
fi

echo ""
echo "Begin to uninstall BladePipe Worker..."
echo ""

rm -rf /tmp/bladepipe-worker-deployment

echo "Begin to delete BladePipe Worker docker containers."
bladepipe_name=bladepipe
if [[ $(docker ps -a | grep $bladepipe_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker rm -f $(docker ps -a | grep $bladepipe_name |awk '{print $1}')
fi
echo "BladePipe Worker docker containers deleted."
echo ""

echo "Begin to delete BladePipe Worker docker images."
docker_container=bladepipe
if [[ $(docker image ls | grep $docker_container) != "" ]]; then
  # shellcheck disable=SC2046
  docker rmi -f $(docker image ls | grep $docker_container | awk '{print $3}')
fi
echo "BladePipe Worker docker images deleted."
echo ""

echo "Begin to delete BladePipe Worker volumes."
log_volume_name=bladepipe_worker_log_volume
if [[ $(docker volume ls | grep $log_volume_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker volume rm -f $(docker volume ls | grep $log_volume_name | awk '{print $2}')
fi

config_volume_name=bladepipe_worker_config_volume
if [[ $(docker volume ls | grep $config_volume_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker volume rm -f $(docker volume ls | grep $config_volume_name | awk '{print $2}')
fi
echo "BladePipe Worker volumes deleted."
echo ""

echo "BladePipe Worker uninstalled..."