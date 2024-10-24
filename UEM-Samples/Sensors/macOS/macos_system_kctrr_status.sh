#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    kernel_ctrr=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Kernel CTRR" | awk '{print $3}')
else
    kernel_ctrr="N/A"
fi
echo "$kernel_ctrr"
# Description: Is KCTRR Enabled
# Execution Context: SYSTEM
# Return Type: STRING