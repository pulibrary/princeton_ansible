#!/bin/bash

DRP_FILES_PATH=`/usr/local/bin/drush dd @prod:%files/feeds/`
curl https://lib-jobs.princeton.edu/staff-directory.csv  > $DRP_FILES_PATH/LibraryDirectoryPrimary.csv

REMOVED=$(curl https://lib-jobs.princeton.edu/removed-staff)
IFS=',' read -ra VALUES <<< "$REMOVED"
for id in "${VALUES[@]}"; do
  echo user to disable: $id
  # drush -r /var/www/library_cap/current ublk --name=$id
done
