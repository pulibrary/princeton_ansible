#!/bin/bash

#purpose: finds and copies intermediate files ONLY (as long as the file name ends in "_i" and has a .mov extension) from source (vendor) drive and puts them in a newly created folder called "deliverables" within destination folder
#note: you may see permissions errors in the terminal, but ignore because they are for the system files on the vendor drive itself
#repurpose: easy to edit file extensions you want to find
#citation: commands largely stolen from https://dd388.github.io/crals/#find_rsync (though any errors introduced are courtesy of KB)

clear

echo "Enter the full path to the mounted source drive (do NOT include trailing slash)"
read sourcedrive

echo "Enter the full path to the destination where you want to copy files (do NOT include trailing slash)"
read destination

find "$sourcedrive" \( -iname "*_i.mov" \) -exec rsync {} "$destination"/deliverables/ \;
