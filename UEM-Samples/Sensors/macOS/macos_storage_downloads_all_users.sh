#!/bin/bash
for user_dir in /Users/*; do
  if [ -d "$user_dir/Downloads" ]; then
    user=$(basename "$user_dir")
    downloads_size=$(du -sh "$user_dir/Downloads" 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
    echo "$downloads_size"
  fi
done
# Description: Show How Much Drive space is being consumed by Downloads Directory on the device
# Execution Context: SYSTEM
# Return Type: INTEGER