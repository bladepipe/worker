#!/bin/bash

# Run the curl command in the background and write the output to a temporary file
temp_file=$(mktemp)
curl -s -L -f https://download.bladepipe.com/version >"$temp_file" &
curl_pid=$!

# Display a loading spinner while waiting for the curl command to finish
spin='-\|/'
i=0
while kill -0 $curl_pid 2>/dev/null; do
    i=$(((i + 1) % 4))
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
    echo -e "\nWelcome to the installation of BladePipe Worker, a real-time data pipeline tool."
else
    echo -e "\n[ERROR] Failed to fetch the latest version. Please check your internet connection or try again later."
    exit 1
fi

echo "If you encounter any problems, please report them to support@bladepipe.com, or refer to our documentation here: https://doc.bladepipe.com/productOP/docker/install_worker_docker/"

echo ""
if ! command -v docker &>/dev/null; then
    echo "[ERROR] Docker is not installed. Please install Docker by following the instructions at https://docs.docker.com/get-docker/"
    exit 2
fi

if ! command -v docker-compose &>/dev/null; then
    echo "[ERROR] Docker Compose is not installed. Please install Docker Compose by following the instructions at https://docs.docker.com/compose/install/"
    exit 3
fi

docker_command() {
    if [[ "$(uname)" == "Linux" && $(id -u) -ne 0 ]]; then
        echo "Please enter your password for sudo:"
        sudo docker "$@"
    else
        docker "$@"
    fi
}

dockerInfoCmd=$(docker_command info >/dev/null 2>&1)

if ! $dockerInfoCmd; then
    echo "[ERROR] Docker daemon is not running. Please start Docker first."
    exit 4
fi

container_name="bladepipe-worker"
if docker_command ps -a --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"; then
    echo "[WARN] Container '$container_name' exists... To reinstall, run the following uninstall command first:"
    echo "/bin/bash -c \"\$(curl -fsSL https://download.bladepipe.com/docker/uninstall.sh)\""
    exit 5
fi

log_volume_name=bladepipe_worker_log_volume
if [[ $(docker_command volume ls | grep $log_volume_name) != "" ]]; then
    echo "Begin to delete old $log_volume_name..."
    docker_command volume rm $log_volume_name || exit 6
    echo -e "Delete old $log_volume_name successfully."
    echo ""
fi

config_volume_name=bladepipe_worker_config_volume
if [[ $(docker volume ls | grep $config_volume_name) != "" ]]; then
    echo "Begin to delete old $config_volume_name..."
    docker_command volume rm $config_volume_name || exit 7
    echo -e "Delete old $config_volume_name successfully."
    echo ""
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
    exit 8
fi

echo ""
echo "Please copy your worker configuration from https://cloud.bladepipe.com, then paste it below:"
echo "+------------------ PASTE CONFIG HERE ------------------+"

read_non_empty_input_block() {
    local input result=""
    local count=0

    while true; do
        IFS= read -r input
        input=$(echo "$input" | xargs)

        if [[ -n "$input" ]]; then
            result="${result}${input}"$'\n'
            count=$((count + 1))

            if [[ $count -eq 4 ]]; then
                break
            fi
        fi
    done

    echo "$result"
}

# Read the configuration block
config_block=$(read_non_empty_input_block)

# Parse each line and extract the values
while IFS= read -r line; do
    if [[ "$line" == *bladepipe.auth.ak=* ]]; then
        ak_input="${line#*=}"
    elif [[ "$line" == *bladepipe.auth.sk=* ]]; then
        sk_input="${line#*=}"
    elif [[ "$line" == *bladepipe.worker.wsn=* ]]; then
        wsn_input="${line#*=}"
    elif [[ "$line" == *bladepipe.console.domain=* ]]; then
        domain_input="${line#*=}"
    fi
done <<<"$config_block"

echo "+---------------------- CONFIG END ---------------------+"

if [ -n "$ak_input" ] && [ -n "$sk_input" ] && [ -n "$wsn_input" ] && [ -n "$domain_input" ]; then
    echo "APP_CLIENT_AK=$ak_input" >.env
    echo "APP_CLIENT_SK=$sk_input" >>.env
    echo "APP_CLIENT_WSN=$wsn_input" >>.env
    echo "APP_CLOUD_DOMAIN=$domain_input" >>.env
    echo "worker_version=${worker_version}" >>.env
else
    echo "[ERROR] BladePipe worker install fail, configuration can be not empty."
    exit 9
fi

echo ""
if [[ $(docker_command volume ls | grep $log_volume_name) == "" ]]; then
    echo "Begin to create $log_volume_name..."
    docker_command volume create $log_volume_name || exit 10
    echo -e "Create $log_volume_name successfully."
else
    echo "Volume $log_volume_name is already exist.reuse it."
fi

echo ""
if [[ $(docker_command volume ls | grep $config_volume_name) == "" ]]; then
    echo "Begin to create $config_volume_name..."
    docker_command volume create $config_volume_name || exit 11
    echo -e "Create $config_volume_name successfully."
else
    echo "Volume $config_volume_name is already exist.reuse it."
fi

docker_compose_command() {
    if ! command -v docker-compose &>/dev/null; then
        if [[ "$(uname)" == "Linux" && $(id -u) -ne 0 ]]; then
            echo "Please enter your password for sudo:"
            sudo docker-compose "$@"
        else
            docker-compose "$@"
        fi
    else
        if [[ "$(uname)" == "Linux" && $(id -u) -ne 0 ]]; then
            echo "Please enter your password for sudo:"
            sudo docker compose "$@"
        else
            docker compose "$@"
        fi
    fi
}

echo ""
docker_compose_command -f docker-compose.yaml up -d || exit 9

echo ""
echo "[SUCCESS] BladePipe Worker has been successfully installed. You can now access worker on https://cloud.bladepipe.com"
