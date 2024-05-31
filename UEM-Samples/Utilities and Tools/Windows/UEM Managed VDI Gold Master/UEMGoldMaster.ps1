<#
.SYNOPSIS
    Enrolls the machine to Workspace ONE Unified Endpoint Management, installs all apps and Windows updates, then unenrolls the machine, leaving those apps and updates installed.
.NOTES
    Created:        April 2022
    Created by:     Max Fox
    Updated by:	    Max Fox
    Organization:   VMware, Inc.
    Filename:       UEMGoldMaster.ps1
.DESCRIPTION
    Enrolls the machine to Workspace ONE Unified Endpoint Management. Then makes sure that all assigned apps and profiles are on the device, before installing all available windows updates. After this, it unenrolls the device, leaving the previously installed apps and updates on the device, so that we can seal the device as a Gold Master image. After this the device will be deleted from the Workspace ONE Unified Endpoint Management console.
.EXAMPLE
    .\UEMGoldMaster.ps1 -ApiUsername administrator -ApiPassword verysecurepassword -UemUrl https://cnuemurl.com -TenantCode VGhpcyBpcyBhIGJhc2U2NCBzdHJpbmcgaXNuJ3QgaXQ= -EnrollmentUrl https://dsuemurl.com -EnrollmentUsername enrollmentuser -EnrollmentPassword verysecurepassword -EnrollmentOG gldmstr -AgentMsiPath C:\Recovery\OEM\AirwatchAgent.msi
#>


