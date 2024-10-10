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

# Read the result from the temp file and clean up
worker_version=$(cat "$temp_file")
rm -f "$temp_file"

if [[ $curl_exit_status -eq 0 ]]; then
    echo -e "\n[INFO] Worker version: ${worker_version}"
    echo -e "\nWelcome to the installation of BladePipe Worker, a real-time data pipeline tool."
else
    echo -e "\n[ERROR] Failed to fetch the latest version. Please check your internet connection or try again later."
fi

echo "If you encounter any problems, please report them to support@bladepipe.com, or refer to our documentation here: https://doc.bladepipe.com/productOP/docker/install_worker_docker"

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

container_name="bladepipe-worker"
if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"; then
    echo "Container '$container_name' is running. To reinstall, run the following uninstall command first:"
    echo "/bin/bash -c \"\$(curl -fsSL https://download.bladepipe.com/docker/uninstall.sh)\""
    exit 4
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
    exit 5
fi

echo ""
echo "Please copy your worker configuration from https://cloud.bladepipe.com, then paste it below:"
echo "+------------------ PASTE CONFIG HERE ------------------+"
read -r -e -p "" ak_input
read -r -e -p "" sk_input
read -r -e -p "" wsn_input
read -r -e -p "" domain_input
echo "+---------------------- CONFIG END ---------------------+"

if [ -n "$ak_input" ] && [ -n "$sk_input" ] && [ -n "$wsn_input" ] && [ -n "$domain_input" ]; then
    if [[ "$(uname)" == "Linux" ]]; then
        ak=$(echo "$ak_input" | grep -oP '(?<=bladepipe\.auth\.ak=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        sk=$(echo "$sk_input" | grep -oP '(?<=bladepipe\.auth\.sk=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        wsn=$(echo "$wsn_input" | grep -oP '(?<=bladepipe\.worker\.wsn=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        domain=$(echo "$domain_input" | grep -oP '(?<=bladepipe\.console\.domain=).*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
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
    exit 6
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
    sudo docker-compose -f docker-compose.yaml up -d || exit 7
else
    docker-compose -f docker-compose.yaml up -d || exit 7
fi

echo ""
echo "[SUCCESS] BladePipe Worker has been successfully installed. You can now access worker on https://cloud.bladepipe.com."
