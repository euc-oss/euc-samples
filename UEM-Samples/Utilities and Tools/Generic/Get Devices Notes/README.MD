# GetDevicesConsoleNotes.ps1

## Overview

•	Author: Leonardo Valente

•	Email: valentel@omnissa.com

•	Date Created: 12/17/2024

•	Date Updated: 12/18/2024

## Latest Updates

## Description
	
This script connects to your VMware Workspace ONE UEM environment API and retrieve the devices notes. When this script was created the device Notes attribute was not included in console reports. This script is useful when an organization uses the Devices Notes tab in WS1 UEM to add specific information about the device lifecycle such as when it was serviced last, where it is located in a building etc... and wishes to export all of the devices notes in to a csv file for reporting and auditing.

The script uses a CSV file as input with the devices’ serial numbers in order to extract the devices notes.

## Requirements
1.	REST API Enabled at the OG you wish to target
2.	WS1 UEM Administrator account with device clear passcode permission.
3.	WS1 UEM REST API Key

## Instructions
Open a PowerShell instance and run the script .\GetDevicesConsoleNotes.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvInputFilePath 'CsvInputFilePath' -CsvOutputFilePath 'CsvOutputFilePath'

## PARAMETERS

### -apiURL
Mandatory parameter for the WS1 UEM API Server, for example ASXXXX.awmdm.com (omit https://).

### -username
Mandatory parameter, the Administrator account’s user name to be used by the script.

### -password
Mandatory parameter, the Administrator account’s password to be used by the script.

### -authToken
Mandatory parameter for the API key that is required for the script to connect via REST API to your server. These keys are per OG and are found under All Settings > System > Advanced > API > REST API.

### -$CsvInputFilePath
Mandatory parameter. The path to the CSV file containing the devices’ serial numbers

### -$CsvOutputFilePath
Mandatory parameter. The path to the CSV file containing the devices’ notes output


## OUTPUTS

The script will output to the PS shell the line:
“Processing device serial number: 'device serial number'” 
for every device

If the device has notes added to its record in the WS1 UEM console the script will output the PS shell the line:
“Retrieving notes from Device: 'device serial number'”

When there is an error sending the command to the device in question the script will output to the PS shell the line:

“Error: 'the exception message returned by PS'”
for example:
“Error: The remote server returned an error: (400) Bad Request.”

## EXAMPLES

Usage: .\GetDevicesConsoleNotes.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvInputFilePath 'CsvInputFilePath' -CsvOutputFilePath 'CsvOutputFilePath'