param (
    # API/Administrator username into UEM. Necessary if -ApiCredential isn't passed in.
    [Parameter(Mandatory=$false)]
    [string]$ApiUsername = $null,
    # API/Administrator password into UEM. Necessary if -ApiCredential isn't passed in.
    [Parameter(Mandatory=$false)]
    [String]$ApiPassword = $null,
    # API/Administrator credential into UEM.
    [Parameter(Mandatory=$false)]
    [pscredential]$ApiCredential = $null,
    # UEM URL to use.
    [Parameter(Mandatory=$true)]
    [string]$UemUrl,
    # UEM API Tenant Code.
    [Parameter(Mandatory=$true)]
    [string]$TenantCode,
    # Enrollment URL if different to the UEM one, defaults to the -UemUrl value
    [Parameter(Mandatory=$false)]
    [string]$EnrollmentUrl=$UemUrl,
    # Enrollment user username
    [Parameter(Mandatory=$true)]
    [string]$EnrollmentUsername,
    # Enrollment user password
    [Parameter(Mandatory=$true)]
    [string]$EnrollmentPassword,
    # Enrollment organizational group
    [Parameter(Mandatory=$true)]
    [string]$EnrollmentOG,
    # Path to the AirwatchAgent.msi. Defaults to "AirwatchAgent.msi" in the current directory.
    [Parameter(Mandatory=$false)]
    [string]$AgentMsiPath=(Join-Path -Path (Get-Location) -ChildPath "AirwatchAgent.msi"),
    # Don't enroll the device.
    [switch]$SkipEnroll,
    # Don't check for apps or profiles, and don't apply windows updates.
    [switch]$SkipUpdate,
    # Don't unenroll the device. (Also sets -SkipUninstall and -SkipCleanup).
    [switch]$SkipUnenroll,
    # Skip uninstall. This leaves the Workspace ONE Unified Endpoint Management agent on the device in an unenrolled state.
    [switch]$SkipUninstall,
    # Skip the cleanup where the device is deleted from the Workspace ONE Unified Endpoint Management console.
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

$MaxRetriesOnSuccessfulApiCalls = 30

class UemApiConnection {
    [string]$BaseUrl
    [string]$ApiTenantCode
    [pscredential]$ApiCredential
    [System.Collections.IDictionary]$BaseApiHeaders

    UemApiConnection(
        [string]$baseUrl,
        [string]$apiTenantCode,
        [string]$apiUsername,
        [string]$apiPassword
    ) {
        $this.BaseUrl = $baseUrl
        $this.ApiTenantCode = $apiTenantCode
        $secureStringApiPassword = ConvertTo-SecureString -AsPlainText -String $apiPassword -Force
        $this.ApiCredential = New-Object System.Management.Automation.PSCredential ($apiUsername, $secureStringApiPassword)
        $this.BaseApiHeaders = @{
            "aw-tenant-code" = $this.ApiTenantCode
            "Accept" = "application/json"
        }
    }

    UemApiConnection(
        [string]$baseUrl,
        [string]$apiTenantCode,
        [pscredential]$apiCredential
    ) {
        $this.BaseUrl = $baseUrl
        $this.ApiTenantCode = $apiTenantCode
        $this.ApiCredential = $apiCredential
        $this.BaseApiHeaders = @{
            "aw-tenant-code" = $this.ApiTenantCode
            "Accept" = "application/json"
        }
    }
}

function Invoke-RestMethodWithRetry {
    param (
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,
        [uri]$Uri,
        [pscredential]$Credential,
        [System.Collections.IDictionary]$Headers,
        [object]$Body=$null,
        [int]$MaxAttempts = 5,
        [int]$RetryInterval = 120,
        [int[]]$AdditionalTransientStatusCodes
    )

    $attempts = 0
    while ($attempts -lt $MaxAttempts) {
        try {
            $response = Invoke-RestMethod -Method $Method -Uri $Uri -Credential $Credential -Headers $Headers -Body $Body
            return $response
        } catch {
            $errorResponse = $_.Exception.Response

            if ($errorResponse) {
                $statusCode = $errorResponse.StatusCode.value__

                if (($statusCode -ge 400 -and $statusCode -lt 500) -and $statusCode -ne 408 -and $AdditionalTransientStatusCodes -notcontains $statusCode) {
                    # Status Code is a 4xx code that isn't 408 or any given transient code. Unrecoverable.
                    throw $_.Exception
                }
            }
        }

        $attempts++
        Start-Sleep -Seconds (60 * [Math]::Pow(2, $attempts))
    }
}

function Get-HttpResponseReason {
    param (
        $response
    )
    if ($response.StatusDescription) {
        return $response.StatusDescription
    } elseif ($response.ReasonPhrase) {
        return $response.ReasonPhrase
    } else {
        return "Unknown"
    }
}


function Get-UemAgentInstallInfo {
    $installInfo = Get-WmiObject -Class Win32_Product -Filter "Name = 'Workspace ONE Intelligent Hub Installer'"
    return $installInfo
}

function Install-UemAgent {
    param (
        [Parameter(Mandatory=$true)]
        [string]$agentMsiPath,
        [Parameter(Mandatory=$true)]
        [string]$enrollmentUrl,
        [Parameter(Mandatory=$true)]
        [string]$enrollmentOG,
        [Parameter(Mandatory=$true)]
        [string]$enrollmentUsername,
        [Parameter(Mandatory=$true)]
        [string]$enrollmentPassword
    )
    # install/enroll WS1 UEM.
    $installInfo = Get-UemAgentInstallInfo
    if ($installInfo -and $installInfo.InstallState -eq 5) {
        Write-Host "UEM agent is already installed, continuing"
    }
    else {
        if (-not (Test-Path -Path $agentMsiPath)) {
            Write-Error "Cannot find ${agentMsiPath}"
        }
        Write-Host "Installing UEM agent"
        msiexec /i $AgentMsiPath /qn /L*V (Join-Path -Path $PSScriptRoot -ChildPath "AirwatchAgent.msi.log") ENROLL=Y SERVER=$enrollmentUrl LGNAME=$enrollmentOG USERNAME=$enrollmentUsername PASSWORD=$enrollmentPassword
    }
}

function Get-EnrollmentInfo {
    param (
        [Parameter(Mandatory=$true)]
        [UemApiConnection]$apiConnection,
        [Parameter(Mandatory=$true)]
        [string]$serialNumber,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Enrolled", "Unenrolled", IgnoreCase=$true)]
        [string]$expectedStatus = "Enrolled"
    )

    $enrollmentFound = $false
    $attemptCount = 0

    $id = $null
    $uuid = $null
    $udid = $null
    $status = $null

    Add-Type -AssemblyName System.Web
    $url = "$($apiConnection.BaseUrl)/API/mdm/devices?searchby=SerialNumber&id=$([System.Web.HttpUtility]::UrlEncode($serialNumber))"
    while (-not $enrollmentFound -and $attemptCount -lt $MaxRetriesOnSuccessfulApiCalls) {
        $response = $null
        try {
            $response = Invoke-RestMethodWithRetry -Method Get -Uri $url -Credential $apiConnection.ApiCredential -Headers $apiConnection.BaseApiHeaders -AdditionalTransientStatusCodes @(404)
        } catch {
            $errorResponse = $_.Exception.Response
            $reason = Get-HttpResponseReason $errorResponse
            Write-Error "Enrollment not found. Reason: $reason"
        }

        if ($response -and $response.EnrollmentStatus -eq $expectedStatus) {
            $enrollmentFound = $true
            $udid = $response.Udid
            $uuid = $response.Uuid
            $id = $response.Id.Value
            $status = $response.EnrollmentStatus
            Write-Host "Device found as $($expectedStatus.ToLowerInvariant())."
            Write-Host "ID   = ${id}"
            Write-Host "UUID = ${uuid}"
            Write-Host "UDID = ${udid}"
        } else {
            $attemptCount++
            Write-Host "Device is not $($expectedStatus.ToLowerInvariant()) yet, retrying in 2 minutes..."
            Start-Sleep -Seconds 120 # poll only once every 2 mins
        }
    }
    if ($enrollmentFound) {
        return @{
            Status = $status
            ID = $id;
            UUID = $uuid;
            UDID = $udid;
        }
    } else {
        Write-Error "Enrollment still not found in the desired state after ${attemptCount} attempts."
    }
}

function Test-UemAppsInstalled {
    param (
        [Parameter(Mandatory=$true)]
        [UemApiConnection]$apiConnection,
        [Parameter(Mandatory=$true)]
        [string]$deviceUuid
    )

    $appsUrl = "$($apiConnection.BaseUrl)/API/mdm/devices/$([System.Web.HttpUtility]::UrlEncode($deviceUuid))/apps/search"
    $appsComplete = $false

    $pendingAppNames = @()
    $pendingAppsCount = 0

    $attemptCount = 0

    while (-not $appsComplete -and $attemptCount -lt $MaxRetriesOnSuccessfulApiCalls) {
        $appsResponse = $null

        try {
            $appsResponse = Invoke-RestMethodWithRetry -Method Get -Uri $appsUrl -Credential $apiConnection.ApiCredential -Headers $apiConnection.BaseApiHeaders
        } catch {
            $errorResponse = $_.Exception.Response
            $reason = Get-HttpResponseReason $errorResponse
            Write-Error "Error getting apps information: $reason"
        }

        if ($appsResponse) {
            $assignedApps = $appsResponse.app_items | Where-Object { $_.assignment_status -eq "Assigned" }
            $installedApps = $assignedApps | Where-Object { $_.installed_status -eq "Installed" }
            $pendingApps = $assignedApps | Where-Object { $_.installed_status -ne "Installed" }
            $assignedAppsCount = @($assignedApps).Count
            $installedAppsCount = @($installedApps).Count
            $pendingAppsCount = @($pendingApps).Count
            $pendingAppNames = $pendingApps.name
            if ($assignedAppsCount -eq 0 -and $pendingAppsCount -eq 0) {
                Write-Host "No apps found... skipping..."
            } else {
                Write-Host "Installed ${installedAppsCount}/${assignedAppsCount} apps..."
            }
            if ($pendingAppsCount -eq 0) {
                $appsComplete = $true
            }
        } else {
            Write-Host "No apps found... skipping..."
            $appsComplete = $true
        }

        $attemptCount++
        if (-not $appsComplete) {
            Write-Host "Sleeping for 2 minutes to try and install remaining $pendingAppsCount app(s)..."
            Start-Sleep -Seconds 120 # poll only once every 2 mins
        }
    }

    if (-not $appsComplete) {
        Write-Host "The following $pendingAppsCount apps failed to install in time:`n$pendingAppNames"
    }

    return $appsComplete
}

function Test-UemProfilesInstalled {
    param (
        [Parameter(Mandatory=$true)]
        [UemApiConnection]$apiConnection,
        [Parameter(Mandatory=$true)]
        [int32]$deviceId
    )

    $profilesUrl = "$($apiConnection.BaseUrl)/API/mdm/devices/${deviceId}/profiles"
    $profilesComplete = $false

    $pendingProfileNames = @{}
    $pendingProfilesCount = 0

    $attemptCount = 0

    while (-not $profilesComplete -and $attemptCount -lt $MaxRetriesOnSuccessfulApiCalls) {
        $profilesResponse = $null

        try {
            $profilesResponse = Invoke-RestMethodWithRetry -Method Get -Uri $profilesUrl -Credential $apiConnection.ApiCredential -Headers $apiConnection.BaseApiHeaders
        } catch {
            $errorResponse = $_.Exception.Response
            $reason = Get-HttpResponseReason $errorResponse
            Write-Error "Error getting profiles information: $reason"
        }

        if ($profilesResponse) {
            $assignedProfiles = $profilesResponse.DeviceProfiles | Where-Object { $_.AssignmentType -eq 1 }
            $installedProfiles = $assignedProfiles | Where-Object { $_.Status -eq 3 }
            $pendingProfiles = $assignedProfiles | Where-Object { $_.Status -ne 3 }
            $pendingProfileNames = $pendingProfiles.Name
            $assignedProfilesCount = @($assignedProfiles).Count
            $installedProfilesCount = @($installedProfiles).Count
            $pendingProfilesCount = @($pendingProfiles).Count
            if ($assignedProfilesCount -eq 0 -and $pendingProfilesCount -eq 0) {
                Write-Host "No profiles found... skipping..."
            } else {
                Write-Host "Installed ${installedProfilesCount}/${assignedProfilesCount} profile(s)..."
            }
            if ($pendingProfilesCount -eq 0) {
                $profilesComplete = $true
            }
        } else {
            Write-Host "No profiles found... skipping..."
            $profilesComplete = $true
        }

        $attemptCount++
        if (-not $profilesComplete) {
            Write-Host "Sleeping for 2 minutes to try and install remaining $pendingProfilesCount profile(s)..."
            Start-Sleep -Seconds 120 # poll only once every 2 mins
        }
    }

    if (-not $profilesComplete) {
        Write-Host "The following $pendingProfilesCount profiles failed to install in time:`n$pendingProfileNames"
    }

    return $profilesComplete
}

function Install-WindowsUpdates {
    Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.208 -Force | Out-Null
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module PSWindowsUpdate -Force -MinimumVersion 2.2.0.2 | Out-Null
    }
    Import-Module -Name "PSwindowsUpdate" -MinimumVersion 2.2.0.2 | Out-Null
    $updates = Get-WindowsUpdate

    if ($null -eq $updates -or $updates.Count -eq 0) {
        Write-Host "No updates to install."
        return
    }

    Write-Host "Installing the following updates:"
    $updates | ForEach-Object {
        Write-Host ([string]$_.Title)
    }

    $rebootRequired = $updates.RebootRequired -contains $true

    if ($rebootRequired) {
        Write-Host "Reboot will be required for updates to finish"
    }

    Install-WindowsUpdate -AcceptAll -Install -AutoReboot | Out-Null

    return $rebootRequired
}

