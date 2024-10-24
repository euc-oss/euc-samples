#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    # Apple Silicon: Model Name is not part of SPiBridgeDataType, so use SPHardwareDataType
    model_name=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Name" | awk '{print $3, $4, $5}')
else
    # Intel: Model Name from SPHardwareDataType
    model_name=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Name" | awk '{print $3, $4, $5}')
fi
echo "$model_name"
# Description: Apple System Model Name
# Execution Context: SYSTEM
# Return Type: STRING