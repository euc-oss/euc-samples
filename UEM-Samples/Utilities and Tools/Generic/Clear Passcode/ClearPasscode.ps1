#Use this script if necessary to clear devices' passcodes in bulk. The script uses a CSV file to feed the Serial numbers of the devices whose passwords require to be clered.
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
   [string]$CsvFilePath
)


# Validate if at least the API URL, authentication token, username/password snf CSV file path are provided
if (-not $apiUrl -or (-not $authToken -and (-not $username -or -not $password) -or (-not $CsvFilePath))) {
    Write-Host "Usage: .\ScriptName.ps1 -apiUrl '<api-url>' -username '<username>' -password '<password>' -authToken '<auth-token>' -CsvFilePath '<CsvFilePath>'"
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
    if (-not (Test-Path $CsvFilePath)) {
        Write-Host "Error: File $CsvFilePath not found." 
        exit 1
    }
    # Import CSV
    $Devices = Import-Csv -Path $CsvFilePath
    # Loop through each device in the CSV
    foreach ($Device in $Devices) {
        $SerialNumber = $Device.serialNumber
        # Skip entries with missing data
        if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
            Write-Host "Skipping device with missing data: $SerialNumber" 
            continue
        }
        Write-Host "Processing device serial number: $SerialNumber"
        #API Endpoint to retrieve devices (adjust based on the UEM API)
        $endpoint = "/API/mdm/devices/commands/ClearPasscode/device/SerialNumber/$SerialNumber"
        $fullApiUrl = "https://" + $apiUrl + $endpoint

        # Send Post Request to Workspace ONE UEM API using the authentication token
        try {
            $Response = Invoke-RestMethod -Uri $fullApiUrl -ContentType "application/json" -Method Post -Headers $Headers #invoking commmand to clear device passcode
            # Output the response
            Write-Host "Passcode clearing command sent successfully for serial number: $SerialNumber."
            }
       catch {
                Write-Host "Error: $($_.Exception.Message)"
             }
}