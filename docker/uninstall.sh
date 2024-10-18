#!/bin/bash

echo -e "[WARN] Do you really want to uninstall BladePipe Worker (this will remove all metadata as well) (Y/N)? \c"

read -r -e -p "" re

if [[ $re == "N" || $re == "n" ]]; then
   echo -e "Thank you for your mercy. have fun :)"
   exit
fi

echo ""
echo "Begin to uninstall BladePipe Worker..."
echo ""

rm -rf /tmp/bladepipe-worker-deployment

docker_command() {
    if [[ "$(uname)" == "Linux" && $(id -u) -ne 0 ]]; then
        echo "Please enter your password for sudo:"
        sudo docker "$@"
    else
        docker "$@"
    fi
}

echo "Begin to delete BladePipe Worker docker containers."
bladepipe_name=bladepipe
if [[ $(docker_command ps -a | grep $bladepipe_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker_command rm -f $(docker_command ps -a | grep $bladepipe_name |awk '{print $1}')
fi
echo "BladePipe Worker docker containers deleted."
echo ""

echo "Begin to delete BladePipe Worker docker images."
docker_container=bladepipe
if [[ $(docker_command image ls | grep $docker_container) != "" ]]; then
  # shellcheck disable=SC2046
  docker_command rmi -f $(docker_command image ls | grep $docker_container | awk '{print $3}')
fi
echo "BladePipe Worker docker images deleted."
echo ""

echo "Begin to delete BladePipe Worker volumes."
log_volume_name=bladepipe_worker_log_volume
if [[ $(docker_command volume ls | grep $log_volume_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker_command volume rm -f $(docker_command volume ls | grep $log_volume_name | awk '{print $2}')
fi

config_volume_name=bladepipe_worker_config_volume
if [[ $(docker_command volume ls | grep $config_volume_name) != "" ]]; then
  # shellcheck disable=SC2046
  docker_command volume rm -f $(docker_command volume ls | grep $config_volume_name | awk '{print $2}')
fi
echo "BladePipe Worker volumes deleted."
echo ""

echo "BladePipe Worker uninstalled..."