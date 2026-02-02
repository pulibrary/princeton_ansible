#!/bin/bash
#acquiring digital archives

clear
echo -e "Where can I find the digital archives?"
read cdo

echo -e "Where should I store the digital archives?"
read dest

echo -e "Where should I store the log file?"
read log

cd /

rsync -ah --progress --stats --exclude=".*" --exclude="~*" --log-file="$log" "$cdo" "$dest"

echo -e "Process Complete"
read exit



