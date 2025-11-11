#!/bin/bash
#acquiring digital archives

clear
echo -e "Where is the disk image mounted?"
read cdo

echo -e "Where should I store the extracted files?"
read dest

cd /

rsync -ah --progress --stats --exclude=".*" --exclude="~*" --log-file="$log" "$cdo" "$dest"

echo -e "Process Complete"
read exit
