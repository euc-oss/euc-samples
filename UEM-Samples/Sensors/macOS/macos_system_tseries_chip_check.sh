#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    # Apple Silicon: All have T2 functionality
    t2_status="YES"
else
    # Intel: Check for T2 chip using SPiBridgeDataType
    t2_check=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Model Identifier")   
    if [[ -n "$t2_check" ]]; then
        # If there's output, the Intel device has a T2 chip
        t2_status="YES"
    else
        # If there's no output, the Intel device does not have a T2 chip
        t2_status="Not Present"
    fi
fi
echo "$t2_status"
# Description: Does the device have an Apple T2 Chip?
# Execution Context: SYSTEM
# Return Type: STRING