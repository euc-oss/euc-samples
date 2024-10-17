
<# Execute-AWRestAPI Powershell Script Help

  .SYNOPSIS
    This Poweshell script make a REST API call to an AirWatch server.  This particular script is used to build an Assignment
    Group for all supervised devices.  There is currently no filter in the console
    
  .DESCRIPTION
    To understand the underlying call check:
    https://<your_AirWatch_Server>/api/mdm/devices/search - this script uses the platform filter to select just iOS devices
    https://<your_AirWatch_Server>/api/mdm/tags/search - checks for a Supervised tag, and if not found creates one.
    It is always helpful to validate your parameter using something like the PostMan extension for Chrome
    https://chrome.google.com/webstore/detail/postman/fhbjgbiflinjbdggehcddcbncdddomop?hl=en

  .EXAMPLE
    Execute-AWRestAPI.ps1 -userName Administrator -password password -tenantAPIKey 4+apikeyw/krandomSstuffIleq4MY6A7WPmo9K9AbM6A= -outputFile c:\Users\Administrator\Desktop\output.txt -endpointURL https://demo.awmdm.com/API/v1/mdm/devices/serialnumber  -inputFile C:\Users\Administrator\Desktop\SerialNumbers1.txt -Verbose
  
  .PARAMETER userName
    An AirWatch account in the tenant is being queried.  This user must have the API role at a minimum.

  .PARAMETER password
    The password that is used by the user specified in the username parameter

  .PARAMETER tenantAPIKey
    This is the REST API key that is generated in the AirWatch Console.  You locate this key at All Settings -> Advanced -> API -> REST,
    and you will find the key in the API Key field.  If it is not there you may need override the settings and Enable API Access

  .PARAMETER airwatchServer
    This will be the https://<your_AirWatch_Server>.  All of the REST endpoints start with a forward slash (/) so do not include that with
    the server name

  .PARAMETER organizationGroupName
    This will be the organization group name in the AirWatch console.
    
#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$userName,

        [Parameter(Mandatory=$True)]
        [string]$password,

        [Parameter(Mandatory=$True)]
        [string]$tenantAPIKey,

        [Parameter(Mandatory=$True)]
        [string]$airwatchServer,

        [Parameter(Mandatory=$True)]
        [string]$organizationGroupName
)

Write-Verbose "-- Command Line Parameters --"
Write-Verbose ("UserName: " + $userName)
Write-Verbose ("Password: " + $password)
Write-Verbose ("Tenant API Key: " + $tenantAPIKey)
Write-Verbose ("AirWatchServer URL: " + $airwatchServer)
Write-Verbose ("Organization Group Name: " + $organizationGroupName)
Write-Verbose "-----------------------------"
Write-Verbose ""

<#
  This implementation uses Baisc authentication.  See "Client side" at https://en.wikipedia.org/wiki/Basic_access_authentication for a description
  of this implementation.
#>
Function Get-BasicUserForAuth {

	Param([string]$func_username)

	$userNameWithPassword = $func_username
	$encoding = [System.Text.Encoding]::ASCII.GetBytes($userNameWithPassword)
	$encodedString = [Convert]::ToBase64String($encoding)

	Return "Basic " + $encodedString
}

Function Build-Headers {

    Param([string]$authoriztionString, [string]$tenantCode, [string]$acceptType, [string]$contentType)

    $authString = $authoriztionString
    $tcode = $tenantCode
    $accept = $acceptType
    $content = $contentType

    Write-Verbose("---------- Headers ----------")
    Write-Verbose("Authorization: " + $authString)
    Write-Verbose("aw-tenant-code:" + $tcode)
    Write-Verbose("Accept: " + $accept)
    Write-Verbose("Content-Type: " + $content)
    Write-Verbose("------------------------------")
    Write-Verbose("")
    $header = @{"Authorization" = $authString; "aw-tenant-code" = $tcode; "Accept" = $useJSON; "Content-Type" = $useJSON}
     
    Return $header
}

Function Get-OrganizationGroupID {

    Param([string]$organizationGroupName, $airwatchServer, [object]$headers)

    Write-Verbose("------------------------------")
    Write-Verbose("Getting Group ID from Group Name")

    $endpointURL = $airwatchServer + "/api/system/groups/search?groupID=" + $organizationGroupName
    $webReturn = Invoke-RestMethod -Method Get -Uri $endpointURL -Headers $headers
    $totalReturned = $webReturn.Total
    $groupID = -1
    If ($webReturn.Total = 1) {
        $groupID = $webReturn.LocationGroups.Id.Value
        Write-Verbose("Group ID for " + $organizationGroupName + " = " + $groupID)
    } else {
        Write-Output("Group Name: " + $organizationGroupName + " not found")
    }
    
    Write-Verbose("------------------------------")
    Write-Verbose("")
    Return $groupID
}

Function Get-SupervidedTagID {

    Param([string]$organizationGroupID, [string]$airwatchServer, [object]$headers)

    Write-Verbose("------------------------------")
    Write-Verbose("Getting Supervised Tag")

    $endpointURL = $airwatchServer + "/api/mdm/tags/search?organizationgroupid=" + $organizationGroupID
    $webReturn = Invoke-RestMethod -Method Get -Uri $endpointURL -Headers $headers
    $supervisedTagExists = $false
    $supervisedTagID = -1
    Write-Verbose("Web Return: " + $webReturn.Total)
    If ([int]$webReturn.Total -gt 0) {
        foreach($currentTag in $webReturn.Tags) {
            if ($currentTag.TagName.ToLower() -eq "supervised") {
                $supervisedTagID = $currentTag.Id.Value
                $supervisedTagExists = $True
                Write-Verbose("Found supervised tag: " + $supervisedTagID)
            }
        }
    }

    If ($supervisedTagExists -ne $True) {
        # This REST API call is not working right now
        Write-Verbose("Supervised Tag Not Found")
    }

    Write-Verbose("------------------------------")
    Write-Verbose("")

    Return $supervisedTagID
}

