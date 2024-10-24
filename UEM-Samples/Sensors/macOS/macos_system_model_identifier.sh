#!/bin/bash
architecture=$(uname -m)
if [[ "$architecture" == "arm64" ]]; then
    model_identifier=$(/usr/sbin/system_profiler SPiBridgeDataType | grep "Model Identifier" | awk '{print $3}')
else
    model_identifier=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | awk '{print $3}')
fi
echo "$model_identifier"
# Description: Apple Model Identifer
# Execution Context: SYSTEM
# Return Type: STRING