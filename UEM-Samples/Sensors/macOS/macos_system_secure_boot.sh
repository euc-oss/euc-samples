#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    secure_boot=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Secure Boot" | awk '{print $3, $4}')
else
    secure_boot="N/A"
fi
echo "$secure_boot"
# Description: Display current Secure Boot Securit Policy
# Execution Context: SYSTEM
# Return Type: STRING