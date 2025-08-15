# Suppress warnings and errors from AWS PowerShell modules
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload

$isTerraform="true"

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$apDeployModule=$ScriptDir+"/uagdeploy.psm1"

if (!(Test-path $apDeployModule)) {
    WriteErrorString "Error: PowerShell Module $apDeployModule not found."

}

import-module $apDeployModule -Force -ArgumentList $awAPIServerPwd, $awTunnelGatewayAPIServerPwd, $awCGAPIServerPwd, $awSEGAPIServerPwd
$iniFile=$json.inifile

if (!(Test-path $iniFile)) {
    WriteErrorString "Error: Configuration file ($iniFile) not found."

}

$settings = ImportIni $iniFile
$output=""

#EC2 Settings
$ipv6AddressCount0 = $settings.AmazonEC2.ipv6AddressCount0
$ipv6AddressCount1 = $settings.AmazonEC2.ipv6AddressCount1
$ipv6AddressCount2 = $settings.AmazonEC2.ipv6AddressCount2

$privateIPAddress0 = $settings.AmazonEC2.privateIPAddress0
$privateIPAddress1 = $settings.AmazonEC2.privateIPAddress1
$privateIPAddress2 = $settings.AmazonEC2.privateIPAddress2

$publicIPId0 = $settings.AmazonEC2.publicIPId0
$publicIPId1 = $settings.AmazonEC2.publicIPId1
$publicIPId2 = $settings.AmazonEC2.publicIPId2

$securityGroupId0 = $settings.AmazonEC2.securityGroupId0
$securityGroupId1 = $settings.AmazonEC2.securityGroupId1
$securityGroupId2 = $settings.AmazonEC2.securityGroupId2

$subnetId0 = $settings.AmazonEC2.subnetId0
$subnetId1 = $settings.AmazonEC2.subnetId1
$subnetId2 = $settings.AmazonEC2.subnetId2

$instanceType = $settings.AmazonEC2.instanceType
$AMIId = $settings.AmazonEC2.amiId

if ($AMIId.length -eq 0)
{

    ##################### Upload vmdk file to S3 #######################


    $vmdkImagePath = $settings.AmazonEC2.vmdkImagePath
    $vmdkImage = $settings.AmazonEC2.vmdkImage
    $profileName = $settings.AmazonEC2.credentialProfileName

    if (($vmdkImagePath.length -eq 0) -or ($vmdkImage.length -eq 0) -or ($profileName.length -eq 0)) {
        Write-Error "Error: AMI can not be generated"
        Exit 1
    }

    Set-AWSCredential -ProfileName $profileName

    $bucket = "uag-images-1"

    $filter = @{
        Name = 'name'
        Values = $vmdkImage
    }

    #$output += "Verifying if AMI corresponding to the vmdk image $vmdkImage is already present`n"
    $AMIId = (Get-EC2Image -Filter $filter).ImageId
    if ( [string]::IsNullOrEmpty($AMIId))
    {
        $params = @{
            "BucketName" = $bucket
            "File" = $vmdkImagePath
            "key" = "/" + $vmdkImage
        }


        if ((Get-S3Object -BucketName $bucket | where{ $_.Key -like "$vmdkImage" }))
        {
            $output += "File  $vmdkImage is already present in S3`n"
        }
        else
        {
            $output += "Uploading to S3`n"
            Write-S3Object @params
            $output += "Upload to S3 is successful`n"
        }

        ##################### Import EC2 Snapshot ########################

        $params = @{
            "DiskContainer_Format" = "VMDK"
            "DiskContainer_S3Bucket" = $bucket
            "DiskContainer_S3Key" = $vmdkImage
        }

        $impId = Import-EC2Snapshot @params

        #write-Host "SnapshotTaskDetail:"
        $Detail = (Get-EC2ImportSnapshotTask -ImportTaskId $impId.ImportTaskId).SnapshotTaskDetail

        $Status = (Get-EC2ImportSnapshotTask -ImportTaskId $impId.ImportTaskId).SnapshotTaskDetail.Status
        if ($Status -ne "completed")
        {
            $wait = 0
            #Write-Host "Waiting for snapshotId.. "
            while ($Status -ne "completed")
            {
                #Write-Host -NoNewline "."
                if ($wait -ge 300)
                {
                    # If its been more than 5 minutes, and SnapshotId is not retrieved
                    #write-Host ". Failed"
                    Write-Error "Failed to retrieve SnapshotId"
                    Exit 1
                }
                # Wait until deployment successful
                $wait++
                Start-Sleep -Seconds 120
                $Status = (Get-EC2ImportSnapshotTask -ImportTaskId $impId.ImportTaskId).SnapshotTaskDetail.Status
                $StatusMessage = (Get-EC2ImportSnapshotTask -ImportTaskId $impId.ImportTaskId).SnapshotTaskDetail.StatusMessage
                $output += "StatusMessage:$StatusMessage`n"
            }
        }
        $SnapshotId = (Get-EC2ImportSnapshotTask -ImportTaskId $impId.ImportTaskId).SnapshotTaskDetail.SnapshotId
        $output += "SnapshotId = $SnapshotId`n"

        ##################### Register the Image as an Amazon Machine Image (AMI) ####################
        $bdm = New-Object Amazon.EC2.Model.BlockDeviceMapping
        $bd = New-Object Amazon.EC2.Model.EbsBlockDevice
        $bd.SnapshotId = $SnapshotId
        $bd.DeleteOnTermination = $true
        $bdm.DeviceName = "/dev/sda1"
        $bdm.Ebs = $bd

        $params = @{
            "BlockDeviceMapping" = $bdm
            "RootDeviceName" = "/dev/sda1"
            "Name" = $vmdkImage
            "Architecture" = "x86_64"
            "VirtualizationType" = "hvm"
        }
        $AMIId = Register-EC2Image @params
    }
}
$output += "AMI id is %$AMIId%`n"


