#Use this script if necessary to retrieve device notes added in WS1 UEM console. The script uses a CSV file to feed the Serial numbers of the devices whose passwords require to be clered.
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
    Write-Host "Usage: .\GetDevicesConsoleNotes.ps1 -apiUrl '<api-url>' -username '<username>' -password '<password>' -authToken '<auth-token>' -CsvInputFilePath '<CsvInputFilePath>' -CsvOutputFilePath '<CsvOutputFilePath>'"
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
            continue
        }
        Write-Host "Processing device serial number: $SerialNumber"
        #API Endpoint to retrieve devices (adjust based on the UEM API)
        $endpoint = "/API/mdm/devices/notes?searchBy=SerialNumber&id=$SerialNumber"
        $fullApiUrl = "https://" + $apiUrl + $endpoint

        # Send Post Request to Workspace ONE UEM API using the authentication token
        try {
            $Response = Invoke-RestMethod -Uri $fullApiUrl -ContentType "application/json" -Method Get -Headers $Headers #invoking commmand to get device notes
           
            #Converting the response object into a string
            $note = $Response | Out-String 
            
            # Output the response
            Write-Host "Retrieving notes from Device: $SerialNumber"
            $startIndex = $note.IndexOf("Note=")  # Find where 'Note' starts
            $endIndex = $note.IndexOf("Created")  # Find where 'Created' starts

            if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
                # Extract substring from 'note' to 'Created'
                $cleanedNote = $note.Substring($startIndex, $endIndex - $startIndex).Trim()

                # Constructing the Output
                #$deviceInfo = $serialNumber + " | " + $cleanedNote
                $deviceInfo = [PSCustomObject]@{
                    SerialNumber = $serialNumber
                    Note         = $cleanedNote
                }
                
                
                # Output the extracted information to the output file
                $deviceInfo | Out-File -Append -FilePath $CsvOutputFilePath  
                }
                
            }
       catch {
                Write-Host "Error: $($_.Exception.Message)"
             }
}