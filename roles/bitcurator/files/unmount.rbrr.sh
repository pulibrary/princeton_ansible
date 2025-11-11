#!/bin/bash          


clear
echo "Would you like to unmount the RBRR storage [y/n]?"
read ans


if [ $ans = y -o $ans = Y -o $ans = yes -o $ans = Yes -o $ans = YES ]
then
echo "Unmounting /mnt/rbrr"
sudo /bin/umount /mnt/rbrr
fi


if [ $ans = n -o $ans = N -o $ans = no -o $ans = No -o $ans = NO ]
then
echo "Okay, will exit now."
fi

echo "Program Completed."
