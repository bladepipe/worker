#!/bin/bash

USERNAME="bladepipe"
USERPATH="/home/$USERNAME"

function tar_tgz() {
    FILENAME=$1
    total_size=$(ls -l $FILENAME | awk '{print $5}')
    block_size=$(expr $total_size / 51200)
    block_size=$(expr $block_size + 2500)

    echo ""
    echo "Begin start unzip $FILENAME file."

    tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action='ttyout=Unzip file progress: %u%    \r' -zxf $FILENAME

    echo "Finish unzip $FILENAME file."
    echo ""
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
}

function download() {
    URL=$1
    cd $USERPATH/tar_gz/
    if [ -f bladepipe.tgz ]; then
        echo -e "If you want to delete the old BladePipe Worker installation package and download it again(Y/N)? \c"
        read -r -e -p "" re
        if [[ $re == "Y" || $re == "y" ]]; then
            echo "Will delete old BladePipe Worker installation package and download new installation package."
            rm -rf bladepipe.tgz
            curl -O -L -f $URL
        fi
    else
        echo "Begin download installation package."
        curl -O -L -f $URL
    fi

    if [ -f bladepipe.tgz ]; then
        echo "BladePipe worker installation package ready."
    else
        echo "[ERROR] BladePipe worker installation package not exist."
        exit 4
    fi
}

function install() {
    echo "Begin to start Install BladePipe Worker..."
    echo ""
    echo "Please copy your Worker 'conf.properties' on https://cloud.bladepipe.com"
    echo "+------------------------------------------------------+"
    read -r -e -p "" ak_input
    read -r -e -p "" sk_input
    read -r -e -p "" wsn_input
    read -r -e -p "" domain_input
    echo "+------------------------------------------------------+"

    if [ -n "$ak_input" ] && [ -n "$sk_input" ] && [ -n "$wsn_input" ] && [ -n "$domain_input" ]; then
        cp $USERPATH/tar_gz/bladepipe.tgz $USERPATH/

        cd $USERPATH

        tar_tgz bladepipe.tgz
        tar_tgz bladepipe-core.tar.gz
        tar_tgz bladepipe-ds.tar.gz
        tar_tgz bladepipe-worker.tar.gz

        echo "$ak_input" > $USERPATH/bladepipe/global_conf/conf.properties
        echo "$sk_input" >> $USERPATH/bladepipe/global_conf/conf.properties
        echo "$wsn_input" >> $USERPATH/bladepipe/global_conf/conf.properties
        echo "$domain_input" >> $USERPATH/bladepipe/global_conf/conf.properties

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
        echo "[ERROR] BladePipe worker install fail, conf.properties can be not empty."
        exit 5
    fi
}

function __main() {
    worker_version=$(curl -s https://download.bladepipe.com/version)

    echo "Welcome to the installation of BladePipe Worker, A real time data pipeline tools, worker_version:${worker_version}"
    echo "If you encounter any problems, please report them to support@bladepipe.com."

    init

    download "https://github.com/bladepipe/worker/releases/download/v$worker_version/bladepipe.tgz"

    install
}

__main
