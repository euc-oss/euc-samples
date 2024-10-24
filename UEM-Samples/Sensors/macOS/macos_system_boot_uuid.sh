#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    boot_uuid=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Boot UUID" | awk '{print $3}')
else
    boot_uuid="N/A"
fi
echo "$boot_uuid"
# Description: What is the current macOS System Boot UUID
# Execution Context: SYSTEM
# Return Type: STRING