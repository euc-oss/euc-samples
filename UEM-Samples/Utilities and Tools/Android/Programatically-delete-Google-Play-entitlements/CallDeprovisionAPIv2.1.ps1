<#
.SYNOPSIS
    Android Enterprise public application entitlements are managed by Google. Once an app has been entitled for a user, it will remain entitled across all their devices. 
    In the case that this app is moved from Public management to Internal management, the public Entitlement will remain. 
    The user will still be able to see the app in Play Store > My Work Apps. 
    The user will also be prompted to update the app, and can update the app, if a new public version is released.

    An app may be moved to Internal management if the customer has a parnership with the app vendor, and receives custom APKs from them. 
    The internal app lifecycle management of the app can be bypassed due to the public entitlement still remaining.

    This use case is most widely seen on Kiosk type devices. As these devices have unique Google User IDs per device, 
    it is acceptable that the entitlement is deleted for all of the target user's devices
    
    This script programmatically deletes Google EMM Entitlements for all devices at a target WS1 Organization Group. 

.DESCRIPTION
    
    Pre-requisites before running the script:
    1) User must open this script and modify the SQL Server connection string information for Server\instance and Database
    2) User must modify parentlocationgroupid in the sqltext where device details are obtained
    3) User must have SQL account with remote access privileges
    4) Android Enterprise must be configured in the WS1 UEM Console
    5) Uncomment line 189 when ready to execute after testing (starts with $result - it is commented out for safety)

    More Info:
    1) The only required input parameter is for the applicatoin bundle id. This must be provided in the format com.application.bundle.id
    2) The Google Auth token has a time to live of 30 minutes, therefore should be "refreshed" prior to executing the script
    3) invoke-sqlcmd is not guaranteed to be available at all locations, so a custom SQL query function was used

    Google Auth Token refresh Steps
    1) Log in to WS1 Console with at least Console Administrator privileges
    2) Navigate to Apps & Books > Applications > Native > Public
    3) Click on "Add Application"
    4) Select "Android" from the platform drop down
    5) Choose the "Import from Play" option
    6) Click "Next" and wait for the following screen to load
    7) !!!!DO NOT CONTINUE PAST THIS SCREEN
    8) !!!!REALLY, DO NOT PRESS IMPORT
    9) Press "Cancel" or the "X" icon to exit without importing
    10) Token is now refreshed

.NOTES
    Author     : kimt@vmware.com
    Company    : VMware, Inc.
    Version    : 1.0.0

.PARAMETERS
    app        Bundle ID of the public application to delete entitlement for
#>

#Setup of input parameter for application bundle id
Param (
[string] $app
)

#Set cert trust so REST calls don't error
Add-Type @"
using System.Net; 
using System.Security.Cryptography.X509Certificates; 
public class TrustAllCertsPolicy : ICertificatePolicy { 
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certicateProblem) {
        return true;
    } 
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = new-object TrustAllCertsPolicy

#Prompt user for SQL auth credentials
$cred = get-credential

#Custom SQL function to replace invoke-sqlcmd
#This function takes SQL query, database name, and server name as inputs
function sql($sqlText, $database = "master", $server = ".")
{
    $uid = $cred.UserName
    $pwd = $cred.Password
    $pwd.MakeReadOnly()
    $sqlcred =  New-Object System.Data.SqlClient.SqlCredential($uid, $pwd)
    $connection = new-object System.Data.SqlClient.SQLConnection("Server=$server;Integrated Security=false;Database=$database");
    $connection.Credential = $sqlcred
    $cmd = new-object System.Data.SqlClient.SqlCommand($sqlText, $connection);
    
    $connection.Open();
    $reader = $cmd.ExecuteReader()

    $results = @()
    while ($reader.Read())
    {
        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++)
        {
            $row[$reader.GetName($i)] = $reader.GetValue($i)
        }
        $results += new-object psobject -property $row            
    }
    $connection.Close();

    $results
}

#Initialize location group variables
$customerOG = 570
$targetParentOG = 570

#Initialize SQL Connection String info
$sqlDatabase = "Workspace ONE UEM"
$sqlServer = "server\Instance"

