#!/bin/bash          


clear
echo "Would you like to mount the archive storage [y/n]?"
read ans


if [ $ans = y -o $ans = Y -o $ans = yes -o $ans = Yes -o $ans = YES ]
then
echo "Mounting /mnt/archives_bd"
sudo /bin/mount /mnt/archives_bd
fi


if [ $ans = n -o $ans = N -o $ans = no -o $ans = No -o $ans = NO ]
then
echo "Okay, will exit now."
fi

echo "Program Completed."
