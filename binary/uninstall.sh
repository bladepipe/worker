#!/bin/bash

USERNAME="bladepipe"
USERPATH="/home/$USERNAME"

echo -e "[WARN] Do you really want to uninstall BladePipe Worker (this will remove all metadata as well) (Y/N)? \c"

read -r -e -p "" re

if [[ $re == "N" || $re == "n" ]]; then
    echo -e "Thank you for your mercy. have fun :)"
    exit
fi

echo ""
echo "Begin to uninstall BladePipe Worker..."

script_path="$USERPATH/bladepipe/worker/bin/stopWorker.sh"
if [[ -f "$script_path" ]]; then
    echo ""
    if [ "$(whoami)" == "$USERNAME" ]; then
        sh "$script_path"
    else
        su $USERNAME -c "sh $script_path"
    fi
fi

rm -rf "$USERPATH/bladepipe"
rm -rf "$USERPATH/logs"
rm -rf "$USERPATH/tar_gz"
rm -rf "$USERPATH/bak"

echo ""
echo "BladePipe Worker uninstalled..."
