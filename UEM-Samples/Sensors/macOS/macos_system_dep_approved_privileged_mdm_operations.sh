#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    dep_mdm_operations=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "DEP Approved Privileged MDM Operations" | awk '{print $6}')
else
    dep_mdm_operations="N/A"
fi
echo "$dep_mdm_operations"
# Description: Is DEP Approved priveledged MDM Operation Enabled
# Execution Context: SYSTEM
# Return Type: STRING