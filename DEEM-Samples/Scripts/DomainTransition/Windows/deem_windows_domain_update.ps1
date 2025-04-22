$supportedVersions = @("23.6", "23.10", "24.7", "24.12")
$url = "api.na1.region.data.workspaceone.com"
$Global:serviceName = ""
$Global:intelUrlUpdated = $false  

# Define log file path
$logFilePath = "$Env:Temp\DEEM_Script_Log\deem_script.log"

# Ensure the log directory exists with error handling
try {
    $logDirectory = Split-Path -Path $logFilePath
    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -ErrorAction Stop | Out-Null
    }
} catch {
    Write-Log "Failed to create log directory '$logDirectory'. Error: $_"
    throw  # Exit script if log directory cannot be created
}

# Function to write logs to the log file
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFilePath -Value $logMessage
}

# Function to update the Intel URL
function Update-IntelURL {
    param (
        [string]$configPath,
        [string]$dpaAuthUrlRegionKey
    )

    try {
        # Check if the full path exists, and create it if it doesn't
        if (-not (Test-Path $configPath)) {
            Write-Log "Registry path '$configPath' does not exist. Creating it..."
            try {
                New-Item -Path $configPath -Force -ErrorAction Stop | Out-Null
                Write-Log "Registry path '$configPath' created successfully."
            } catch {
                Write-Log "Failed to create registry path '$configPath'. Error: $_"
                return $false
            }
        }

        # Check if the URL is already set
        $currentValue = $null
        try {
            $currentValue = (Get-ItemProperty -Path $configPath -Name $dpaAuthUrlRegionKey -ErrorAction SilentlyContinue).$dpaAuthUrlRegionKey
        } catch {
            Write-Log "Property '$dpaAuthUrlRegionKey' does not exist in '$configPath'. It will be created."
        }

        if ($currentValue -eq $url) {
            Write-Log "The URL is already set to '$url'. No changes needed."
            return $false  # Indicate that no update was performed
        }

        # Add or update the DpaAuthUrlRegion value
        try {
            if ($currentValue -eq $null) {
                # Create the property if it does not exist
                New-ItemProperty -Path $configPath -Name $dpaAuthUrlRegionKey -Value $url -PropertyType String -Force -ErrorAction Stop | Out-Null
                Write-Log "Intel URL property '$dpaAuthUrlRegionKey' created at path: '$configPath' with value: '$url'"
            } else {
                # Update the property if it exists
                Set-ItemProperty -Path $configPath -Name $dpaAuthUrlRegionKey -Value $url -ErrorAction Stop
                Write-Log "Intel URL updated at path: '$configPath' with key: '$dpaAuthUrlRegionKey'"
            }
            return $true  # Indicate that the update was successful
        } catch {
            Write-Log "Failed to update Intel URL at path: '$configPath' with key: '$dpaAuthUrlRegionKey'. Error: $_"
            return $false  # Indicate that the update failed
        }
    } catch {
        Write-Log "An unexpected error occurred in Update-IntelURL. Error: $_"
        return $false  # Indicate that the function failed
    }
}

# Helper function to retrieve product version
function Get-ProductVersion {
    param (
        [string]$productName
    )

    try {
        # Attempt to retrieve the product version
        $productVersion = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
            -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $productName } | Select-Object -ExpandProperty DisplayVersion

        # Check if the product version starts with any of the supported versions
        if ($productVersion -and ($supportedVersions | Where-Object { $productVersion -like "$_*" })) {
            Write-Log "Product version '$productVersion' found for product '$productName'."
            return $productVersion
        }

        Write-Log "No matching product version found for product '$productName'."
        return $null
    } catch {
        # Log any unexpected errors
        Write-Log "An error occurred while retrieving the product version for '$productName'. Error: $_"
        return $null
    }
}

# Function to handle DEEM MixMode ("23.06", "23.10", "24.07")
function Handle-DEEM-MixMode {
    try {
        $configPath = "HKLM:\SOFTWARE\VMware, Inc.\VMware EUC Telemetry\Service\Configuration"
        if (Update-IntelURL -configPath $configPath -dpaAuthUrlRegionKey "dpaauthurl_region") {
            $Global:serviceName = "vmwetlm"
            $Global:intelUrlUpdated = $true
        }
    } catch {
        Write-Log "An error occurred in Handle-DEEM-MixMode. Error: $_"
    }
}

