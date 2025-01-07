#Use this script if necessary to update your devices' friendly name in bulk WS1 UEM. The script uses a CSV file to feed the Serial numbers of the devices whose friendly name need to be updated.
#In this specific scenario the devices friendly names are required to have the Asset Number values added to the original friendly name. 
#The following parameters are required for the script to work:
#1 - A WS1 UEM Adming credentials (username and password) with privileges to execute API commands
#2 - Your WS1 API URL, for exemple ASXXXX.awmdm.com, where XXXX is your tenant number
#3 - A REST API key that can be created / retrieved in the WS1 UEM console in All Settings / System / Advanced / API / REST API
#4 - A CSV formatted file with the serial number of the devices in question

# Check if the required arguments (API URL, username, password, and token) are provided
param (
   [string]$apiUrl,
   [string]$username,
   [string]$password,
   [string]$authToken,
   [string]$CsvInputFilePath,
   [string]$CsvOutputFilePath
)


# Validate if at least the API URL, authentication token, username/password and CSV file path are provided
if (-not $apiUrl -or (-not $authToken -and (-not $username -or -not $password) -or (-not $CsvInputFilePath) -or (-not $CsvOutputFilePath))) {
    Write-Host "Usage: .\UpdateDeviceFriendlyName.ps1 -apiUrl '<api-url>' -username '<username>' -password '<password>' -authToken '<auth-token>' -CsvInputFilePath '<CsvInputFilePath>' -CsvOutputFilePath '<CsvOutputFilePath>'"
    exit
}

$EncodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
            
# Define headers using the provided auth token
$Headers = @{
    "aw-tenant-code" = "$AuthToken"
    "Authorization" = "Basic $EncodedCredentials"
    "Accept"    = "application/json; version=2"
    }

# Verify the file exists
    if (-not (Test-Path $CsvInputFilePath)) {
        Write-Host "Error: File $CsvInputFilePath not found."
        $FileDoesNotExist = "Error: File $CsvInputFilePath not found."  
        $FileDoesNotExist| Out-File -Append -FilePath $CsvOutputFilePath 
        exit 1
    }
    # Import CSV
    $Devices = Import-Csv -Path $CsvInputFilePath
    # Loop through each device in the CSV
    foreach ($Device in $Devices) {
        $SerialNumber = $Device.serialNumber
        # Skip entries with missing data
        if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
            Write-Host "Skipping device with missing data: $SerialNumber"
            $SerialDoesNotExist = "Skipping device with missing data: $SerialNumber"  
            $SerialDoesNotExist| Out-File -Append -FilePath $CsvOutputFilePath 
            continue
        }
        Write-Host "Processing device serial number: $SerialNumber"
        #API Endpoint to retrieve devices (adjust based on the UEM API)
        $endpoint = "/API/mdm/devices?searchBy=SerialNumber&id=$SerialNumber"
        $fullApiUrl = "https://" + $apiUrl + $endpoint
        # Send Post Request to Workspace ONE UEM API using the authentication token
        try {
            $ResponseGet = Invoke-RestMethod -Uri $fullApiUrl -ContentType "application/json" -Method Get -Headers $Headers #Getting device ID of device
            $deviceID = $ResponseGet.id.value
            $fullApiUrlUpdate = "https://" + $apiUrl + "/API/mdm/devices/$deviceID" #Creating URI with device ID
            $DeviceFriendlyName = $ResponseGet.DeviceFriendlyName #Getting Current Friendly Device Name
            $DeviceAssetNumber = $ResponseGet.AssetNumber #Getting current Asset Number
            if ($DeviceFriendlyName.Contains($DeviceAssetNumber)) {
                Write-Host "The device friendly name $DeviceFriendlyName already contains the device asset number $DeviceAssetNumber."
                $AlreadyContainsAssetNumber = "The device friendly name $DeviceFriendlyName already contains the device asset number $DeviceAssetNumber."  
                $AlreadyContainsAssetNumber| Out-File -Append -FilePath $CsvOutputFilePath 
                continue
            }
            $NewFriendlyName = $DeviceFriendlyName + "-" + $DeviceAssetNumber #Creating new Friendly Device Name
            write-Host "Changing Friendly name of Device $DeviceFriendlyName device ID $deviceId Serial number $SerialNumber"
            $body = @{
                 
                 "DeviceFriendlyName" = $NewFriendlyName
                              
                     } | ConvertTo-Json

            $ResponsePost = Invoke-RestMethod -Uri $fullApiUrlUpdate -ContentType "application/json" -Method Put -Headers $headers -Body $body #Updating WS1 UEM device registration with new Friendly Device Name
            $ResponseGetNew = Invoke-RestMethod -Uri $fullApiUrlUpdate -ContentType "application/json" -Method Get -Headers $Headers # Confirming change was performed
            $DeviceFriendlyNameNew = $ResponseGetNew.DeviceFriendlyName
            write-Host "New Friendly name for Device ID $deviceId Serial number $SerialNumber is $DeviceFriendlyNameNew" #Printing results  
            $Result = "New Friendly name for Device ID $deviceId Serial number $SerialNumber is $DeviceFriendlyNameNew"  #Exporting results to CSV file
            $Result | Out-File -Append -FilePath $CsvOutputFilePath
            }
       catch {
                Write-Host "Error: $($_.Exception.Message)"
                $($_.Exception.Message) | Out-File -Append -FilePath $CsvOutputFilePath
             }
}