#!/bin/bash

USERNAME="bladepipe"
USERPATH="/home/$USERNAME"

function tar_tgz() {
    FILENAME=$1
    total_size=$(ls -l $FILENAME | awk '{print $5}')
    block_size=$(expr $total_size / 51200)
    block_size=$(expr $block_size + 2500)

    echo ""
    echo "Begin start unzip $FILENAME file"

    tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action='ttyout=Unzip file progress: %u%    \r' -zxf $FILENAME

    echo "Finish unzip $FILENAME file"
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
            echo "Will delete old BladePipe Worker installation package and download new installation package"
            rm -rf bladepipe.tgz
            curl -O -L -f $URL
        fi
    else
        echo "Begin download installation package"
        curl -O -L -f $URL
    fi

    if [ -f bladepipe.tgz ]; then
        echo "BladePipe worker installation package ready"
    else
        echo "[ERROR] BladePipe worker installation package not exist"
        exit 4
    fi
}

function upgrade() {
    echo "Begin to upgrade BladePipe Worker..."
    echo ""

    cp $USERPATH/tar_gz/bladepipe.tgz $USERPATH/

    cd $USERPATH

    if [ "$(whoami)" == "$USERNAME" ]; then
        sh ./bladepipe/worker/bin/stopWorker.sh
    else
        su - $USERNAME -c "sh ./bladepipe/worker/bin/stopWorker.sh"
    fi

    bakPath=$USERPATH/bak/upgrade/$(date +%F)/bladepipe_$(date +%F)

    if [ ! -d "$bakPath" ]; then
        mkdir -p $bakPath
    else
        rm -rf $bakPath/*
    fi

    mv -f $USERPATH/bladepipe/{bladepipe,ds_lib,global_conf,release_info,worker,drivers} $bakPath

    tar_tgz bladepipe.tgz
    tar_tgz bladepipe-core.tar.gz
    tar_tgz bladepipe-ds.tar.gz
    tar_tgz bladepipe-worker.tar.gz

    cp -r $bakPath/global_conf/conf.properties $USERPATH/bladepipe/global_conf/conf.properties

    chown -R $USERNAME:$USERNAME $USERPATH/

    if [ "$(whoami)" == "$USERNAME" ]; then
        sh ./bladepipe/worker/bin/startWorker.sh
    else
        su - $USERNAME -c "sh ./bladepipe/worker/bin/startWorker.sh"
    fi

    task=$(jps -l | grep -E 'TaskCoreApplication')

    if [[ ! -z "$task" ]]; then
        $task | awk '{print $1}' | xargs kill -9
    fi

    rm -f bladepipe.tgz bladepipe-core.tar.gz bladepipe-ds.tar.gz bladepipe-sidecar.tar.gz

    echo ""
    echo "[SUCCESS] BladePipe Worker has been successfully upgraded. You can now access worker on https://cloud.bladepipe.com."
}

function __main() {
    echo "Begin to upgrade BladePipe Worker."
    echo ""

    init

    worker_version=$(curl -s https://download.bladepipe.com/version)

    download "https://github.com/bladepipe/worker/releases/download/v$worker_version/bladepipe.tgz"

    upgrade
}

__main
