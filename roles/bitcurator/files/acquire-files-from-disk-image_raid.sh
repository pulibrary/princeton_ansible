#!/bin/bash
#acquiring digital archives

clear
echo -e "Where is the disk image mounted?"
read cdo

echo -e "What is the accession number?"
read acc

echo -e "What is the disk number?"
read disk

rsync -ah --progress --stats --exclude=".*" --exclude="~*" --log-file="/mnt/raid/$acc/$acc_$disk.log" "/media/$cdo/" "/mnt/raid/$acc/cdo/$disk/"
