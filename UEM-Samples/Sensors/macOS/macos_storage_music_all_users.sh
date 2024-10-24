#!/bin/bash
for user_dir in /Users/*; do
  if [ -d "$user_dir/Music" ]; then
    user=$(basename "$user_dir")
    music_size=$(du -sh "$user_dir/Music" 2>/dev/null | awk '{print $1}' | sed 's/[a-zA-Z]//g' | awk '{print int($1)}')
    echo "$music_size"
  fi
done
# Description: Show How Much Drive space is being consumed by Music Directory on the device
# Execution Context: SYSTEM
# Return Type: INTEGER