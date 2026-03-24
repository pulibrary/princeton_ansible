#!/bin/bash
#acquiring digital archives

clear
echo -e "Where is the disk image mounted?"
read cdo

echo -e "What is the accession number?"
read acc

echo -e "What is the disk number?"
read disk

rsync -ah --progress --stats --exclude=".*" --exclude="~*" --log-file="/home/bcadmin/Desktop/$acc_$disk.log" "/media/$cdo/" "/home/bcadmin/Desktop/$acc/cdo/$disk/"
