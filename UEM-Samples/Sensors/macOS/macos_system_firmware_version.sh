#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    firmware_version=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Firmware Version" | awk '{print $3}')
else
    firmware_version=$(/usr/sbin/system_profiler SPHardwareDataType | grep "System Firmware Version" | awk '{print $4}')
fi
echo "$firmware_version"
# Description: What is the current System Firmeware Version
# Execution Context: SYSTEM
# Return Type: STRING