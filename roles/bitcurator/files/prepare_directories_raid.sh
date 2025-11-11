#!/bin/bash
#create processing and destination directories

clear

echo -e "What is the digital object's repository?"
read repo

echo -e "What is the digital object's call number?"
read cn

echo -e "What is the digital object's accession number?"
read an

mkdir -pv /mnt/raid/bcadmin/"$repo"/"$cn"/"$an"/{cdo,images,ri,submission}

#then
#mkdir /media/raid/"$an"/ri
#then
#mkdir /media/raid/"$an$/submission

echo "Directories created."