<#
  This function is used to build the JSON to POST to build the Supervised tag if it doesn't exist.  This is not currently working
  as there is an issue with the Create Tag REST API.
#>
Function Get-SupervisedTagJSON {

    Param([int]$organizationGroupID)

	$quoteCharacter = [char]34
	$tagJSON = "{ " + $quoteCharacter + "TagAvatar" + $quoteCharacter + " : " + $quoteCharacter + $quoteCharacter + ", "
    $tagJSON = $tagJSON + $quoteCharacter + "TagName" + $quoteCharacter + " : " + $quoteCharacter + "Supervised" + $quoteCharacter + ", "
    $tagJSON = $tagJSON + $quoteCharacter + "TagType" + $quoteCharacter + " : " + "1" + ", "
    $tagJSON = $tagJSON + $quoteCharacter + "LocationGroupId" + $quoteCharacter + " : " + $organizationGroupID + ", "
    $tagJSON = $tagJSON + $quoteCharacter + "id" + $quoteCharacter + " : " + "1" + " }"
	
    Write-Verbose "------- JSON to Post---------"
    Write-Verbose $tagJSON
    Write-Verbose "-----------------------------"
    Write-Verbose ""
	Return $tagJSON
}

<#  This function builds the JSON to add the supervised tag to all of the devices that are in supervised mode. #>
Function Build-AddSupervisedTagJSON {

    Param([Array]$deviceList)

    Write-Verbose("------------------------------")
    Write-Verbose("Building JSON to Post")

    $arrayLength = $deviceList.Count
    $counter = 0
    $quoteCharacter = [char]34
    
    $addTagJSON = "{ " + $quoteCharacter + "BulkValues" + $quoteCharacter + " : { " + $quoteCharacter + "Value" + $quoteCharacter + " : [ "
    foreach ($currentDeviceID in $deviceList) {
        $deviceIDString = Out-String -InputObject $currentDeviceID
        $deviceIDString = $deviceIDString.Trim()

        $counter = $counter + 1
        if ($counter -lt $arrayLength) {
            $addTagJSON = $addTagJSON + $quoteCharacter + $deviceIDString + $quoteCharacter + ", "
        } else {
            $addTagJSON = $addTagJSON + $quoteCharacter + $deviceIDString + $quoteCharacter
        }
    }
    $addTagJSON = $addTagJSON + " ] } }"

    Write-Verbose($addTagJSON)
    Write-Verbose("------------------------------")
    Write-Verbose("")
    
    Return $addTagJSON
}

<# This is the actual start of the script.  All above functions are called from this point forward. #>
$concateUserInfo = $userName + ":" + $password
$deviceListURI = $baseURL + $bulkDeviceEndpoint
$restUserName = Get-BasicUserForAuth ($concateUserInfo)

<#
  Build the headers and send the request to the server.  The response is returned as a PSObject $webReturn, which is a collection
  of the devices.  Parse-DeviceObject gets all of the device properties.  This example also prints out the AirWatch device ID, 
  friendly name, and user name
#>
$useJSON = "application/json"
$headers = Build-Headers $restUserName $tenantAPIKey $useJSON $useJSON
$organizationGroupID = Get-OrganizationGroupID $organizationGroupName $airwatchServer $headers
$supervisedTagIid = Get-SupervidedTagID $organizationGroupID $airwatchServer $headers

<# 
    Get the tags collection and make sure there is a "Supervised" tag.  This function needs to be updated because I found
    an issue in the Create Tag API.
#>
$endpointURL = $airwatchServer + "/api/mdm/tags/search?organizationgroupid=" + $organizationGroupID
$webReturn = Invoke-RestMethod -Method Get -Uri $endpointURL -Headers $headers

#Build an array of all the devices that are supervised
$endpointURL = $airwatchServer + "/api/mdm/devices/search?platform=Apple"
$webReturn = Invoke-RestMethod -Method Get -Uri $endpointURL -Headers $headers
$supervisedDeviceIDs = New-Object System.Collections.ArrayList
foreach ($currentDevice in $webReturn.Devices) {
	If ($currentDevice.IsSupervised -eq $True) {
        $supervisedDeviceIDs.Add($currentDevice.Id.Value)
    }
}

$addTagJSON = Build-AddSupervisedTagJSON $supervisedDeviceIDs
$endpointURL = $airwatchServer + "/api/mdm/tags/" + $supervisedTagIid + "/adddevices"
$webReturn = Invoke-RestMethod -Method Post -Uri $endpointURL -Headers $headers -Body $addTagJSON

Write-Verbose("------------------------------")
Write-Verbose("Results of Add Tags Call")
Write-Verbose("Total Items: " +$webReturn.TotalItems)
Write-Verbose("Accepted Items: " + $webReturn.AcceptedItems)
Write-Verbose("Failed Items: " + $webReturn.FailedItems)
Write-Verbose("------------------------------")