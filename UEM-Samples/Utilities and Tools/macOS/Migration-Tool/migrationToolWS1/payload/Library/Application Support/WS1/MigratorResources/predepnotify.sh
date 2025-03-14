#!/bin/bash
### Use this script to customize DEPNotify UI ###
### This script runs when the migration script starts, but before opening DEPNotify ###

DEPNOTIFYLOG="/private/var/tmp/depnotify.log"
DEPNOTIFYIMAGE="/Library/Application Support/WS1/MigratorResources/my_org_logo.png"

echo "Command: MainTextImage: $DEPNOTIFYIMAGE" >> $DEPNOTIFYLOG
echo "Command: Image: $DEPNOTIFYIMAGE" >> $DEPNOTIFYLOG
echo "Command: MainTitle: Workspace ONE macOS Migration" >> $DEPNOTIFYLOG
echo "Command: MainText: Your device is now being migrated." >> $DEPNOTIFYLOG

exit 0
