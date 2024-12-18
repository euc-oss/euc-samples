# ClearPasscode.ps1

## Overview

•	Author: Leonardo Valente

•	Email: valentel@omnissa.com

•	Date Created: 12/13/2024

•	Date Updated: 12/17/2024

## Latest Updates

## Description
This script connects to your VMware Workspace ONE UEM environment API in order to clear your devices passcodes using the serial numbers to select the devices which passcodes are required to be cleared.
This script is useful when you have several devices that need their passcodes to be clear that are too many to be performed one by one in the Workspace One console UI.
The script uses a CSV file as input with the devices’ serial numbers.

## Requirements
1.	REST API Enabled at the OG you wish to target
2.	WS1 UEM Administrator account with device clear passcode permission.
3.	WS1 UEM REST API Key

## Instructions
Open a PowerShell instance and run the script .\ClearPasscode.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvFilePath 'CsvFilePath'

## PARAMETERS

**-apiURL
Mandatory parameter for the WS1 UEM API Server, for example ASXXXX.awmdm.com (omit https://).

**-username
Mandatory parameter, the Administrator account’s user name to be used by the script.

**-password
Mandatory parameter, the Administrator account’s password to be used by the script.

**-authToken
Mandatory parameter for the API key that is required for the script to connect via REST API to your server. These keys are per OG and are found under All Settings > System > Advanced > API > REST API.

**-CsvFilePath
Mandatory parameter. The path to the CSV file containing the devices’ serial numbers

## OUTPUTS

The script will output to the PS shell the line:
“Processing device serial number: 'device serial number'"
for every device
When the passcode clear command is sent successfully the script will output the PS shell the line:
“Passcode clearing command sent successfully for serial number: 'device serial number'”

When there is an error sending the command to the device in question the script will output to the PS shell the line:

“Error: 'the exception message returned by PS'”
for example:
“Error: The remote server returned an error: (400) Bad Request.”

## EXAMPLES

Usage: .\ClearPasscode.ps1 -apiUrl 'api-url' -username 'username' -password 'password' -authToken 'auth-token' -CsvFilePath 'CsvFilePath'

