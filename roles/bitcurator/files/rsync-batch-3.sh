#!/bin/bash 

# rsync bags 2-6 from goldstein batch 3 to isilon, then validate them    

/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage_bag2.log /media/sdd2/Video_Deliverables/C1449_2018_06_bag_02 /mnt/archives_bd/bcadmin/mss/av_backlog/C1449

/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage_bag3.log /media/sdd2/Video_Deliverables/C1449_2018_06_bag_03 /mnt/archives_bd/bcadmin/mss/av_backlog/C1449

/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage_bag4.log /media/sdd2/Video_Deliverables/C1449_2018_06_bag_04 /mnt/archives_bd/bcadmin/mss/av_backlog/C1449

/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage_bag5.log /media/sdd2/Video_Deliverables/C1449_2018_06_bag_05 /mnt/archives_bd/bcadmin/mss/av_backlog/C1449

/usr/bin/rsync -ah --progress --stats --log-file=/home/bcadmin/Desktop/storage_bag6.log /media/sdd2/Video_Deliverables/C1449_2018_06_bag_06 /mnt/archives_bd/bcadmin/mss/av_backlog/C1449

bagit.py --log /home/bcadmin/Desktop/validate_bag2.txt --validate /mnt/archives_bd/bcadmin/mss/av_backlog/C1449/C1449_2018_06_bag_02

bagit.py --log /home/bcadmin/Desktop/validate_bag3.txt --validate /mnt/archives_bd/bcadmin/mss/av_backlog/C1449/C1449_2018_06_bag_03

bagit.py --log /home/bcadmin/Desktop/validate_bag4.txt --validate /mnt/archives_bd/bcadmin/mss/av_backlog/C1449/C1449_2018_06_bag_04

bagit.py --log /home/bcadmin/Desktop/validate_bag5.txt --validate /mnt/archives_bd/bcadmin/mss/av_backlog/C1449/C1449_2018_06_bag_05

bagit.py --log /home/bcadmin/Desktop/validate_bag6.txt --validate /mnt/archives_bd/bcadmin/mss/av_backlog/C1449/C1449_2018_06_bag_06

echo "Sync and Validation Completed."

read -p "Press [Enter] key to continue."

