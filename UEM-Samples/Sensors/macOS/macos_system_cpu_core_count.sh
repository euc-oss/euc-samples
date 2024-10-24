#!/bin/bash
num_cores=$(sysctl -n hw.physicalcpu)  # Physical cores
num_logical_cores=$(sysctl -n hw.logicalcpu)  # Logical cores
echo "$num_cores Physical Cores, $num_logical_cores Logical Cores"
# Description: How many cores does the device have
# Execution Context: SYSTEM
# Return Type: STRING