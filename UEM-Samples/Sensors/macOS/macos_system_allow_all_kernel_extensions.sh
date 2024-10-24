#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    allow_kext=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Allow All Kernel Extensions" | awk '{print $5}')
else
    allow_kext="N/A"
fi
echo "$allow_kext"
# Description: Show If Kernel extensions are allowed to be installed
# Execution Context: SYSTEM
# Return Type: STRING