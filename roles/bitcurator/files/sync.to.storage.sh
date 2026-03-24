#!/bin/bash          


clear
echo "Would you like to sync data folder to the archive storage [y/n]?"
read ans


if [ $ans = y -o $ans = Y -o $ans = yes -o $ans = Yes -o $ans = YES ]
then
echo "Mounting and Syncing to Storage"
# /bin/mount /media/archives_bd
/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage.log /home/bcadmin/Desktop/bcadmin /media/archives_bd
fi


if [ $ans = n -o $ans = N -o $ans = no -o $ans = No -o $ans = NO ]
then
echo "Okay, will exit now."
fi


echo "Sync Completed."

read -p "Press [Enter] key to continue."

