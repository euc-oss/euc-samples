#!/bin/bash
applications_size=$(du -sh /Applications 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
echo $applications_size
# Description: Show How Much Drive space is being consumed by Applications Installed on the device
# Execution Context: SYSTEM
# Return Type: INTEGER