#!/bin/bash
#create processing and destination directories

clear

echo -e "What is the digital object's repository?"
read repo

echo -e "What is the digital object's call number?"
read cn

echo -e "What is the digital object's accession number?"
read an

mkdir -pv /home/bcadmin/Desktop/bcadmin/"$repo"/"$cn"/"$an" -pv /home/bcadmin/Desktop/"$an"/{cdo,images,ri,submission}

#then
#mkdir /home/bcadmin/Desktop/"$an"/ri
#then
#mkdir /home/bcadmin/Desktop/"$an"/submission

echo "Directories created."
