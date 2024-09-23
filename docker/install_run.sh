#!/bin/bash

worker_version=$(curl -s https://download.bladepipe.com/version)

echo "Welcome to the installation of BladePipe Worker, A real time data pipeline tools, worker_version:${worker_version}"
echo "If you encounter any problems, please report them to support@bladepipe.com."

echo ""
if ! command -v docker &> /dev/null
then
    echo "[ERROR] Docker is not installed. Please install Docker by following the instructions at https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null
then
    echo "[ERROR] Docker Compose is not installed. Please install Docker Compose by following the instructions at https://docs.docker.com/compose/install/"
    exit 2
fi

if [[ "$(uname)" == "Linux" ]]; then
    dockerInfoCmd=$(sudo docker info >/dev/null 2>&1)
else
    dockerInfoCmd=$(docker info >/dev/null 2>&1)
fi

if ! $dockerInfoCmd; then
    echo "[ERROR] Docker daemon is not running. Please start Docker first."
    exit 3
fi

installTopDir=/tmp/bladepipe-worker-deployment
if [ ! -d ${installTopDir} ]; then
    mkdir ${installTopDir}
else
    echo "[WARN] Directory bladepipe-worker-deployment already exists."
fi

# shellcheck disable=SC2164
cd ${installTopDir}

curl -O -L -f https://download.bladepipe.com/docker/docker-compose.yaml
if [ ! -f "docker-compose.yaml" ]; then
    echo "[ERROR] Docker compose yaml file not exist."
    exit 4
fi

echo ""
echo "Please copy your Worker 'conf.properties' on https://cloud.bladepipe.com"
echo "+------------------------------------------------------+"
read -r -e -p "" ak_input
read -r -e -p "" sk_input
read -r -e -p "" wsn_input
read -r -e -p "" domain_input
echo "+------------------------------------------------------+"

if [ -n "$ak_input" ] && [ -n "$sk_input" ] && [ -n "$wsn_input" ] && [ -n "$domain_input" ]; then
    if [[ "$(uname)" == "Linux" ]]; then
        ak=$(echo $ak_input | grep -oP '(?<=bladepipe\.auth\.ak=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        sk=$(echo $sk_input | grep -oP '(?<=bladepipe\.auth\.sk=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        wsn=$(echo $wsn_input | grep -oP '(?<=bladepipe\.worker\.wsn=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        domain=$(echo $domain_input | grep -oP '(?<=bladepipe\.console\.domain=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        ak=$(echo "$ak_input" | awk -F 'bladepipe\\.auth\\.ak=' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        sk=$(echo "$sk_input" | awk -F 'bladepipe\\.auth\\.sk=' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        wsn=$(echo "$wsn_input" | awk -F 'bladepipe\\.worker\\.wsn=' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        domain=$(echo "$domain_input" | awk -F 'bladepipe\\.console\\.domain=' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi

    echo "APP_CLIENT_AK=$ak" > .env
    echo "APP_CLIENT_SK=$sk" >> .env
    echo "APP_CLIENT_WSN=$wsn" >> .env
    echo "APP_CLOUD_DOMAIN=$domain" >> .env

    machine_arch=$(uname -m)
    if [[ $machine_arch == *"arm"* || $machine_arch == *"aarch"* ]]; then
       machine_arch="arm64"
    elif [[ $machine_arch == *"x86"* ]]; then
       machine_arch="x86"
    fi
    echo "worker_version=${worker_version}_$machine_arch" >> .env
else
    echo "[ERROR] BladePipe worker install fail, conf.properties can be not empty."
    exit 1
fi

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
    sudo docker-compose -f docker-compose.yaml up -d || exit 5
else
    docker-compose -f docker-compose.yaml up -d || exit 5
fi

echo ""
echo "[SUCCESS] BladePipe Worker has been successfully installed. You can now access worker on https://cloud.bladepipe.com."
