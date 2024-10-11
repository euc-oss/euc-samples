#!/bin/bash

# Get the current logged-in username
username=$(stat -f "%Su" /dev/console)

# Check the secure token status for the user and capture the output
output=$(sysadminctl -secureTokenStatus "$username" 2>&1)

# Extract the status (ENABLED or DISABLED) from the output
status=$(echo "$output" | grep -oE 'ENABLED|DISABLED')

# Optionally, log the status to a file for later review
# echo "$status" >> /path/to/logfile.log

# Suppress output to ensure the script runs silently
echo "$status"
# Description: Secure Token Status
# Execution Context: SYSTEM
# Return Type: STRING