function Add-KeepAppsPolicy {

    $deployCmdPath = Join-Path -Path $env:ProgramFiles -ChildPath "\VMware\SfdAgent\VMware.Hub.SfdAgent.DeployCmd.exe"
    if (-not (Test-Path -Path $deployCmdPath)) {
        Write-Error "Unable to find VMware.Hub.SfdAgent.DeployCmd.exe"
    }

    $keepAppsString = '{"policies":{"enterprise_wipe_options":{"keep_app":true,"keep_appdata":true}}}'

    $policyPath = Join-Path -Path $env:TEMP -ChildPath "sfdpolicy.json"

    Set-Content -Path $policyPath -Value $keepAppsString

    & $deployCmdPath /addpolicy $policyPath | Out-Null

    $regItem = Get-ItemProperty -Path "HKLM:\SOFTWARE\AirWatchMDM\AppDeploymentAgent\Policy\{00000000-0000-0000-0000-000000000000}"
    if (-not $regItem.PolicyJson -or
        $regItem.PolicyJson.Trim() -ne $keepAppsString -or
        -not $regItem.KeepApps -or
        -not $regItem.KeepAppData) {
        Write-Error "SFD policy to keep apps wasn't correctly applied"
    }

    Remove-Item $policyPath
}

function Remove-Enrollment {

    Add-KeepAppsPolicy

    $awProcessCommandsPath = "$(${env:ProgramFiles(x86)})\Airwatch\AgentUI\AWProcessCommands.exe"

    if (-not (Test-Path $awProcessCommandsPath)) {
        Write-Error "Unable to find AWProcessCommands.exe"
        return $false
    }

    & $awProcessCommandsPath Unenroll
    return $true
}