######################################################################################################################################

function CreateNIC {
    Param ($settings, $nic, $description)

    $privateIPAddress = $settings.AmazonEC2.("privateIPAddress"+$nic)

    $ipv6AddressCount = $settings.AmazonEC2.("ipv6AddressCount"+$nic)
    $subnetId = $settings.AmazonEC2.("subnetId"+$nic)
    $securityGroupId =  $settings.AmazonEC2.("securityGroupId"+$nic)
    $newnic = "New-EC2NetworkInterface -SubnetId $subnetId -Group $securityGroupId"
    if($privateIPAddress.Length -gt 0) {
        $newnic = "$newnic -PrivateIPAddress $privateIPAddress"
    }
    if($ipv6AddressCount.Length -gt 0) {
        $newnic = "$newnic -Ipv6AddressCount $ipv6AddressCount"
    }
    $newnic = Invoke-Expression $newnic

    If([string]::IsNullOrEmpty($newnic)) {
        $msg = $error[0]
        WriteErrorString "Error: Failed to create NIC$nic - $msg"
        Exit
    }

    New-EC2Tag -Region $awsRegion -Tag @( @{ Key = "Name" ; Value = "$apName-eth$nic"}) -Resource $newnic.NetworkInterfaceId -Force

    $e = Edit-EC2NetworkInterfaceAttribute -NetworkInterfaceId $newnic.NetworkInterfaceId -Description "$apName-eth$nic ($description)"

    if ($settings.AmazonEC2.("publicIPId"+$nic).length -gt 0) {
        $r = Register-EC2Address -AllocationId $settings.AmazonEC2.("publicIPId"+$nic) -NetworkInterfaceId $newnic.NetworkInterfaceId
        If([string]::IsNullOrEmpty($r)) {
            $msg = $error[0]
            WriteErrorString "Error: Failed to register address - $msg"
            Exit
        }
    }

    $eth = new-object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification
    $eth.NetworkInterfaceId = $newnic.NetworkInterfaceId
    $eth.DeviceIndex = $nic
    $eth.DeleteOnTermination = $false

    $eth
}


