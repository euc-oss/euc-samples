#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    user_mdm_operations=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "User Approved Privileged MDM Operations" | awk '{print $6}')
else
    user_mdm_operations="N/A"
fi
echo "$user_mdm_operations"
# Description: Are System user approved Priviledged MDM enabled?
# Execution Context: SYSTEM
# Return Type: STRING