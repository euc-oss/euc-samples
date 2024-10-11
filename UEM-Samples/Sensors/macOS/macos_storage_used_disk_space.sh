#!/bin/bash
used_space=$(df -H / | tail -1 | awk '{print $3}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
echo $used_space
# Description: Show How Much Drive space is being used on the device
# Execution Context: SYSTEM
# Return Type: INTEGER