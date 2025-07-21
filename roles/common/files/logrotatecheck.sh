#!/bin/bash
# This script check to see when the last time the logrotate status file was updated
#   If it was updated today the status is ok
#   If it was updated yesterday the status is warn
#   Otherwise the status is critical
#
message=$(find /var/lib/logrotate/status -mtime 0)
if [ "$message" = "/var/lib/logrotate/status" ]; then
  echo "0 \"Log Rotate\" - Logs were rotated today"
else
  yest_message=$(find /var/lib/logrotate/status -mtime 1)
  if [ "$yest_message" = "/var/lib/logrotate/status" ]; then
    echo "1 \"Log Rotate\" - No logs were rotated today, but they were yesterday"
  else
    echo "2 \"Log Rotate\" - No logs were rotated today or yesterday"
  fi
fi

