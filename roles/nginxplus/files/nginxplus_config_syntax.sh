#!/usr/bin/env bash
#
# Check_MK Local Check: NGINX Plus configuration syntax test
# Places this script in /usr/lib/check_mk_agent/local/ and makes it executable.
#
# Requires: sudoers entry for "check_mk ALL=NOPASSWD: /usr/sbin/nginx -t"

# locate nginx binary
NGINX_CMD="$(command -v nginx)"
if [ -z "$NGINX_CMD" ]; then
    # 3 = UNKNOWN
    echo "3 nginxplus_config_syntax - UNKNOWN: nginx executable not found"
    exit 0
fi

# run syntax check quietly
OUTPUT="$(sudo "$NGINX_CMD" -t 2>&1)"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # 0 = OK
    echo "0 nginxplus_config_syntax - OK: NGINX Plus configuration syntax is valid"
else
    # 2 = CRITICAL
    # include the first line of error to keep the check line concise
    ERROR_LINE="$(echo "$OUTPUT" | head -n1)"
    echo "2 nginxplus_config_syntax - CRITICAL: syntax error: $ERROR_LINE"
fi