function ValidateNetworkSettings {
    Param ($settings, $nic)

    $subnetID = $settings.AmazonEC2.("subnetId"+$nic)

    if ($subnetID.length -gt 0) {

        $subnet = Get-EC2Subnet -SubnetId $subnetID
        If([string]::IsNullOrEmpty($subnet)) {
            $msg = $error[0]
            WriteErrorString "Error: [AmazonEC2] subnetID$nic ($subnetID) not found"
        }
    } else {
        WriteErrorString "Error: [AmazonEC2] subnetID$nic not specified"
    }

    $publicIPId = $settings.AmazonEC2.("publicIPId"+$nic)

    if ($publicIPId.length -gt 0) {

        $ipObj = Get-EC2Address -AllocationId $publicIPId

        If([string]::IsNullOrEmpty($ipObj)) {
            WriteErrorString "Error: [AmazonEC2] publicIPId$nic ($publicIPId) not found"
        }

        $publicIP = $ipObj.PublicIp

        if ($ipObj.InstanceId.length -gt 0) {
            WriteErrorString "Error: [AmazonEC2] publicIPId$nic ($publicIPId - $publicIP) is already in use by another instance"
        }
    }

    $securityGroupId = $settings.AmazonEC2.("securityGroupId"+$nic)

    if ($securityGroupId.length -gt 0) {
        $sg = Get-EC2SecurityGroup -GroupId $securityGroupId
        If([string]::IsNullOrEmpty($sg)) {
            WriteErrorString "Error: [AmazonEC2] securityGroupId$nic ($securityGroupId) not found"
        }

        if ($sg.VpcId -ne $subnet.VpcId) {
            WriteErrorString "Error: [AmazonEC2] securityGroupId$nic ($securityGroupId) is not in the same VPC as the specified subnet"
        }
    }
}





$uagSettings = @{}
$rootPwd=$json.rootPassword
$adminPwd=$json.adminPassword
$awAPIServerPwd=$json.awAPIServerPwd
$awTunnelGatewayAPIServerPwd=$json.awTunnelGatewayAPIServerPwd
$awCGAPIServerPwd=$json.awCGAPIServerPwd
$awSEGAPIServerPwd=$json.awSEGAPIServerPwd
$newAdminUserPwd=$json.newAdminUserPwd

$apName=$settings.General.name
$ceipEnabled=$settings.General.ceipEnabled

$deploymentOption=GetDeploymentSettingOption $settings

$awsRegion = $settings.AmazonEC2.region
if ($awsRegion.length -gt 0) {
    $region = Get-EC2Region -Region $awsRegion
    If([string]::IsNullOrEmpty($region)) {
        WriteErrorString "Error: [AmazonEC2] region ($awsRegion) not found"
        $regions = Get-EC2Region
        $regionNames = $regions.RegionName
        WriteErrorString "Specify a region from the following list - $regionNames"
        Exit
    }
    Set-DefaultAWSRegion $awsRegion
} else {
    WriteErrorString "Error: [AmazonEC2] region not specified"
    Exit
}

$credentialProfileName = $settings.AmazonEC2.credentialProfileName

if ($credentialProfileName.length -gt 0) {
    $cred = Get-AWSCredential -ProfileName $credentialProfileName
    If([string]::IsNullOrEmpty($cred)) {
        WriteErrorString "Error: [AmazonEC2] credentialProfileName ($credentialProfileName) not found. To set a named credential profile, run the command:"
        WriteErrorString "Set-AWSCredential -AccessKey <accesskey> -SecretKey <secretkey> -StoreAs $credentialProfileName"
        Exit
    }
    $subNets = get-ec2subnet -ProfileName $credentialProfileName
    If([string]::IsNullOrEmpty($subNets)) {
        WriteErrorString "Error: [AmazonEC2] credentialProfileName ($credentialProfileName) is invalid. To set a named credential profile, run the command:"
        WriteErrorString "Set-AWSCredential -AccessKey <accesskey> -SecretKey <secretkey> -StoreAs $credentialProfileName"
        Exit
    }
} else {
    $credentialProfileName = "default"
    $subNets = get-ec2subnet -ProfileName $credentialProfileName
    If([string]::IsNullOrEmpty($subNets)) {
        WriteErrorString "Error: Default credential profile is not set or is invalid. To set a default credential profile, run the command:"
        WriteErrorString "Set-AWSCredential -AccessKey <accesskey> -SecretKey <secretkey> -StoreAs default"
        Exit
    }
}

Initialize-AWSDefaultConfiguration -ProfileName $credentialProfileName -Region $awsRegion

