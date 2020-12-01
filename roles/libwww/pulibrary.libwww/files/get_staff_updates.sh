#!/bin/sh

DRP_FILES_PATH=`/usr/local/bin/drush dd @prod:%files/feeds/`
curl http://libweb5.princeton.edu/NewStaff/LibraryDirectoryPrimary.csv  > $DRP_FILES_PATH/LibraryDirectoryPrimary.csv