# Function to handle the DEEM 24.12
function Handle-DEEM-2412 {
    try {
        # Check registry path for integration key
        $integrationPath = "HKLM:\SOFTWARE\WorkspaceONE\Endpoint Telemetry\Installer\Integration"
        $configPath = "HKLM:\SOFTWARE\WorkspaceONE\Endpoint Telemetry\Service\Config\IntelUemForwarder"

        if (Test-Path $integrationPath) {
            $hubValue = (Get-ItemProperty -Path $integrationPath -Name "Hub" -ErrorAction SilentlyContinue).Hub
            if ($hubValue) {
                if (Update-IntelURL -configPath $configPath -dpaAuthUrlRegionKey "DpaAuthUrlRegion") {
                    $Global:serviceName = "ws1etlm"
                    $Global:intelUrlUpdated = $true
                    return
                }
            }
        }

        # Special Case: Horizon and Hub Coexist; Hub has old DEEM version and Hz has new DEEM version
        $productVersion = Get-ProductVersion -productName "VMware DEEM for Intelligent Hub"
        if ($productVersion) {
            if (Update-IntelURL -configPath $configPath -dpaAuthUrlRegionKey "DpaAuthUrlRegion") {
                $Global:serviceName = "ws1etlm"
                $Global:intelUrlUpdated = $true
                return
            }
        }

        Write-Log "No valid registry path or product version found for 'Omnissa Workspace ONE Experience Management'."
    } catch {
        Write-Log "An error occurred in Handle-DEEM-2412. Error: $_"
    }
}

# Function to handle different DEEM versions
function Handle-DEEM-Version {
    try {
        # Case 1: Handle DEEM 24.12
        $productVersion = Get-ProductVersion -productName "Omnissa Workspace ONE Experience Management"
        if ($productVersion) {
            Handle-DEEM-2412
            return
        }

        # Case 2: Handle DEEM MixMode ("23.06", "23.10", "24.07")
        $productVersion = Get-ProductVersion -productName "VMware DEEM for Intelligent Hub"
        if ($productVersion) {
            Handle-DEEM-MixMode
            return
        }

        # Case 3: Failure (no product found)
        Write-Log "No supported product or version found. Exiting script."
    } catch {
        Write-Log "An error occurred in Handle-DEEM-Version. Error: $_"
    }
}

# Entry Function
Handle-DEEM-Version

# Function to handle logic for serviceName "ws1etlm"
function Handle-ws1etlm {
    try {
        # Path to IntelForwarder folder
        $forwarderPath = $Env:ProgramData + "\WorkspaceONE\ws1etlm\cache\event-store"
        # Delete all folders under event-store
        if (Test-Path $forwarderPath) {
            Write-Log "Deleting all folders under event-store..."
            Remove-Item -Path $forwarderPath\* -Recurse -Force
            Write-Log "All folders under event-store deleted."
        } else {
            Write-Log "event-store folder not found at '$forwarderPath'."
        }
    } catch {
        Write-Log "An error occurred in Handle-ws1etlm. Error: $_"
    }
}