$omnissaDir = SetUp
# Set this variable so that we can clear it in error scenario
Set-Variable -Name "ovfFile" -Value (Join-Path "$omnissaDir" "$apName.cfg") -Scope global

switch -Wildcard ($deploymentOption) {

    'onenic*' {
        ValidateNetworkSettings $settings "0"
        $eth0 = CreateNIC $settings "0" "Internet, Management and Backend"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $NetworkInterfaces = $eth0
        $customConfigEntry0 = GetCustomConfigEntry $settings "0"
        if ($customConfigEntry0.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry0))
        }
    }
    'twonic*' {
        ValidateNetworkSettings $settings "0"
        ValidateNetworkSettings $settings "1"
        $eth0 = CreateNIC $settings "0" "Internet"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNIC $settings "1" "Management and Backend"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
        $NetworkInterfaces = $eth0,$eth1
        $customConfigEntry0 = GetCustomConfigEntry $settings "0"
        if ($customConfigEntry0.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry0))
        }
        $customConfigEntry1 = GetCustomConfigEntry $settings "1"
        if ($customConfigEntry1.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry1))
        }
    }
    'threenic*' {
        ValidateNetworkSettings $settings "0"
        ValidateNetworkSettings $settings "1"
        ValidateNetworkSettings $settings "2"
        $eth0 = CreateNIC $settings "0" "Internet"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNIC $settings "1" "Management"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
        $eth2 = CreateNIC $settings "2" "Backend"
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode2=DHCPV4+DHCPV6"))
        $NetworkInterfaces = $eth0,$eth1,$eth2
        $customConfigEntry0 = GetCustomConfigEntry $settings "0"
        if ($customConfigEntry0.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry0))
        }
        $customConfigEntry1 = GetCustomConfigEntry $settings "1"
        if ($customConfigEntry1.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry1))
        }
        $customConfigEntry2 = GetCustomConfigEntry $settings "2"
        if ($customConfigEntry2.length -gt 0) {
            [IO.File]::AppendAllLines($ovfFile, [string[]]($customConfigEntry2))
        }
    }
    default {
        WriteErrorString "Error: Invalid deploymentOption ($deploymentOption)."
        Exit
    }
}

if ($apName.length -gt 32) {
    WriteErrorString "Error: Virtual machine name must be no more than 32 characters in length"
}

if (!$apName) {
    $apName = GetAPName
}

$osLoginUsername = ReadOsLoginUsername $settings
if ($osLoginUsername.length -eq 0) {
    $osLoginUsername = "root"
}

if ($settings.General.dsComplianceOS -eq "true") {
    updatePasswordPolicyForDsComplianceOS $settings
}

$warningMessage="";

if (!$rootPwd) {
    $warningMessage += "ROOT PASSWORD NOT PROVIDED: RANDOM PASSWORD WILL BE SET `n"

}

if (!$adminPwd) {
    $warningMessage += "THE ADMIN PASSWORD HAS NOT BEEN PROVIDED: AN ADMIN UI USER WILL NOT BE CREATED, AND YOU WILL NOT BE ABLE TO CONFIGURE ANY SETTINGS ON THE APPLIANCE. YOU WILL HAVE TO REDEPLOY THE UAG APPLIANCE WITH A PASSWORD TO USE THE ADMIN UI `n"

}

if (!$ceipEnabled) {
    $warningMessage += "Customer Experience Improvement Program Enabled "
    $ceipEnabled="True"
}

$settingsJSON=GetJSONSettings $settings $newAdminUserPwd

[IO.File]::WriteAllLines($ovfFile, [string[]]("deploymentOption="+"$deploymentOption"))

$dns=$settings.General.dns
if ($dns.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("DNS="+"$dns"))
}

$defaultGateway=$settings.General.defaultGateway
if ($defaultGateway.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("defaultGateway="+"$defaultGateway"))
}

$v6DefaultGateway=$settings.General.v6DefaultGateway
if ($v6defaultGateway.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("v6defaultGateway="+"$v6defaultGateway"))
}

$forwardrules=$settings.General.forwardrules
if ($forwardrules.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("forwardrules="+"$forwardrules"))
}

$routes0=$settings.General.routes0
if ($routes0.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes0="+"$routes0"))
}

