#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    sip_status=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "System Integrity Protection" | awk '{print $4}')
else
    sip_status=$(/usr/sbin/system_profiler SPHardwareDataType | grep "System Integrity Protection" | awk '{print $4}')
fi
echo "$sip_status"
# Description: Is SIP enabled
# Execution Context: SYSTEM
# Return Type: STRING