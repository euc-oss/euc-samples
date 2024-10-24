#!/bin/bash
chip_info=$(sysctl -n machdep.cpu.brand_string)
echo "$chip_info"
# Description: What CPU is installed on the device
# Execution Context: SYSTEM
# Return Type: STRING