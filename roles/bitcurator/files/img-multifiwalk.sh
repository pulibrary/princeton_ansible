#!/bin/bash

# Very basic shell script to run fiwalk over every file in a directory,
# ignoring any subdirectories.

unset a i
while IFS= read -r -u3 -d $'\0' file; do
    fiwalk -f -X "$file".xml $file
done 3< <(find $@ -name "*.img" -type f -print0)

