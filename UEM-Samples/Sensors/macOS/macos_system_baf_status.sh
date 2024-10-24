#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    boot_args_filter=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Boot Arguments Filtering" | awk '{print $4}')
else
    boot_args_filter="N/A"
fi
echo "$boot_args_filter"
# Description: Whatis the current boot arguments filter
# Execution Context: SYSTEM
# Return Type: STRING