rsync -ah --progress --stats --exclude=".*" --exclude="~*" --log-file="/mnt/raid/$acc_$disk.log" "/media/$cdo/" "/mnt/raid/$acc/cdo/$disk/"