#Form SQL query based on variables above
$sqlTextToken = "SELECT AccessToken from mobilemanagement.AndroidWorkSetting where locationgroupid = "+$customerOG
$sqlTextEID = "SELECT EnterpriseID from mobilemanagement.AndroidWorkSetting where locationgroupid = "+$customerOG
$sqlTextDevices = "select friendlyname, serialnumber, googleuserid, parentlocationgroupid
from dbo.devicegoogleidmap g inner join dbo.device d on g.deviceid = d.deviceid 
inner join dbo.locationgroupflat l on l.childlocationgroupid = d.locationgroupid
where parentlocationgroupid = "+$targetParentOG

#Call SQL function to obtain Access Token and Enterprise ID 
#Database and Server details must be modified for both calls
$token = sql -sqltext $sqlTextToken -database $sqlDatabase -server $sqlServer
$EnterpriseIDoutput =sql -sqltext $sqlTextEID -database $sqlDatabase -server $sqlServer
$EnterpriseID = $EnterpriseIDoutput.enterpriseid
write-host $EnterpriseID #Output just so user has visual indication of data
write-host $token #Output just so user has visual indication of data

#Pause for verification if needed 
start-sleep -s 1
write-output "Resuming in 5..."
start-sleep -s 1
write-output "4..."
start-sleep -s 1
write-output "3..."
start-sleep -s 1
write-output "2..."
start-sleep -s 1
write-output "1..."

#Setup API headers
$APIUrlBase = "https://www.googleapis.com/androidenterprise/v1/enterprises/"+$EnterpriseID+"/users/"
$APITestURL = "https://www.googleapis.com/androidenterprise/v1/enterprises/"+$EnterpriseID
$header = @{"Authorization" = "Bearer " + $token.AccessToken} 

#Test Google API to validate current OAuth token
Try{
    $testConnection = invoke-restmethod -uri $APITestURL -Headers $header -method Get
    write-host $testConnection
    }
Catch{
    $message = $_.exception.message
    write-host Test Connection failed: $message
    write-output "Please refresh the Google Auth Token"
    break
    }
Write-output "Test connection successful, continuing with deprovision"


#Call SQL function to obtain device serial number list
#Database and Server details must be modified
#Parentlocationgroupid must be modified (570 is the first Customer OG)
$sqlOutput = sql -sqltext $sqlTextDevices -database $sqlDatabase -server $sqlServer


#Initialize logging/reporting parameters
$count = 0
$ErrorCount = 0
$SuccessSerialNumbers = New-Object -TypeName "system.collections.arraylist"
$SuccessList = @{}
$FailSerialNumbers = new-object -TypeName "system.collections.arraylist"
$Faillist = @{}

<#
    For each line in the SQL output, call the Google Deprovision API
    Commented lines below are for testing prior to execution
    User should comment out the invoke-restmethod line for testing as well

    Failure reason 407 = Google Auth Token invalid
        30 minutes have passed since Token was issued

    Failure reason 404 = Entitlement does not exist
        User ID does not have entitlement for the given app bundle id
#>

foreach ($line in $sqlOutput) {
    Try{
        $error.clear()
        $ApiURL = $APIUrlBase+$line.googleuserid+"/entitlements/app:"+$app
        #throw "this is an error"
        #$Result = invoke-restmethod -uri $ApiURL -Headers $header -method Delete
        #write-host $Result
        #write-host $ApiURL
        write-host Successfully deprovisioned entitlement of $app for $line.serialnumber
        }
    Catch{
        $message = $_.Exception.Message
        write-host Deprovision failed for $line.serialnumber because of error $message
        continue
    }
    Finally{
        if (!$error){
            $Count++
            $SuccessList.SerialNumber = $line.serialnumber
            $successSerialNumbers.add((new-object PSObject -Property $SuccessList)) | out-null
        }
        else {
            $ErrorCount++
            $FailList.SerialNumber = $line.serialnumber
            $FailList.Reason = $message
            $FailSerialNumbers.add((new-object PSObject -Property @{Reason = $Faillist.Reason; SerialNumber = $FailList.SerialNumber})) | out-null
        }
    }
}

write-host Successfully deprovisioned $app for $count devices
write-host There were $ErrorCount failures
$SuccessSerialNumbers | export-csv "$app Success Report.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ','
$FailSerialNumbers | export-csv "$app Fail Report.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ','
