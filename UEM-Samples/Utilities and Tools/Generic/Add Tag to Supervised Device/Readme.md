# Add Tag to Supervised Device

Author: Rober Terakedis, Omnissa
Last Edit: May 13, 2016
Version: 1.0

## Overview
<!-- Summary Start -->
This Poweshell script make a REST API call to an AirWatch server.  This particular script is used to build an Assignment Group for all supervised devices.  There is currently no filter in the console
<!-- Summary End -->

To understand the underlying call check:

- https://<your_AirWatch_Server>/api/mdm/devices/search - this script uses the platform filter to select just iOS devices
- https://<your_AirWatch_Server>/api/mdm/tags/search - checks for a Supervised tag, and if not found creates one.
- It is always helpful to validate your parameter using something like the PostMan extension for Chrome
- https://chrome.google.com/webstore/detail/postman/fhbjgbiflinjbdggehcddcbncdddomop?hl=en

## EXAMPLE

Execute-AWRestAPI.ps1 -userName Administrator -password password -tenantAPIKey 4+apikeyw/krandomSstuffIleq4MY6A7WPmo9K9AbM6A= -outputFile c:\Users\Administrator\Desktop\output.txt -endpointURL https://demo.awmdm.com/API/v1/mdm/devices/serialnumber  -inputFile C:\Users\Administrator\Desktop\SerialNumbers1.txt -Verbose

## Parameters

**userName**
An AirWatch account in the tenant is being queried.  This user must have the API role at a minimum.

**password**
The password that is used by the user specified in the username parameter

**tenantAPIKey**
This is the REST API key that is generated in the AirWatch Console.  You locate this key at All Settings -> Advanced -> API -> REST,
and you will find the key in the API Key field.  If it is not there you may need override the settings and Enable API Access

**airwatchServer**
This will be the https://<your_AirWatch_Server>.  All of the REST endpoints start with a forward slash (/) so do not include that with the server name

**organizationGroupName**
This will be the organization group name in the AirWatch console.
