# UpdateDeviceFriendlyName.ps1

## Overview

•	Author: Leonardo Valente

•	Email: valentel@omnissa.com

•	Date Created: 12/20/2024

•	Date Updated: 12/20/2024

## Latest Updates

## Description
<!-- Summary Start -->	
This script connects to your VMware Workspace ONE UEM environment API and update your devices' friendly name in bulk WS1 UEM. The script uses a CSV file to feed the Serial numbers of the devices whose friendly name need to be updated. In this specific scenario the devices friendly names are required to have the Asset Number values added to the original friendly name. 
<!-- Summary End -->
The script uses a CSV file as input with the devices’ serial numbers which need the friendly name to be updated.

## Requirements
1.	REST API Enabled at the OG you wish to target
2.	WS1 UEM Administrator account with device clear passcode permission.
3.	WS1 UEM REST API Key

## Instructions
Open a PowerShell instance and run the script .\UpdateDeviceFriendlyName.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvInputFilePath 'CsvInputFilePath' -CsvOutputFilePath 'CsvOutputFilePath'

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
Mandatory parameter. The path to the CSV file containing the script's execution results
	

## OUTPUTS

The script will output to the PS shell the line:

“Processing device serial number: 'device serial number'” 

for every device

If the device already contains the asset number as part of the friendly name the script will output the PS shell the line:

"The device friendly name 'Friendly Name' already contains the device asset number 'Asset Number'."

If the device friendly name is changed to include the asset number script will output the PS shell the line:

"New Friendly name for Device ID 'device Id' Serial number 'Serial Number' is 'New Device Friendly Name'"

When there is an error sending the command to the device in question the script will output to the PS shell the line:

“Error: 'the exception message returned by PS'”

for example:

“Error: The remote server returned an error: (400) Bad Request.”

## EXAMPLES

Usage: .\UpdateDeviceFriendlyName.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvInputFilePath 'CsvInputFilePath' -CsvOutputFilePath 'CsvOutputFilePath'

