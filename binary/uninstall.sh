#!/bin/bash

USERNAME="bladepipe"
USERPATH="/home/$USERNAME"

echo -e "[WARN] Do you really want to uninstall BladePipe Worker (this will remove all metadata as well)? \c"

read -r -e -p "(Y/N):" re

if [[ $re == "N" || $re == "n" ]]; then
    echo -e "Thank you for your mercy. have fun :)"
    exit
fi

echo ""
echo "Begin to uninstall BladePipe Worker..."

rm -rf "$USERPATH/bladepipe"
rm -rf "$USERPATH/logs"
rm -rf "$USERPATH/tar_gz"

echo ""
echo "BladePipe Worker uninstalled..."
