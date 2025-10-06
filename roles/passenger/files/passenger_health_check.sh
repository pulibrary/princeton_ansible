#!/usr/bin/env bash
#
# Check_MK local check to monitor Passenger request queue
# and fallback to Nginx stub_status Waiting count.
#
# Dependencies:
#   - passenger-status (in PATH)
#   - curl (only if using Nginx fallback)
#
# Sudoers:
#   If your agent does *not* run as root, allow:
#     deploy ALL=(root) NOPASSWD: /usr/bin/passenger-status
#
# Thresholds can be overridden via environment:
#   PASSENGER_QUEUE_WARN, PASSENGER_QUEUE_CRIT

# defaults
WARN=${PASSENGER_QUEUE_WARN:-5}
CRIT=${PASSENGER_QUEUE_CRIT:-10}

# try passenger-status
if queue=$(passenger-status 2>/dev/null \
      | awk '/Requests in queue/ {print $4}'); then
    # ensure numeric
    [[ $queue =~ ^[0-9]+$ ]] || queue=""
fi

# fallback to nginx stub_status
if [[ -z $queue ]]; then
    if nginx_status=$(curl -s http://127.0.0.1/nginx_status); then
        queue=$(awk '/Waiting/ {print $2}' <<<"$nginx_status")
        [[ $queue =~ ^[0-9]+$ ]] || queue=""
    fi
fi

# if still empty, report UNKNOWN
if [[ -z $queue ]]; then
    echo "2 passenger_queue - UNKNOWN: could not determine queue length"
    exit 3
fi

# determine state
state=0; state_txt="OK"
if (( queue >= CRIT )); then
    state=2; state_txt="CRITICAL"
elif (( queue >= WARN )); then
    state=1; state_txt="WARNING"
fi

# output: <state> <item> - <text>: <msg> | perfdata
echo "${state} passenger_queue - ${state_txt}: ${queue} requests in queue | requests=${queue};${WARN};${CRIT};0;"
exit 0

