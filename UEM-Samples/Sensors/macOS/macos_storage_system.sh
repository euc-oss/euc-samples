#!/bin/bash
system_size=$(du -sh /System 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
echo $system_size
# Description: Show How Much Drive space is being consumed by the Systems Folder on the device
# Execution Context: SYSTEM
# Return Type: INTEGER