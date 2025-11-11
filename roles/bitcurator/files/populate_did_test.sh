#!/bin/bash
OIFS="$IFS"
IFS=$'\n'
directories=$(find $1 -maxdepth 1 -type d)
for directory in $directories
do
		#1) name of directory
		echo -n "\"$directory\", "

		#2) mtime of oldest file
		echo -n \"`find $directory -type f -printf '%T+ %TY-%TB-%Td %p\n' | sort -n | head -1 | awk -F ' ' '{print $2}'`"\", "

		#3) mtime of newest file
		echo -n \"`find $directory -type f -printf '%T+ %TY-%TB-%Td %p\n' | sort -n | tail -1 | awk -F ' ' '{print $2}'`"\", "
		
		#4) number of files
		echo -n  \"`find  $directory -type f -printf  '\n' | wc -l` digital files\"
	
		echo
		
		#4a) number of hidden directories
		#find -iname ".*" -type d -printf '\n' | wc -l
		#5a) number of hidden files
		#find -iname ".*" -type f -printf '\n' | wc -l

done
IFS="$OIFS"
