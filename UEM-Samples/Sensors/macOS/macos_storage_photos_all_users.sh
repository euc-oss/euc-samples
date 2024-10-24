#!/bin/bash
for user_dir in /Users/*; do
  if [ -d "$user_dir/Pictures" ]; then
    user=$(basename "$user_dir")
    photos_size=$(du -sh "$user_dir/Pictures" 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
    echo "$photos_size"
  fi
done
# Description: Show How Much Drive space is being consumed by Photos Directory on the device
# Execution Context: SYSTEM
# Return Type: INTEGER