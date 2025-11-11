#!/bin/bash 

# generalizable rsync script. rsync files from one location to another (user specifies locations in prompt)
# media to/from which you're transferring files will need to be mounted before running the script.        

clear

echo "Enter the full path to the bag/files you want to copy (INCLUDE trailing slash)"
read bag

echo "Enter the full path to the destination folder where you want the files to be copied (INCLUDE trailing slash)"
read destination


/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage.log "$bag" "$destination"


echo "Sync Completed."

read -p "Press [Enter] key to continue."

