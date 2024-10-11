#!/bin/bash

# Retrieve disk size and unit
disk_info=$(diskutil info / | grep "Disk Size:")

# Extract size and unit from the formatted output
disk_size=$(echo "$disk_info" | awk -F'[: ]+' '{print $4}')
unit=$(echo "$disk_info" | awk -F'[: ]+' '{print $5}')

# Function to round up to the nearest integer
round_up() {
  # Input: $1 = size
  # Output: rounded size
  local size=$1
  echo "$size" | awk '{print int($1 + 0.999999)}'
}

# Convert size based on the unit
if [[ "$unit" == "GB" ]]; then
  if (( $(echo "$disk_size >= 1000" | bc -l) )); then
    tb_size=$(echo "$disk_size / 1000" | bc -l)
    tb_size=$(round_up "$tb_size")
    echo "$tb_size"
  else
    rounded_size=$(round_up "$disk_size")
    echo "$rounded_size"
  fi
else
  rounded_size=$(round_up "$disk_size")
  echo "$rounded_size"
fi
# Description: What is the size of the hard drive installed?
# Execution Context: SYSTEM
# Return Type: INTEGER