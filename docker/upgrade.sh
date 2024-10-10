#!/bin/bash

# Run the curl command in the background and write the output to a temporary file
temp_file=$(mktemp)
curl -s -L -f https://download.bladepipe.com/version > "$temp_file" &
curl_pid=$!

# Display a loading spinner while waiting for the curl command to finish
spin='-\|/'
i=0
while kill -0 $curl_pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\rFetching the latest version... ${spin:$i:1}"
    sleep 0.1
done

# Wait for curl to finish
wait $curl_pid
curl_exit_status=$?
printf "\r\033[K"

# Read the result from the temp file and clean up
worker_version=$(cat "$temp_file")
rm -f "$temp_file"

if [[ $curl_exit_status -eq 0 ]]; then
    echo -e "\n[INFO] Worker version: ${worker_version}"
    echo -e "\nWelcome to the upgrade of BladePipe Worker, a real-time data pipeline tool."
else
    echo -e "\n[ERROR] Failed to fetch the latest version. Please check your internet connection or try again later."
    exit 1
fi

echo "If you encounter any problems, please report them to support@bladepipe.com, or refer to our documentation here: https://doc.bladepipe.com/productOP/docker/upgrade_worker_docker/"

echo ""
bladepipe_name=bladepipe
if [[ $(docker ps -a | grep $bladepipe_name) != "" ]]; then
  # shellcheck disable=SC2046
  old_worker_version=$(docker ps -a | grep $bladepipe_name | awk '{print $2}')
  echo "Old_worker_version:$old_worker_version -> Latest_worker_version:$worker_version."
else
  echo "[ERROR] Please install BladePipe Worker first, latest_worker_version:$worker_version, run below command:"
  echo "/bin/bash -c \"\$(curl -fsSL https://download.bladepipe.com/docker/install_run.sh)\""
  exit 2
fi

echo ""
if ! command -v docker &> /dev/null
then
    echo "[ERROR] Docker is not installed. Please install Docker by following the instructions at https://docs.docker.com/get-docker/"
    exit 3
fi

if ! command -v docker-compose &> /dev/null
then
    echo "[ERROR] Docker Compose is not installed. Please install Docker Compose by following the instructions at https://docs.docker.com/compose/install/"
    exit 4
fi

if [[ "$(uname)" == "Linux" ]]; then
    dockerInfoCmd=$(sudo docker info >/dev/null 2>&1)
else
    dockerInfoCmd=$(docker info >/dev/null 2>&1)
fi

if ! $dockerInfoCmd; then
    echo "[ERROR] Docker daemon is not running. Please start Docker first."
    exit 5
fi

installTopDir=/tmp/bladepipe-worker-deployment
if [ ! -d ${installTopDir} ]; then
    mkdir ${installTopDir}
else
    # shellcheck disable=SC2115
    rm -rf ${installTopDir}/*
fi

# shellcheck disable=SC2164
cd ${installTopDir}

curl -O -L -f https://download.bladepipe.com/docker/docker-compose.yaml
if [ ! -f "docker-compose.yaml" ]; then
    echo "[ERROR] Docker compose yaml file not exist."
    exit 6
fi

machine_arch=$(uname -m)
if [[ $machine_arch == *"arm"* || $machine_arch == *"aarch"* ]]; then
   machine_arch="arm64"
elif [[ $machine_arch == *"x86"* ]]; then
   machine_arch="x86"
fi
echo "worker_version=${worker_version}_$machine_arch" > .env

echo ""
log_volume_name=bladepipe_worker_log_volume
if [[ $(docker volume ls | grep $log_volume_name) == "" ]]; then
    echo "Begin to create bladepipe_worker_log_volume..."
    docker volume create $log_volume_name
    echo -e "Create bladepipe_worker_log_volume successfully."
else
    echo "Volume bladepipe_worker_log_volume is already exist.reuse it."
fi

echo ""
config_volume_name=bladepipe_worker_config_volume
if [[ $(docker volume ls | grep $config_volume_name) == "" ]]; then
    echo "Begin to create bladepipe_worker_config_volume..."
    docker volume create $config_volume_name
    echo -e "Create bladepipe_worker_config_volume successfully."
else
    echo "Volume bladepipe_worker_config_volume is already exist.reuse it."
fi

echo ""
if [[ "$(uname)" == "Linux" ]]; then
    echo "Please enter your password for sudo:"
    sudo docker-compose -f docker-compose.yaml up -d || exit 7
else
    docker-compose -f docker-compose.yaml up -d || exit 7
fi

echo ""
echo "[SUCCESS] BladePipe Worker has been successfully upgraded. You can now access worker on https://cloud.bladepipe.com"
