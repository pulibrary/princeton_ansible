#!/bin/bash          

clear
echo -e "Where is the disk image mounted?"
read cdo

echo $cdo


/bin/mkdir /home/bcadmin/Desktop/test.dir

/usr/bin/touch /home/bcadmin/Desktop/test.dir/test.file

echo "Program Completed."
