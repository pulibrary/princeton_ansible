#!/bin/bash
# This script check to see if the Redis is healthy, by checking on the get stats
#
# required vars:
#
message=$(redis-cli --raw info commandstats |grep cmdstat_get |grep failed_calls=0 |wc -l)
if [ $message =  1 ]; then   
   echo "0 \"Redis Health Status\" - Redis is healthy"; 
else
   echo "2 \"Redis Health Status\" - Users are having issues getting keys from Redis";
fi