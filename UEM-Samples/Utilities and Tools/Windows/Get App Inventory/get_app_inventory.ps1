<# 
  .SYNOPSIS
    This script reports on applications in Workspace ONE UEM and provides details including dependent apps.
  .DESCRIPTION
    When run without parameters, this script will prompt for Workspace ONE UEM API Server, credentials, API Key and OG Name. 
    The script then creates a log file in the same directory as the script with a name of GetAppInventory_YYYYMMDD_HHMM.log
    The script will search for the OG Name provided and if multiple OGs are found, will prompt to select one.
    The script then queries the Workspace ONE UEM API for all Windows applications in the selected OG and creates a report of the applications including dependent apps.
    The report is written to the log file and also displayed in the console window.
  .EXAMPLE
    .\uploadlargeapps.ps1 
        -Server https://asXXX.awmdm.com/ 
        -Username USERNAME
        -Password PASSWORD
        -ApiKey APIKEY
        -OGName OGNAME
  .PARAMETER Server
    Server URL for the Workspace ONE UEM API Server
  .PARAMETER UserName
    The Workspace ONE UEM API user name. This group must have rights to be able to create applications,against the REST API. 
  .PARAMETER Password
    The password that is used by the user specified in the username parameter
  .PARAMETER APIKey
    This is the REST API key that is generated in the Workspace ONE UEM Console.  You locate this key at All Settings -> Advanced -> API -> REST,
    and you will find the key in the API Key field.  If it is not there you may need override the settings and Enable API Access
  .PARAMETER OGName
    The OGName is the name of the Organization Group where the apps will be migrated. The script searches for matching OGName and will
    present a list to select from if multiple OGs are found. The API key and admin credentials need to be authenticated at this Organization Group.
    The shorcut to getting this value is to navigate to https://<YOUR HOST>/AirWatch/#/AirWatch/OrganizationGroup/Details.
    The ID you are redirected to appears in the URL (7 in the following example). https://<YOUR HOST>/AirWatch/#/AirWatch/OrganizationGroup/Details/Index/7

  .NOTES 
    Created:   	    September, 2025
    Created by:	    Phil Helmling
    Organization:   Omnissa LLC
    Filename:       get_app_inventory.ps1
    GitHub:         https://github.com/euc-occ/euc-samples/tree/main/UEM-Samples/Utilities%20and%20Tools/Windows/Get%20App%20Inventory
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$Username,
    [Parameter(Mandatory=$false)]
    [string]$Password,
    [Parameter(Mandatory=$false)]
    [string]$OGName,
    [Parameter(Mandatory=$false)]
    [string]$Server,
    [Parameter(Mandatory=$false)]
    [string]$ApiKey
)
$Debug = $false
[string]$psver = $PSVersionTable.PSVersion
$current_path = $PSScriptRoot;
if($PSScriptRoot -eq ""){
    #PSScriptRoot only popuates if the script is being run.  Default to default location if empty
    $current_path = ".";
}

#setup Report/Log file
$DateNow = Get-Date -Format "yyyyMMdd_HHmm";
$pathfile = "$current_path\GetAppInventory_$DateNow";
$Script:logLocation = "$pathfile.log";
$Script:Path = $logLocation;
if($Debug){
  write-host "Path: $Path"
  write-host "LogLocation: $LogLocation"
}

