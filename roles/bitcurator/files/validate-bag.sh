#!/bin/bash 

# validates bag using bagit.py (user specifies location of bag in prompt); saves log file (named current-date_log.txt) to location specified by user; and sends email with contents of log file to project manager (user specifies email)
# media to/from which you're transferring files will need to be mounted before running the script

# dependencies: bagit-python, sendmail        

clear

echo "Enter the full path to the bag you want to validate (do NOT include trailing slash)"
read bag

echo "Enter location for storing temporary local log file (do NOT include trailing slash)"
read temp

echo "Enter the email address that should receive the log file"
read email

now=$(date +"%m_%d_%Y")

logpath="$temp/"$now"_log.txt"

bagit.py --log "$logpath" --validate "$bag"

mailx -s "validation log: "$bag"" "$email" < "$logpath"

echo "Validation process completed. See log file for success/failure."

read -p "Press [Enter] key to continue."

