#!/bin/bash

macAddress=$(/usr/sbin/networksetup -getmacaddress "Wi-Fi" | awk '{print $3}')
echo "$macAddress"
exit 0

# Description: Gets the physcial MAC address from the Wi-Fi hardware module.
# Execution Context: SYSTEM
# Execution Architecture: UNKNOWN
# Return Type: STRING
