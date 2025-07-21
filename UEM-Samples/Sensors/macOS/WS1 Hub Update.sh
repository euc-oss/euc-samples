#!/bin/bash
##################################
#
# Written by: Matt Zaske
# Copyright 2025 Omnissa
#
# Hub update repair
#
##################################

#ws1 variables
# username
# password
# apiKey
# apiURL

function version { echo "$@" | awk -F. '{ printf("%d%03d%05d%05d\n", $1,$2,$3,$4); }'; }
target_version="24.11.3"

#check if hub is installed
if [ -d "/Applications/Workspace ONE Intelligent Hub.app" ]; then
	#check version
	hubVersion="$(defaults read "/Applications/Workspace ONE Intelligent Hub.app/Contents/Info.plist" CFBundleShortVersionString)"
	if [ $(version $hubVersion) -lt $(version $target_version) ]; then
		#deploy fix/update
		serial=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')
		apiAuth=$(printf "%s" "$username:$password" | /usr/bin/base64)
		response=$(/usr/bin/curl "$apiURL/api/mdm/devices/commands?searchby=SerialNumber&id=$serial&command=InstallPackagedMacOSXAgent" \
		-X POST \
		-H "Authorization: Basic $apiAuth" \
		-H "aw-tenant-code: $apiKey" \
		-H "Accept: application/json;version=1" \
		-H "Content-Length: 0" \
		-H "Content-Type: application/json")
		echo "Hub install initiated"
	else
		#hub already on expected version
		echo "Hub version $hubVersion installed"
	fi
else
	#hub not installed
	echo "Hub is not installed"
fi


# Description: Detects if Hub is on desired version and sends command to install newer version if not.
# Execution Context: SYSTEM
# Execution Architecture: UNKNOWN
# Return Type: STRING
# Variables: username,administrator; password,ReplaceWithPassword; apiKey,ReplaceWithAPIKey; apiURL,https://as1234.awmdm.com
