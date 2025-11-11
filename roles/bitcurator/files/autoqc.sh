#!/bin/bash

#This script bulk renames files by appending the appropriate file extension based on a file path and extension from a csv input file.

#Input csv file ($input) should contain the full file path in column 1 ($f1) and extension to be appended in column 2 ($f2). This input file can be created from DROID ext-mismatch report.

#To call script, enter the following into the terminal: bash ./add-extensions.sh

clear

echo "Enter the full path of your input file."
read input

echo "Enter the full path to the location where you want to store the log file."
read log

while IFS=, read f1 f2
do
	mv -v "$f1" "$f1".$f2
done < "$input" > "$log"/log.txt

#Ignore everything above this line (just here for context from old script)

clear

echo "Enter the full path to the hard drive containing digitized files (be sure that the drive is mounted)." # test and specify whether to include trailing slash
read drive

now=$(date +"%m_%d_%Y")

#step 1: virus scan

clamscan -a "$drive" &> /home/bcadmin/Desktop/autoqc_report_"$now".txt # &> redirects both stderr and stdout

report=$(/home/bcadmin/Desktop/autoqc_report_"$now".txt) # not sure if this variable creation syntax is right

#step 2: validate bags

bagit.py --validate path/to/bag &>> $report #maybe use grabbags instead?

grabbags --validate path/to/bags &>> $report

#step 3: completeness check

#step 4: format verification




