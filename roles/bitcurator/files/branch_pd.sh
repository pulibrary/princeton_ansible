#!/bin/bash
OIFS="$IFS"
IFS=$'\n'
directories=$(find $1 -maxdepth 1 -type d)
for directory in $directories
do
		#1) name of directory
		echo -n "\"$directory\", "
		

		#2) mtime of oldest file - mtime of newest file
		echo -n \"`find $directory -type f -printf '%T+ %TY-%TB-%Td %y%p\n'  | sort -n | head -1 | awk -F ' ' '{print $2}'` - `find $directory -type f -printf '%T+ %TY-%TB-%Td %p\n' | sort -n | tail -1 | awk -F ' ' '{print $2}'`\", ""
		


		#4) number of directories and files
		echo -n  \"Digital Folders':' `find  $directory -type d -printf '\n'| wc -l`, Digital Files':' `find  $directory -type f -printf  '\n' | wc -l`\"
	

		echo 
		


		#4a) number of hidden directories
		#find -iname ".*" -type d -printf '\n' | wc -l
		#5a) number of hidden files
		#find -iname ".*" -type f -printf '\n' | wc -l

done
IFS="$OIFS"