Function setupServerAuth {

  if ([string]::IsNullOrEmpty($script:Server)){
      $script:Server = Read-Host -Prompt 'Enter the Workspace ONE UEM Server Name'
      $private:Username = Read-Host -Prompt 'Enter the Username'
      $SecurePassword = Read-Host -Prompt 'Enter the Password' -AsSecureString
      $script:APIKey = Read-Host -Prompt 'Enter the API Key'
      $script:OGName = Read-Host -Prompt 'Enter the Organizational Group Name'
    
      #Convert the Password
      if($psver -lt 7){
        #Powershell 6 or below
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
      } else {
        #Powershell 7 or above
        $Password = ConvertFrom-SecureString $SecurePassword -AsPlainText
      }
    }

  #Base64 Encode AW Username and Password
  $private:combined = $Username + ":" + $Password
  $private:encoding = [System.Text.Encoding]::ASCII.GetBytes($private:combined)
  $private:encoded = [Convert]::ToBase64String($private:encoding)
  $script:cred = "Basic $encoded"

  $combined = $Username + ":" + $Password
  $encoding = [System.Text.Encoding]::ASCII.GetBytes($combined)
  $encoded = [Convert]::ToBase64String($encoding)
  $cred = "Basic $encoded"
  if($Debug){ 
    Write-host `n"Server Auth" 
    write-host "WS1 Host: $script:Server"
    write-host "Base64 creds: $script:cred"
    write-host "APIKey: $script:APIKey"
    write-host "OG Name: $script:OGName"
  }
}

function GetOG {

  param(
    [Parameter(Mandatory=$true)]
    [string]$OGName
  )
  #Search for the OG Name and return GroupUUID and GroupID attributes.
  #Present list if multiple OGs with those search characters and allow selection

  $url = "$script:server/API/system/groups/search?name=$OGName"
  $header = @{'aw-tenant-code' = $script:APIKey;'Authorization' = $script:cred;'accept' = 'application/json;version=2';'Content-Type' = 'application/json'}
  try {
    $OGSearch = Invoke-RestMethod -Method Get -Uri $url.ToString() -Headers $header
  }
  catch {
    throw "Server Authentication or Server Connection Failure $($_.Exception.Message)`n`n`tExiting"
  }

  $OGSearchOGs = $OGSearch.OrganizationGroups
  $OGSearchTotal = $OGSearch.TotalResults
  if ($OGSearchTotal -eq 1){
    $Choice = 0
  } elseif ($OGSearchTotal -gt 1) {
    $ValidChoices = 0..($OGSearchOGs.Count -1)
    $ValidChoices += 'Q'
    Write-Host "`nMultiple OGs found. Please select an OG from the list:" -ForegroundColor Yellow
    $Choice = ''
    while ([string]::IsNullOrEmpty($Choice)) {

      $i = 0
      foreach ($OG in $OGSearchOGs) {
        Write-Host ('{0}: {1}       {2}       {3}' -f $i, $OG.name, $OG.GroupId, $OG.Country)
        $i += 1
      }

      $Choice = Read-Host -Prompt 'Type the number that corresponds to the OG or Press "Q" to quit'
      if ($Choice -in $ValidChoices) {
        if ($Choice -eq 'Q'){
          Write-host " Exiting Script"
          exit
        } else {
          $Choice = $Choice
        }
      } else {
        [console]::Beep(1000, 300)
        Write-host ('    [ {0} ] is NOT a valid selection.' -f $Choice)
        Write-host '    Please try again ...'
        pause

        $Choice = ''
      }
    }
  }
  return $OGSearchOGs[$Choice]
}

function Get-Apps {
  param(
    [Parameter(Mandatory=$true)]
    [string]$groupid
  )
  $appsearch = ""
  #Search to see if existing app so we can "Add Version"
  $url = "$script:server/api/mam/apps/search?platform=WinRT"
  $header = @{'aw-tenant-code' = $script:APIKey;'Authorization' = $script:cred;'accept' = 'application/json';'Content-Type' = 'application/json'}
  try {
    $appSearch = Invoke-RestMethod -Method Get -Uri $url.ToString() -Headers $header
  }
  catch {
    throw "Server Authentication or Server Connection Failure $($_.Exception.Message)`n`n`tExiting"
  }

  return $appSearch.Application
}

function Get-App {
  param(
    [Parameter(Mandatory=$true)]
    [string]$uuid
  )
  $appsearch = ""
  #Search to see if existing app so we can "Add Version"
  $url = "$script:server/api/mam/apps/internal/$uuid"
  $header = @{'aw-tenant-code' = $script:APIKey;'Authorization' = $script:cred;'accept' = 'application/json;version=2';'Content-Type' = 'application/json'}
  try {
    $appSearch = Invoke-RestMethod -Method Get -Uri $url.ToString() -Headers $header
  }
  catch {
    throw "Server Authentication or Server Connection Failure $($_.Exception.Message)`n`n`tExiting"
  }

  return $appSearch
}

