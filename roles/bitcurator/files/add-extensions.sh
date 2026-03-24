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
