#!/bin/bash
#scanning for flag words

clear

echo -e "Enter the full path to the folder you would like to scan."
read cdo

echo -e "Enter the full path to the text file that will contain your scan's results."
read results

cd "$cdo"
find . \( -name "*ecommend*" -o -name "*earch*" -o -name "*iscipli*" -o -name "*ersonne*" -o -name "*ersona*" -o -name "*ransc*" \) -print >"$results"