function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)] [ValidateNotNullOrEmpty()] [Alias("LogContent")] [string] $Message,
        [Parameter(Mandatory=$false)] [Alias('LogPath')] [Alias('LogLocation')] [string] $Local:Path=$Script:LogPath,
        [Parameter(Mandatory=$false)] [ValidateSet("Success","Error","Warn","Info")] [string] $Level="Info",
        [Parameter(Mandatory=$false)] [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'

        if(!$Local:Path){
            $Local:Path = $PSScriptRoot;
            if($PSScriptRoot -eq ""){
                #default fallback path
                $Local:Path = "C:\Temp";
            }
        }

        $Local:NewLogFile = "LogFile_{0:yyyyMMdd}.log" -f (Get-Date)
        $Local:NewLogFile = "$Local:Path\$Local:NewLogFile"
        if (!(Test-Path $Local:NewLogFile)) {
            # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
            New-Item -Path $Local:NewLogFile -Force -ItemType File
            $Script:LogFile = $Local:NewLogFile
        } else {
            $Script:LogFile = $Local:NewLogFile
        }

        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffZ"

        $ColorMap = @{"Success"="Green";"Error"="Red";"Warn"="Yellow"}
        $FontColor = "White"
        If($ColorMap.ContainsKey($Level)){
            $FontColor = $ColorMap[$Level]
        }
    }
    Process
    {
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Script:LogFile) -AND $NoClobber) {
            Write-Error "Log file $Local:LogFile already exists, and you specified NoClobber. Either delete the file or specify a different LogPath."
            Return
        }

        # Write message with Date Level and Message
        Add-Content -Path $Script:LogFile -Value ("$timestamp`t$Level`t$Message")
        Write-Host "$Level`t$Message" -ForegroundColor $FontColor
    }
    End
    {

    }
}

function Write-2Report{ 
    [CmdletBinding()]
    Param
    (
        [string]$Message,

        [Alias('LogPath')]
        [Alias('LogLocation')]
        [string]$Path=$Local:Path,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Title","Header","Body","Footer","Error")]
        [string]$Level="Body"
        
    )
    
    $ColorMap = @{"Title"="Cyan";"Header"="Yellow";"Footer"="Yellow";"Error"="Red"};
    $FontColor = "White";
    If($ColorMap.ContainsKey($Level)){
        $FontColor = $ColorMap[$Level];
    }
    if($Level -eq "Error"){
        $Errormsg = @("************************************************************************`n`n`t$Message`n`n************************************************************************`n");
        $Message = $Errormsg
    }

    if($Level -eq "Title"){
        $DateNow = Get-Date -Format f;
        $Title = @("************************************************************************`n`n`t$Message`n`n`t$DateNow`n`n************************************************************************`n");
        $Message = $Title
    }

    if($Level -eq "Footer"){
        $Footer = @("************************************************************************`n`n`t$Message`n`n************************************************************************`n");
        $Message = $Footer
    }

    Add-Content -Path $Path -Value ("$Message")
    Write-Host "$Message" -ForegroundColor $FontColor;
    
}

