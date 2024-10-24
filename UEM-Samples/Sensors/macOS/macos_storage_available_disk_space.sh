#!/bin/bash
available_space=$(df -H / | tail -1 | awk '{print $4}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
echo $available_space
# Description: Show How Much Drive space is available on the device
# Execution Context: SYSTEM
# Return Type: INTEGER