#!/bin/bash
rsr=$(sw_vers -ProductVersionExtra)
if [[ "$rsr" == "Usage"* ]] || [[ "$rsr" == "" ]]; then
	echo "No RSR Applied"
else
	echo "$rsr"
fi
# Description: Current Apple RSR Version
# Execution Context: SYSTEM
# Return Type: INTEGER