function Main{
  #Setup Server Auth
  setupServerAuth
  #Get OG Info
  $OG = GetOG -OGName $script:OGName
  if($Debug){
    Write-Host "`nSelected OG Info"
    Write-Host "Name: $($OG.Name)"
    Write-Host "GroupID: $($OG.GroupId)"
    Write-Host "GroupUUID: $($OG.Uuid)"
    Write-Host "Country: $($OG.Country)"
    Write-Host "Users: $($OG.Users)"
    Write-Host "Admins: $($OG.Admins)"
    Write-Host "Devices: $($OG.Devices)"
  }
  Write-2Report -Path $Script:Path -Message "WS1 App Inventory Report" -Level "Title"
  Write-2Report -Path $Script:Path -Message "Selected OG: $($OG.Name) ($($OG.Uuid))" -Level "Header"
  
  #Get Existing Apps
  $getApps = Get-Apps -groupid $OG.GroupId
  $getAppsCount = $getApps.Count
  if($getAppsCount -ge 500){
    Write-2Report -Path $Script:Path -Message "Existing Apps in OG: >= 500" -Level "Header"
  }else{
    Write-2Report -Path $Script:Path -Message "Existing Apps in OG: $($getApps.Count)" -Level "Header"
  }

  $appList = @()
  #Iterate through apps to add dependency apps info
  foreach ($app in $getApps) {

    $Assignments = $app.SmartGroups
    foreach ($sg in $Assignments) {
      if ($strsg -eq $null) {
        $strsg = $sg.Name
      } else {
        $strsg += ", " + $sg.Name
      }
    }
    $SmartGroups = $strsg

    $Models = $app.SupportedModels | Select-Object -ExpandProperty Model
    foreach ($sm in $Models) {
      if ($strsm -eq $null) {
        $strsm = $sm.ModelName
      } else {
        $strsm += ", " + $sm.ModelName
      }
    }
    $SupportedModels = $strsm

    #Get Dependent Apps info and other details provided in the other API call
    $appuuid = $app.Uuid
    $appDetails = Get-App -uuid $appuuid
    
    $AppDependenciesList = $appDetails | Select-Object -ExpandProperty FilesOptions | Select-Object -ExpandProperty AppDependenciesList
    foreach ($dep in $AppDependenciesList) {
      if ($strdep -eq $null) {
        $strdep = $dep.Name
      } else {
        $strdep += ", " + $dep.Name
      }
    }
    $DependencyApps = $strdep
    
    $PSObject = New-Object PSObject -Property @{
      ApplicationName = $app.ApplicationName
      AppVersion = $app.AppVersion
      Uuid = $app.Uuid
      Status = $app.Status
      BundleId = $app.BundleId
      RootLocationGroupName = $app.RootLocationGroupName
      AssignedDeviceCount = $app.AssignedDeviceCount
      InstalledDeviceCount = $app.InstalledDeviceCount
      ApplicationFileName = $app.ApplicationFileName
      AppSizeInKB = $appDetails.AppSizeInKB
      SupportedModels = $SupportedModels
      MinimumOperatingSystem = $appDetails.MinimumOperatingSystem
      DependencyApps = $DependencyApps
      SmartGroups = $SmartGroups
      ExcludedSmartGroupGuids = $depApp.ExcludedSmartGroupGuids
    }
    $appList += $PSObject

    #Reset string variables
    $strsm = $null
    $strsg = $null
    $strdep = $null
  }

  $appProperties = @(
    @{N="Application";E={$_.ApplicationName}},
    @{N="Version";E={$_.AppVersion}},
    @{N="File Name";E={$_.ApplicationFileName}},
    @{n="File Size";E={$_.AppSizeInKB}},
    @{N="Supported Models";E={$_.SupportedModels}},
    @{N="Min OS Version";E={$_.MinimumOperatingSystem}},
    @{N="Dependency Apps";E={$_.DependencyApps}}
    @{N="Assigned SGs";E={$_.SmartGroups}},
    @{N="Excl SGs";E={$_.ExcludedSmartGroupGuids}},
    @{N="Assigned Device";E={$_.AssignedDeviceCount}},
    @{N="Installed Device";E={$_.InstalledDeviceCount}},
    @{N="Status";E={$_.Status}}
  )

  $csvLocation = $pathfile+".csv"
  $appList | Sort-Object ApplicationName, AppVersion | Select-Object -Property $appProperties | Export-Csv -Path $csvLocation -NoTypeInformation -Encoding UTF8
  $strAppArray = $appList | Sort-Object ApplicationName, AppVersion | Format-Table -Property $appProperties | Out-String
  Write-2Report -Path $Script:Path -Message $strAppArray -Level "Body"
  Write-2Report -Path $Script:Path -Message "End of Report" -Level "Footer"
}

Main