#!/bin/bash
most_frequent_user=$(last | awk '{print $1}' | grep -v "wtmp" | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}')
echo "$most_frequent_user"
# Description: Parse the Login History and Find the most frequent user of the device
# Execution Context: SYSTEM
# Return Type: STRING