function Remove-UemAgent {
    Write-Host "Checking if uninstall is required"
    $installInfo = Get-UemAgentInstallInfo

    if ($installInfo -and $installInfo.InstallState -eq 5) {
        Write-Host "Uninstall required"
        $installInfo.Uninstall() | Out-Null
    } else {
        Write-Host "Uninstall not required"
    }
}

function Remove-EnrollmentFromUem {
    param (
        [Parameter(Mandatory=$true)]
        [UemApiConnection]$apiConnection,
        [Parameter(Mandatory=$true)]
        [int32]$deviceId
    )

    Write-Host "Deleting enrollment from UEM console."

    try {
        $deleteUrl = "$($apiConnection.BaseUrl)/API/mdm/devices?id=${deviceId}&searchby=DeviceId"
        Invoke-RestMethodWithRetry -Method Delete -Uri $deleteUrl -Credential $apiConnection.ApiCredential -Headers $apiConnection.BaseApiHeaders
    } catch {
        $errorResponse = $_.Exception.Response
        $reason = Get-HttpResponseReason $errorResponse
        Write-Error "Error deleting enrollment from UEM console: $reason"
    }
}

$x = $PSScriptRoot
$serialNumber = (Get-WmiObject Win32_BIOS).SerialNumber
Write-Host "Serial Number: `"$serialNumber`""

[UemApiConnection]$uemApiConnection = $null

if ($ApiCredential) {
    $uemApiConnection = [UemApiConnection]::new($UemUrl, $TenantCode, $ApiCredential)
} elseif ($ApiUsername -and $ApiPassword) {
    $uemApiConnection = [UemApiConnection]::new($UemUrl, $TenantCode, $ApiUsername, $ApiPassword)
} else {
    Write-Error "Please supply an API credential (either using Get-Credentails, or supply a username and password)"
}

$enrollmentInfo = $null


if (-not $SkipEnroll) {
    Install-UemAgent -agentMsiPath $AgentMsiPath -enrollmentUrl $EnrollmentUrl -enrollmentOG $EnrollmentOG -enrollmentUsername $EnrollmentUsername -enrollmentPassword $EnrollmentPassword
}

if (-not $SkipUpdate) {
    $enrollmentInfo = Get-EnrollmentInfo -apiConnection $uemApiConnection -serialNumber $serialNumber -expectedStatus "Enrolled"
    $profilesInstalled = Test-UemProfilesInstalled -apiConnection $uemApiConnection -deviceId $enrollmentInfo.ID
    $appsInstalled = Test-UemAppsInstalled -apiConnection $uemApiConnection -deviceUuid $enrollmentInfo.UUID

    if ((-not $appsInstalled) -or (-not $profilesInstalled)) {
        Write-Error "All apps and profiles are not installed."
    }

    $rebootRequired = Install-WindowsUpdates

    if ($rebootRequired) {
        Write-Host "Reboot is required, rebooting..."
        Restart-Computer
    }
}

if (-not $SkipUnenroll) {
    $unenrolled = Remove-Enrollment

    if (-not $unenrolled) {
        Write-Error "Unable to unenroll the device"
    }

    if (-not $SkipUninstall) {
        Remove-UemAgent
    }

    if (-not $SkipCleanup) {
        $enrollmentInfo = Get-EnrollmentInfo -apiConnection $uemApiConnection -serialNumber $serialNumber -expectedStatus "Unenrolled"
        Remove-EnrollmentFromUem -apiConnection $uemApiConnection -deviceId $enrollmentInfo.ID
    }
}