$routes1=$settings.General.routes1
if ($routes1.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes1="+"$routes1"))
}

$routes2=$settings.General.routes2
if ($routes2.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("routes2="+"$routes2"))
}

$policyRouteGateway0=$settings.General.policyRouteGateway0
if ($policyRouteGateway0.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("policyRouteGateway0="+"$policyRouteGateway0"))
}

$policyRouteGateway1=$settings.General.policyRouteGateway1
if ($policyRouteGateway1.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("policyRouteGateway1="+"$policyRouteGateway1"))
}

$policyRouteGateway2=$settings.General.policyRouteGateway2
if ($policyRouteGateway2.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("policyRouteGateway2="+"$policyRouteGateway2"))
}

if ($osLoginUsername.length -ne "root") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("osLoginUsername="+"$osLoginUsername"))
}

$osMaxLoginLimit = ReadOsMaxLoginLimit $settings
if ($osMaxLoginLimit.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("osMaxLoginLimit="+"$osMaxLoginLimit"))
}

$rootPasswordExpirationDays=$settings.General.rootPasswordExpirationDays
if ($rootPasswordExpirationDays.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("rootPasswordExpirationDays="+"$rootPasswordExpirationDays"))
}

$passwordPolicyMinLen=$settings.General.passwordPolicyMinLen
if ($passwordPolicyMinLen.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("passwordPolicyMinLen="+"$passwordPolicyMinLen"))
}

$passwordPolicyMinClass=$settings.General.passwordPolicyMinClass
if ($passwordPolicyMinClass.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("passwordPolicyMinClass="+"$passwordPolicyMinClass"))
}

$passwordPolicyDifok=$settings.General.passwordPolicyDifok
if ($passwordPolicyDifok.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("passwordPolicyDifok="+"$passwordPolicyDifok"))
}

$passwordPolicyUnlockTime=$settings.General.passwordPolicyUnlockTime
if ($passwordPolicyUnlockTime.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("passwordPolicyUnlockTime="+"$passwordPolicyUnlockTime"))
}

$passwordPolicyFailedLockout=$settings.General.passwordPolicyFailedLockout
if ($passwordPolicyFailedLockout.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("passwordPolicyFailedLockout="+"$passwordPolicyFailedLockout"))
}

$adminPasswordFailedLockoutCount=$settings.General.adminPasswordPolicyFailedLockoutCount
if ($adminPasswordFailedLockoutCount.length -gt 0){
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminPasswordPolicyFailedLockoutCount="+"$adminPasswordFailedLockoutCount"))
}

$adminPasswordMinLen=$settings.General.adminPasswordPolicyMinLen
if ($adminPasswordMinLen.length -gt 0){
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminPasswordPolicyMinLen="+"$adminPasswordMinLen"))
}

$adminPasswordLockoutTime=$settings.General.adminPasswordPolicyUnlockTime
if ($adminPasswordLockoutTime.length -gt 0){
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminPasswordPolicyUnlockTime="+"$adminPasswordLockoutTime"))
}

$adminSessionIdleTimeoutMinutes=$settings.General.adminSessionIdleTimeoutMinutes
if ($adminSessionIdleTimeoutMinutes.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminSessionIdleTimeoutMinutes="+"$adminSessionIdleTimeoutMinutes"))
}

$adminMaxConcurrentSessions = ValidateAdminMaxConcurrentSessions $settings
if ($adminMaxConcurrentSessions.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminMaxConcurrentSessions="+"$adminMaxConcurrentSessions"))
}

$rootSessionIdleTimeoutSeconds = ValidateRootSessionIdleTimeoutSeconds $settings
if ($rootSessionIdleTimeoutSeconds.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("rootSessionIdleTimeoutSeconds="+"$rootSessionIdleTimeoutSeconds"))
}

if ($ceipEnabled -eq $true) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("ceipEnabled=true"))
}

if ($settings.General.dsComplianceOS -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("dsComplianceOS=true"))
}

if ($settings.General.tlsPortSharingEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("tlsPortSharingEnabled=true"))
}

if ($settings.General.sshEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshEnabled=true"))
}

if ($settings.General.sshPasswordAccessEnabled -eq "false") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshPasswordAccessEnabled=false"))
}

