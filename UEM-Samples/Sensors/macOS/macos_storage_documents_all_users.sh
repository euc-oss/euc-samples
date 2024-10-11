#!/bin/bash
for user_dir in /Users/*; do
  if [ -d "$user_dir/Documents" ]; then
    user=$(basename "$user_dir")
    documents_size=$(du -sh "$user_dir/Documents" 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
    echo "$documents_size"
  fi
done
# Description: Show How Much Drive space is being consumed by the Documents folder on the device
# Execution Context: SYSTEM
# Return Type: INTEGER