#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    ssv_status=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Signed System Volume" | awk '{print $4}')
else
    # Intel (Not available in SPHardwareDataType)
    ssv_status="N/A"
fi
echo "$ssv_status"
# Description: Is SSV Enabled
# Execution Context: SYSTEM
# Return Type: STRING