#!/bin/bash
#NEW_PASSWORD="0mn1ss@2024"

# Step 1: Extract the username from user-level profiles

USERNAME=$(profiles list -all | \

grep "attribute: profileIdentifier" -B 1 | \

grep -v "_computerlevel" | \

grep -Eo '^[^[]+' | \

sort | \

uniq | head -n 1)

# Check if a username was found

if [ -z "$USERNAME" ]; then

    echo "No user-level profile found. Exiting."

    #exit 1

fi

#echo "Found user: $USERNAME"



# Step 2: Change the password

dscl . -passwd /Users/"$USERNAME" "$NEW_PASSWORD"

# Step 4: Confirm success

if [ $? -eq 0 ]; then

    echo "Password for user '$USERNAME' changed successfully."

else

    echo "Failed to change password for user '$USERNAME'."

fi

# Description: Script to change the password of the local enrolled user on macOS
# Execution Context: System
# Execution Architecture:
# Timeout: 30
# Variables: NEW_PASSWORD (String)