# Function to rename database file for vmwetlm
function Handle-vmwetlm {
    try {
        # Paths to the database files
        $dbPath = $Env:ProgramData + "\VMWOSQEXT\Extensions\vmwosqext.exe\OSQData\data.db"
        $dbOldPath = $Env:ProgramData + "\VMWOSQEXT\Extensions\vmwosqext.exe\OSQData\data_old.db"
        $destinationPath = "$Env:Temp\data_old.db"
        if (Test-Path $dbPath) {
            Write-Log "Database file found at '$dbPath'. Preparing to rename..."
            # Ensure $dbPath is a file
            if ((Get-Item $dbPath).PSIsContainer) {
                Write-Log "Error: '$dbPath' is a directory, not a file. Aborting operation."
                return
            }
            # Check if the file is in use by attempting to open it
            try {
                $fileStream = [System.IO.File]::Open($dbPath, 'Open', 'Read', 'None')
                $fileStream.Close()
            } catch {
                Write-Log "Error: '$dbPath' is currently in use by another process. Aborting operation."
                return
            }
            # Remove existing data_old.db if it exists with retry mechanism
            if (Test-Path $dbOldPath) {
                $retryCount = 3
                $retryDelay = 5
                $removedSuccessfully = $false

                for ($i = 1; $i -le $retryCount; $i++) {
                    try {
                        Remove-Item -Path $dbOldPath -Force
                        Write-Log "Existing data_old.db removed successfully."
                        $removedSuccessfully = $true
                        break
                    } catch {
                        Write-Log "Attempt ${i}: Failed to remove data_old.db. Error: $_"
                        Start-Sleep -Seconds $retryDelay
                    }
                }

                if (-not $removedSuccessfully) {
                    Write-Log "Failed to remove data_old.db after '$retryCount' attempts. Aborting operation."
                    return
                }
            }
            # Rename data.db to data_old.db
            Rename-Item -Path $dbPath -NewName $dbOldPath -ErrorAction Stop
            Write-Log "Database file renamed to data_old.db successfully."
            # Verify the rename operation
            if ((Test-Path $dbOldPath) -and (-not (Test-Path $dbPath))) {
                Write-Log "Rename verification successful: '$dbPath' no longer exists, and '$dbOldPath' exists."
            } else {
                Write-Log "Rename verification failed: '$dbPath' still exists or '$dbOldPath' does not exist."
                return
            }
            # Copy data_old.db to the destination path specified in $destinationPath
            try {
                Copy-Item -Path $dbOldPath -Destination $destinationPath -Force
                Write-Log "data_old.db successfully copied to '$destinationPath'."
            } catch {
                Write-Log "Failed to copy data_old.db to '$destinationPath'. Error: $_"
            }
            # Verify the copy operation
            if (-not (Test-Path $destinationPath)) {
                Write-Log "Error: data_old.db file is missing in C:\ after copy operation."
            }
        } else {
            Write-Log "Database file not found at '$dbPath'. Ensure the file exists and the path is correct."
        }
    } catch {
        Write-Log "Error in Handle-vmwetlm: $_"
    }
}

# Function to retry stopping a service
function Retry-StopService {
    param (
        [string]$serviceName,
        [int]$retryCount = 3,
        [int]$retryDelay = 5
    )

    $stoppedSuccessfully = $false

    for ($i = 1; $i -le $retryCount; $i++) {
        try {
            Stop-Service -Name $serviceName -Force
            Write-Log "Service '$serviceName' stopped successfully."
            $stoppedSuccessfully = $true
            break
        } catch {
            Write-Log "Attempt ${i}: Failed to stop service '$serviceName'. Error: $_"
            Start-Sleep -Seconds $retryDelay
        }
    }

    if (-not $stoppedSuccessfully) {
        Write-Log "Failed to stop service '$serviceName' after $retryCount attempts. Attempting to kill the process..."
        $serviceProcess = Get-WmiObject Win32_Service | Where-Object { $_.Name -eq $serviceName } | Select-Object -ExpandProperty ProcessId
        if ($serviceProcess) {
            try {
                Stop-Process -Id $serviceProcess -Force
                Write-Log "Process associated with '$serviceName' killed successfully."
            } catch {
                Write-Log "Failed to kill the process associated with '$serviceName'. Error: $_"
            }
        } else {
            Write-Log "No process found for '$serviceName'."
        }
    }

    return $stoppedSuccessfully
}

# Restart the service only if the Intel URL was successfully updated
try {
    if ($Global:intelUrlUpdated -and $Global:serviceName) {
        if ($Global:serviceName -eq "ws1etlm") {
            if ($args -contains "--purge-events") {
                Retry-StopService -serviceName $Global:serviceName
                Handle-ws1etlm
            }

            Restart-Service -Name $Global:serviceName -Force
            Write-Log "Service '$Global:serviceName' restarted successfully."

        } elseif ($Global:serviceName -eq "vmwetlm") {
            if ($args -contains "--purge-events") {
                $servicesToStop = @("VMWOSQEXT", $Global:serviceName)
                foreach ($service in $servicesToStop) {
                    Retry-StopService -serviceName $service
                }

                Handle-vmwetlm
            }

            Restart-Service -Name $Global:serviceName -Force
            Write-Log "Service '$Global:serviceName' restarted successfully."

            Restart-Service -Name "VMWOSQEXT" -Force
            Write-Log "Service 'VMWOSQEXT' restarted successfully."
        }
    } else {
        Write-Log "No service to restart or no valid product found."
    }
} catch {
    Write-Log "An error occurred while restarting the service. Error: $_"
}