#!/bin/sh

# WorkspaceOne Intelligence Backend Domain Change Utility
# 	This script helps to modify a configuration setting for the DEEM Agent
#	software on macOS. It targets the configuration file located at:
#	'/Library/Application Support/WorkspaceONE/Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json'
#	The script will change the configuration, to make the DEEM Agent use the new
#	Omnissa branded WorkspaceOne Intelligence backend service. After updating
#	the specified setting, the script will gracefully relaunch the DEEM Agent to
#	apply the change.
#
# --purge-events option:
# 	An optional command-line flag --purge-events is provided. This is intended
# 	to address a specific scenario related to backend service change:
# 	- After June 2025, DEEM Agent will no longer be able to stream telemetry
#	  events to legacy VMware WorkspaceOne Intelligence backend service.
# 	- If the DEEM Agent has continued running past this date without applying
#	  the updated configuration, telemetry events may have accumulated locally
#	  on endpoint devices.
# 	- Applying this script (without the purge option) will re-enable DEEM Agent
#	  to connect to the new Omnissa WorkspaceOne backend. However, any
#	  previously accumulated events will begin streaming at once, potentially
#	  overwhelming customer's business network.
# 	- To avoid this, use the --purge-events option. It will delete the backlog
#	  of locally stored telemetry events from the database located at:
# 	  '/Library/Application Support/WorkspaceONE/Deem/deem-data/sqlite/logs.db'
# 	- After purging, DEEM Agent will begin streaming only new telemetry events
#	  to the Omnissa backend.
#
# Usage:
# 	'sudo ./deem-config.sh [--purge-events]'
# 	- Run without arguments to update the configuration and restart the DEEM
#	  Agent.
#	- Use --purge-events to prevent a backlog of telemetry events from flooding
#	  the network after switching to Omnissa services.
#
# Note:
#	This script must be run with root privileges (sudo) to access and
# 	modify system files and services.


echo "Looking for existing DEEM appsettings.json..."

deemSettings=""
daemonPlist=""
logdb=""

if [ -f "/Library/Application Support/VMware/VMware.Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json" ]; then

	echo "Found legacy DEEM appsettings.json..."

	deemSettings="/Library/Application Support/VMware/VMware.Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json"
	daemonPlist="/Library/LaunchDaemons/com.vmware.deemd.plist"
	logdb="/Library/Application Support/VMware/VMware.Deem/VMWOSQEXT-dotnetcore/sqlite/logs.db"

elif [ -f "/Library/Application Support/VMware/VMware.Deem/deem/appsettings.json" ]; then

	echo "Found older DEEM appsettings.json..."

	deemSettings="/Library/Application Support/VMware/VMware.Deem/deem/appsettings.json"
	daemonPlist="/Library/LaunchDaemons/com.vmware.deemd.plist"
	logdb="/Library/Application Support/VMware/VMware.Deem/VMWOSQEXT-dotnetcore/sqlite/logs.db"

elif [ -f "/Library/Application Support/WorkspaceONE/Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json" ]; then

	echo "Found DEEM appsettings.json..."

	deemSettings="/Library/Application Support/WorkspaceONE/Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json"
	daemonPlist="/Library/LaunchDaemons/com.ws1.deemd.plist"
	logdb="/Library/Application Support/WorkspaceONE/Deem/deem-data/sqlite/logs.db"

else
	echo "Did not find any DEEM appsettings.json, is DEEM installed?"
	exit 0
fi

echo "DEEM settings: $deemSettings"
echo "DEEM daemon plist: $daemonPlist"
echo "Event db: $logdb"

echo "Checking for old domain settings..."

foundOldDomain=$(grep '"DeploymentEndpoint": "api.na1.region.data.vmwservices.com"' "$deemSettings")

if [ -z "$foundOldDomain" -o $? -ne 0 ]; then
	echo "Existing domain api.na1.region.data.vmwservices.com was not found in DEEM settings, no changes will be made."
	exit 0
fi

echo "Updating settings..."
sudo sed -ie 's/api.na1.region.data.vmwservices.com/api.na1.region.data.workspaceone.com/g' "$deemSettings"

if [[ "$1" == "--purge-events" ]]; then

	echo "Looking for event log file $logdb..."

	if [ -n "$logdb" -a -f "$logdb" ]; then
		echo "Removing cached events..."
		sudo sqlite3 "$logdb" "DELETE FROM logs"
	fi

fi

echo "Stopping daemon..."
sudo launchctl unload $daemonPlist

sleep 5

echo "Starting daemon..."
sudo launchctl load $daemonPlist

echo "Done."

exit 0

