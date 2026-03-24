#!/bin/bash

#purpose: copying metadata (.txt, .csv, and .xml) and access (.mp3 and .mp4) files ONLY from vendor drives containing digitized audiovisual materials to desired folder
#note: you may see permissions errors in the terminal, but ignore because they are for the system files on the vendor drive itself
#repurpose: easy to edit file extensions you want to find
#citation: commands largely stolen from https://dd388.github.io/crals/#find_rsync (though any errors introduced are courtesy of KB)

clear

echo "Enter the full path to the mounted source drive or existing copy (do NOT include trailing slash)"
read sourcedrive

echo "Enter the full path to the destination where you want to copy files (do NOT include trailing slash)"
read destination

#finds and copies metadata files (.txt, .csv, and .xml) from source drive and puts them in a newly created folder called "metadata" within destination folder

find "$sourcedrive" \( -iname "*.xml" -o -iname "*.txt" -o -iname "*.csv" \) -exec rsync {} "$destination"/metadata/ \;

#finds and copies access files (.mp4 and .mp3) and puts them in a newly created folder called "access" within the destination folder

find "$sourcedrive" \( -iname "*.mp4" -o -iname "*.mp3" \) -exec rsync {} "$destination"/access/ \;

