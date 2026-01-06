#!/bin/bash
set -euo pipefail

USERNAME="$1"
PASSWORD="${2:-$(openssl rand -base64 12)}"

if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists" >&2
  exit 1
fi

# Get the currently logged-in user
CURRENT_USER=$(stat -f%Su /dev/console)
 
# If the current user is not the global admin and is not already an admin, add them
if ! dseditgroup -o checkmember -m "$CURRENT_USER" admin | grep -q "yes"; then

  echo "Creating user '$USERNAME'..."
  
  # Create the new user
  sysadminctl -addUser "$USERNAME" -password "$PASSWORD" -admin

  # Ensure home directory exists
  sudo createhomedir -c -u "$USERNAME" >/dev/null

  echo "Created user: $USERNAME"
  echo "Password: $PASSWORD"
fi
echo "No action needed. Current user '$CURRENT_USER' is already an admin."

# Description: Create local admin account if the current user is not the global admin
# Execution Context: System
# Execution Architecture:
# Timeout: 30
# Variables: username, password