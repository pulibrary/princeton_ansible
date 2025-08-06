#!/bin/bash
# This script check to see if the health-moitor-rails (https://github.com/lbeder/health-monitor-rails) page is all ok
#   If all the items monitored are ok the status is ok
#   If any items are not ok the status is critical
#
# required vars:
#  check_mk_health_url - the url to curl for the health page ( for example localhost/health)
#
message=$(sudo -u deploy curl localhost/health.json |grep \"status\":\"ok\" | wc -l)
if [ $message =  1 ]; then   
   echo "0 \"Rails Health Status\" - Rails is healthy"; 
else
   echo "2 \"Rails Health Status\" - Check the Rails health page {{ check_mk_health_url }} for details";
fi