if ($settings.General.sshKeyAccessEnabled -eq "true") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshKeyAccessEnabled=true"))
}

$sshBannerText=ReadLoginBannerText $settings
if ($sshBannerText.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshLoginBannerText=" + "$sshBannerText"))
}

$sshInterface = validateSSHInterface $settings
if (($sshInterface.length -gt 0)) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshInterface=" + "$sshInterface"))
}

$sshPort = $settings.General.sshPort
if ($sshPort.length -gt 0 -and ($sshPort -match '^[0-9]+$')) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("sshPort=" + "$sshPort"))
}

$secureRandomSrc=ReadSecureRandomSource $settings
if ($secureRandomSrc.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("secureRandomSource=" + "$secureRandomSrc"))
}

[IO.File]::AppendAllLines($ovfFile, [string[]]("rootPassword="+"$rootPwd"))

if ($adminPwd.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminPassword="+"$adminPwd"))
}

$enabledAdvancedFeatures=$settings.General.enabledAdvancedFeatures
if ($enabledAdvancedFeatures.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("enabledAdvancedFeatures="+"$enabledAdvancedFeatures"))
}

$gatewaySpec = getGatewaySpec $settings
if ($gatewaySpec.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("gatewaySpec="+"$gatewaySpec"))
}

$commandsFirstBoot = ValidateCustomBootTimeCommands $settings "commandsFirstBoot"
if ($commandsFirstBoot.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("commandsFirstBoot="+"$commandsFirstBoot"))
}
$commandsEveryBoot = ValidateCustomBootTimeCommands $settings "commandsEveryBoot"
if ($commandsEveryBoot.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("commandsEveryBoot="+"$commandsEveryBoot"))
}

$configURL=$settings.General.configURL
if ($configURL.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("configURL="+"$configURL"))
}

$configKey=$settings.General.configKey
if ($configURL.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("configKey="+"$configKey"))
}

$configURLThumbprints=$settings.General.configURLThumbprints
if ($configURLThumbprints.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("configURLThumbprints="+"$configURLThumbprints"))
}

$configURLHttpProxy=$settings.General.configURLHttpProxy
if ($configURLHttpProxy.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("configURLHttpProxy="+"$configURLHttpProxy"))
}

$adminCsrSubject=$settings.General.adminCsrSubject
if ($adminCsrSubject.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminCsrSubject="+"$adminCsrSubject"))
}

$adminCsrSAN=$settings.General.adminCsrSAN
if ($adminCsrSAN.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminCsrSAN="+"$adminCsrSAN"))
}

$additionalDeploymentMetadata = $settings.General.additionalDeploymentMetadata
if($additionalDeploymentMetadata.length -gt 0){
    [IO.File]::AppendAllLines($ovfFile, [string[]]("additionalDeploymentMetadata="+"$additionalDeploymentMetadata"))
}


[IO.File]::AppendAllLines($ovfFile, [string[]]("settingsJSON="+"$settingsJSON"))

$ovfProperties = Get-Content -Raw $ovfFile

$UserData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($ovfProperties))
[IO.File]::Delete($ovfFile)

$output += $ovfProperties
$result=@{}
$result["amiID"]=$AMIId
$result["output"]=$output
$result["userData"]=$UserData
$result["warningMessage"]=$warningMessage

$result["ipv6AddressCount0"]=$ipv6AddressCount0
$result["ipv6AddressCount1"]=$ipv6AddressCount1
$result["ipv6AddressCount2"]=$ipv6AddressCount2

$result["privateIPAddress0"]=$privateIPAddress0
$result["privateIPAddress1"]=$privateIPAddress1
$result["privateIPAddress2"]=$privateIPAddress2

$result["publicIPId0"]=$publicIPId0
$result["publicIPId1"]=$publicIPId1
$result["publicIPId2"]=$publicIPId2

$result["securityGroupId0"]=$securityGroupId0
$result["securityGroupId1"]=$securityGroupId1
$result["securityGroupId2"]=$securityGroupId2

$result["subnetId0"]=$subnetId0
$result["subnetId1"]=$subnetId1
$result["subnetId2"]=$subnetId2

$result["instanceType"]=$instanceType
$result | ConvertTo-Json -Compress


