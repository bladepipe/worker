#!/bin/bash

USERNAME="bladepipe"
USERPATH="/home/$USERNAME"

function tar_tgz() {
    FILENAME=$1
    total_size=$(ls -l $FILENAME | awk '{print $5}')
    block_size=$(expr $total_size / 51200)
    block_size=$(expr $block_size + 2500)

    echo ""
    echo "Begin to start unzip $FILENAME file."

    tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action='ttyout=Unzip file progress: %u%    \r' -zxf $FILENAME

    echo "Finish unzip $FILENAME file."
}

function init() {
    if ! id "$USERNAME" &>/dev/null; then
        echo "[ERROR] User '$USERNAME' does not exist."
        echo "[ERROR] Please add the user '$USERNAME' and grant NOPASSWD sudo permissions."
        echo "To add the user and grant permissions, you can run the following commands:"
        echo "    sudo useradd -d $USERPATH -m $USERNAME"
        echo "    sudo bash -c 'echo \"$USERNAME ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
        exit 2
    fi

    if ! command -v java &>/dev/null; then
        echo "[ERROR] Java is not installed. Please install Java by following the instructions at https://openjdk.org/projects/jdk8/"
        exit 3
    fi

    cd $USERPATH

    if [ ! -d $USERPATH/tar_gz/ ]; then
        mkdir $USERPATH/tar_gz/
    fi

    chown -R $USERNAME:$USERNAME $USERPATH/

    worker_app="SidecarApplication"
    if jps | grep -q "$worker_app"; then
        echo "[WARN] Worker exists... To reinstall, run the following uninstall command first:"
        echo "/bin/bash -c \"\$(curl -fsSL https://download.bladepipe.com/binary/uninstall.sh)\""
        exit 4
    fi
}

function download() {
    URL=$1
    cd $USERPATH/tar_gz/
    if [ -f bladepipe.tgz ]; then
        echo -e "[INFO] Do you want to delete the old BladePipe Worker installation package and download it again (Y/N)? \c"
        read -r -e -p "" re
        if [[ $re == "Y" || $re == "y" ]]; then
            echo "Will delete old BladePipe Worker installation package and download new installation package."
            rm -rf bladepipe.tgz
            echo ""
            curl -O -L -f $URL
        fi
    else
        echo "Begin to download installation package."
        echo ""
        curl -O -L -f $URL
    fi

    echo ""
    if [ -f bladepipe.tgz ]; then
        echo "BladePipe worker installation package ready."
    else
        echo "[ERROR] BladePipe worker installation package not exist."
        exit 5
    fi
}

function install() {
    echo "Please copy your Worker configuration from https://cloud.bladepipe.com, then paste it below:"
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
    done <<< "$config_block"

    echo "+---------------------- CONFIG END ---------------------+"

    if [ -n "$ak_input" ] && [ -n "$sk_input" ] && [ -n "$wsn_input" ] && [ -n "$domain_input" ]; then
        cp $USERPATH/tar_gz/bladepipe.tgz $USERPATH/

        cd $USERPATH

        tar_tgz bladepipe.tgz
        tar_tgz bladepipe-core.tar.gz
        tar_tgz bladepipe-ds.tar.gz
        tar_tgz bladepipe-worker.tar.gz

        echo ""
        echo "bladepipe.auth.ak=$ak_input" > $USERPATH/bladepipe/global_conf/conf.properties
        echo "bladepipe.auth.sk=$sk_input" >> $USERPATH/bladepipe/global_conf/conf.properties
        echo "bladepipe.worker.wsn=$wsn_input" >> $USERPATH/bladepipe/global_conf/conf.properties
        echo "bladepipe.console.domain=$domain_input" >> $USERPATH/bladepipe/global_conf/conf.properties

        chown -R $USERNAME:$USERNAME $USERPATH/

        if [ "$(whoami)" == "$USERNAME" ]; then
            sh ./bladepipe/worker/bin/startWorker.sh
        else
            su $USERNAME -c "sh ./bladepipe/worker/bin/startWorker.sh"
        fi

        rm -f bladepipe.tgz bladepipe-core.tar.gz bladepipe-ds.tar.gz bladepipe-worker.tar.gz

        echo ""
        echo "[SUCCESS] BladePipe Worker has been successfully installed. You can now access worker on https://cloud.bladepipe.com."
    else
        echo ""
        echo "[ERROR] BladePipe worker install fail, configuration can be not empty."
        exit 6
    fi
}

function __main() {
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
        echo -e "\nWelcome to the installation of BladePipe Worker, a real-time data pipeline tool."
    else
        echo -e "\n[ERROR] Failed to fetch the latest version. Please check your internet connection or try again later."
        exit 1
    fi

    echo "If you encounter any problems, please report them to support@bladepipe.com, or refer to our documentation here: https://doc.bladepipe.com/productOP/binary/install_worker_binary/"

    echo ""

    # init bladepipe user
    init

    # download the bladepipe worker
    download "https://github.com/bladepipe/worker/releases/download/v$worker_version/bladepipe.tgz"

    echo ""

    # begin to install
    install
}

__main
