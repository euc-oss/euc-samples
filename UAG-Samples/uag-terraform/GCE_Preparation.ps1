$jsonpayload = [Console]::In.ReadLine()
$json = ConvertFrom-Json $jsonpayload

$rootPwd=$json.rootPassword
$adminPwd=$json.adminPassword
$awAPIServerPwd=$json.awAPIServerPwd
$awTunnelGatewayAPIServerPwd=$json.awTunnelGatewayAPIServerPwd
$awCGAPIServerPwd=$json.awCGAPIServerPwd
$awSEGAPIServerPwd=$json.awSEGAPIServerPwd
$newAdminUserPwd=$json.newAdminUserPwd

$isTerraform="true"

function CreateNICOptions {
    Param ($settings, $nic, $description, $region)

    $nicOption = ''

    $subnet = $settings.GoogleCloud.("subnet" + $nic)
    $vpcHostProjectId = $settings.GoogleCloud.("vpcHostProjectId")
    $isSubnetOnSharedVpc=$settings.GoogleCloud.("sharedVpcForSubnet"+$nic)

    if ($subnet.length -eq 0) {
        $subnet="default"
    }
    if($vpcHostProjectId -gt 0 -and $isSubnetOnSharedVpc -eq $true) {
        $subnetSelfLink = gcloud compute networks subnets describe $subnet --region $region --project $vpcHostProjectId --verbosity error --format "value(selfLink)" 2>&1
        $nicOption += "subnet=$subnetSelfLink"
    }
    else {
        $nicOption += "subnet=$subnet"
    }


    $privateIP = $settings.GoogleCloud.("privateIPAddress" + $nic)
    if($privateIP.length -gt 0) {
        $nicOption += ",private-network-ip=$privateIP"
    }

    $publicIP = $settings.GoogleCloud.("publicIPAddress" + $nic)
    if($publicIP.length -gt 0) {
        if ($publicIP -eq "no-address") {
            $nicOption += ",no-address"
        } else {
            $nicOption += ",address=$publicIP"
        }
    }

    $nicOption = "--network-interface `"$nicOption`" "
    return $nicOption
}

function ValidateIPAddress {
    Param ($settings, $region, $type, $fieldName, $subnet, $isSubnetOnSharedVpc)

    $address = $settings.GoogleCloud.$fieldName
    if ($address.length -eq 0 -or ("EXTERNAL" -eq $type -and "no-address" -eq $address)) {
        return
    }

    Try {
        $ip = [IPAddress] "$address"
        # Accept only valid IPv4 address. GCE supports passing unreserved IP address also. So, accept any valid IPv4 values.
        if ($ip.AddressFamily -ne "InterNetwork") {
            WriteErrorString "Error: Invalid IP configured for [GoogleCloud] $fieldName. Provide valid IPv4 address."
            CleanExit
        }
    } Catch {

        # Parsing the address into IP failed. Name of reserved INTERNAL or EXTERNAL IP may have been provided. Verify if it is in valid state for use.

        if (isSubnetOnSharedVpc -eq $true){
            #check if subnet is on vpcHostProjectId or project id
            $projectId = $settings.GoogleCloud.vpcHostProjectId
        }
        else{
            $projectId = $settings.GoogleCloud.projectId
        }
        $reservedAddrJson = gcloud compute addresses describe $address --region $region --project $projectId --verbosity error --format json 2>&1

        if ("$reservedAddrJson".StartsWith("ERROR:")) {
            WriteErrorString "Error: Unable to validate [GoogleCloud] $fieldName value $address. $reservedAddrJson"
            CleanExit
        }
        else {
            $reservedAddress = $reservedAddrJson | ConvertFrom-Json
            if ($reservedAddress.addressType -ne $type) {
                WriteErrorString "Error: [GoogleCloud] $fieldName reserved address $address must be of type $type, but found $($reservedAddress.addressType)"
                CleanExit
            }
            if ($reservedAddress.status -eq "IN_USE") {
                $uagName = $settings.General.name
                # Do not fail if the address is in use by instance with same name, we are going to delete that anyways.
                if (!($reservedAddress.users.EndsWith($uagName))) {
                    WriteErrorString "Error: [GoogleCloud] $fieldName reserved address $address is already in use by other instance."
                    CleanExit
                }
            }
            if ($type -eq "INTERNAL") {
                if ($reservedAddress.purpose -ne "GCE_ENDPOINT") {
                    WriteErrorString "Error: [GoogleCloud] $fieldName internal reserved address $address must have purpose GCE_ENDPOINT, but found $($reservedAddress.purpose)"
                    CleanExit
                }
                if (!($reservedAddress.subnetwork.EndsWith($subnet))) {
                    $addrSubnet = $reservedAddress.subnetwork.Split('/')[-1]
                    WriteErrorString "Error: [GoogleCloud] $fieldName internal reserved address $address must be in subnet $subnet, but found $addrSubnet"
                    CleanExit
                }
            }
        }

    }
}

# Validates netowrk and subnet values, public and private static IPs when configured.
function ValidateNetworkSettings {
    Param ($settings, $nic, $region, $usedNetworks)
    # Validate subnet.
    $subnet = $settings.GoogleCloud.("subnet"+$nic)
    $vpcHostProjectId = $settings.GoogleCloud.("vpcHostProjectId")
    $isSubnetOnSharedVpc=$settings.GoogleCloud.("sharedVpcForSubnet"+$nic)
    $subnetProjectId=$settings.GoogleCloud.projectId
    if($subnet.length -eq 0) {
        $settings.GoogleCloud.("subnet"+$nic) = 'default'
        $subnet = 'default'
    }
    if($vpcHostProjectId -gt 0 -and $isSubnetOnSharedVpc -eq $true) {
        $subnetProjectId=$vpcHostProjectId
    }
    $gceSubnet = gcloud compute networks subnets describe $subnet --region $region --project $subnetProjectId --verbosity error --format "value(name)" 2>&1
    if($gceSubnet -ne $subnet) {
        WriteErrorString "Error: [GoogleCloud] subnet$nic $subnet not found in region $region. $gceSubnet"
        CleanExit
    }

    # Validate the current subnet is not in already used network.
    $network = gcloud compute networks subnets describe $subnet --region $region --project $subnetProjectId --verbosity error --format "value(selfLink)" 2>&1
    if ($usedNetworks -contains $network) {
        $networkName = "$network".Split("/")[-1] # $network will be URL of the VPC network. Split the URL and collect the name.
        WriteErrorString "Error: VPC Networks must not be the same for NICs attached to a VM. [GoogleCloud] subnet$nic can not use the subnet $subnet in the VPC $networkName. This VPC is already used for another NIC."
        CleanExit
    } else {
        [void]$usedNetworks.add($network)
    }

    $privateIPKey = "privateIPAddress"+$nic
    ValidateIPAddress $settings $region "INTERNAL" $privateIPKey $subnet $isSubnetOnSharedVpc

    $publicIPKey = "publicIPAddress"+$nic
    ValidateIPAddress $settings $region "EXTERNAL" $publicIPKey '' false
}


#======================================
# ++++++ EXECUTION STARTS HERE ++++++ #
#======================================

#
# Load the dependent PowerShell Module
#
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$uagDeployModule=$ScriptDir+"\uagdeploy.psm1"

if (!(Test-path $uagDeployModule)) {
    Exit
}

import-module $uagDeployModule -Force -ArgumentList $awAPIServerPwd, $awTunnelGatewayAPIServerPwd, $awCGAPIServerPwd, $awSEGAPIServerPwd
$iniFile=$json.inifile

if ($null -eq (Get-Command "gcloud" -ErrorAction SilentlyContinue))
{
    WriteErrorString "Error: Google Cloud SDK could not be found in the PATH. Install Google Cloud SDK and retry"
    Exit
}

if (!(Test-path $iniFile)) {
    WriteErrorString "Error: Configuration file $iniFile not found."
    Exit
}

$settings = ImportIni $iniFile

$uagName=$settings.General.name

if (!$uagName) {
    WriteErrorString "Error: [General] name not specified in the configuration file $iniFile"
    Exit
}

# Name must start with a lowercase letter. Max size 63 characters. Supports lowercase letters, numbers and hyphens. Cannot end with a hyphen.
if (!($uagName -match '(?-i)(^[a-z])([a-zA-Z\d-]{0,61})([a-zA-Z\d]$)')) {
    WriteErrorString "Error: [General] name ($uagName) is invalid. Name must start with a lowercase letter followed by up to 62 lowercase letters, numbers or hyphens and cannot end with a hyphen"
    Exit
}

$osLoginUsername = ReadOsLoginUsername $settings
if ($osLoginUsername.length -eq 0) {
    $osLoginUsername = "root"
}

if ($settings.General.dsComplianceOS -eq "true") {
    updatePasswordPolicyForDsComplianceOS $settings
}

if (!$ceipEnabled) {
    $ceipEnabled = "true"
}

$settingsJSON=GetJSONSettings $settings $newAdminUserPwd

$omnissaDir = SetUp
# Set this variable so that we can clear it in error scenario
Set-Variable -Name "ovfFile" -Value (Join-Path "$omnissaDir" "$uagName.cfg") -Scope global

$commandOptions = ' '

$deploymentOption=GetDeploymentSettingOption $settings


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

$adminMaxConcurrentSessions=ValidateAdminMaxConcurrentSessions $settings
if ($adminMaxConcurrentSessions.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("adminMaxConcurrentSessions="+"$adminMaxConcurrentSessions"))
}

if ($osLoginUsername -ne "root") {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("osLoginUsername="+"$osLoginUsername"))
}

$osMaxLoginLimit = ReadOsMaxLoginLimit $settings
if ($osMaxLoginLimit.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("osMaxLoginLimit="+"$osMaxLoginLimit"))
}

$rootSessionIdleTimeoutSeconds = ValidateRootSessionIdleTimeoutSeconds $settings
if ($rootSessionIdleTimeoutSeconds.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("rootSessionIdleTimeoutSeconds="+"$rootSessionIdleTimeoutSeconds"))
}

$enabledAdvancedFeatures=$settings.General.enabledAdvancedFeatures
if ($enabledAdvancedFeatures.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("enabledAdvancedFeatures="+"$enabledAdvancedFeatures"))
}

$gatewaySpec = getGatewaySpec $settings
if ($gatewaySpec.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("gatewaySpec="+"$gatewaySpec"))
}

$configURL=$settings.General.configURL
if ($configURL.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("configURL="+"$configURL"))
}

$configKey=$settings.General.configKey
if ($configKey.length -gt 0) {
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

$commandsFirstBoot = ValidateCustomBootTimeCommands $settings "commandsFirstBoot"
if ($commandsFirstBoot.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("commandsFirstBoot="+"$commandsFirstBoot"))
}
$commandsEveryBoot = ValidateCustomBootTimeCommands $settings "commandsEveryBoot"
if ($commandsEveryBoot.length -gt 0) {
    [IO.File]::AppendAllLines($ovfFile, [string[]]("commandsEveryBoot="+"$commandsEveryBoot"))
}

$gcpProjectId = $settings.GoogleCloud.projectId
if ($gcpProjectId.length -gt 0) {
    $projectId = gcloud projects describe $gcpProjectId --format "value(projectId)" 2>&1
    if($gcpProjectId -ne $projectId) {
        WriteErrorString "Error: [GoogleCloud] gcpProjectId ($gcpProjectId) not found. $projectId"
        CleanExit
    }
} else {
    $projectId = gcloud config list --format 'value(core.project)' 2>&1
    if([string]::IsNullOrEmpty($projectId)) {
        WriteErrorString "Error: No projectId found in the configuration file and gcloud SDK active configuration."
        CleanExit
    } else {
        $settings.GoogleCloud.projectId = $projectId
    }
}

$commandOptions += "--project=$projectId "

$gceImageName = $settings.GoogleCloud.imageName
$gceImageProject= $settings.GoogleCloud.imageProjectId
if ($gceImageProject.length -gt 0){
    $imgProjectId = gcloud projects describe $gceImageProject --format "value(projectId)" 2>&1
    if($gceImageProject -ne $imgProjectId) {
        WriteErrorString "Error: [GoogleCloud] Image Project ID ($gceImageProject) not found. $imgProjectId"
        CleanExit
    }

}
else{
    $gceImageProject=$projectId
}
if ($gceImageName.length -gt 0) {
    $imageName = gcloud compute images describe $gceImageName --project $gceImageProject --verbosity error --format "value(name)" 2>&1
    if($gceImageName -ne $imageName) {
        WriteErrorString "Error: [GoogleCloud] imageName ($gceImageName) not found. $imageName"
        CleanExit
    }
} else {
    WriteErrorString "Error: [GoogleCloud] imageName is not specified in the configuration file $iniFile"
    CleanExit
}

$commandOptions += "--image=$imageName "

if($projectId -ne $gceImageProject) {
    $commandOptions += "--image-project=$gceImageProject "
}


$gceZone = $settings.GoogleCloud.zone
if ($gceZone.length -gt 0) {
    $zone = gcloud compute zones describe $gceZone --project $projectId --verbosity error --format "value(name)" 2>&1
    if($gceZone -ne $zone) {
        WriteErrorString "Error: Configured [GoogleCloud] zone ($gceZone) not found. $zone"
        CleanExit
    }
} else {
    $zone = gcloud config list --format 'value(compute.zone)' 2>&1
    if([string]::IsNullOrEmpty($zone)) {
        WriteErrorString "Error: No compute zone configured, default compute zone is not set. $zone"
        CleanExit
    } else {
        $settings.GoogleCloud.zone = $zone
    }
}

$commandOptions += "--zone=$zone "

$gceMachineType = $settings.GoogleCloud.machineType
if ($gceMachineType.length -gt 0) {
    $machineType = gcloud compute machine-types describe $gceMachineType --zone $zone --verbosity error --format "value(name)" 2>&1
    if($gceMachineType -ne $machineType) {
        WriteErrorString "Error: [GoogleCloud] gceMachineType ($gceMachineType) is invalid. $machineType"
        CleanExit
    }
} else {
    $machineType = "e2-standard-4" # 4 CPU cores and 16GB memory.
}

$commandOptions += "--machine-type=$machineType "

$regionLink = gcloud compute zones describe $zone --project $projectId --verbosity error --format "value(region)" 2>&1
$region = "$regionLink".Split("/")[-1]

$labels = $settings.GoogleCloud.labels
if ($labels.length -gt 0) {
    $labels += ",name=$uagName"
} else {
    $labels = "name=$uagName"
}
$commandOptions += "--labels=`"$labels`" "

$tags = $settings.GoogleCloud.tags
if($tags.length -gt 0) {
    $tags += ",https-server"
} else {
    $tags = "https-server"
}
$commandOptions += "--tags=`"$tags`" "

$gceServiceAccount=$settings.GoogleCloud.serviceAccount
if ($gceServiceAccount.length -gt 0) {
    $commandOptions += "--service-account=`"$gceServiceAccount`" "
}

$usedNetworks = New-Object collections.arraylist
switch -Wildcard ($deploymentOption) {

    'onenic*' {
        ValidateNetworkSettings $settings "0" $region $usedNetworks
        $eth0 = CreateNICOptions $settings "0" "Internet, Management and Backend" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $commandOptions += $eth0
    }
    'twonic*' {
        ValidateNetworkSettings $settings "0" $region $usedNetworks
        ValidateNetworkSettings $settings "1" $region $usedNetworks
        $eth0 = CreateNICOptions $settings "0" "Internet" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNICOptions $settings "1" "Management and Backend" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
        $commandOptions += $eth0 + $eth1
    }
    'threenic*' {
        ValidateNetworkSettings $settings "0" $region $usedNetworks
        ValidateNetworkSettings $settings "1" $region $usedNetworks
        ValidateNetworkSettings $settings "2" $region $usedNetworks
        $eth0 = CreateNICOptions $settings "0" "Internet" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode0=DHCPV4+DHCPV6"))
        $eth1 = CreateNICOptions $settings "1" "Management" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode1=DHCPV4+DHCPV6"))
        $eth2 = CreateNICOptions $settings "2" "Backend" $region
        [IO.File]::AppendAllLines($ovfFile, [string[]]("ipMode2=DHCPV4+DHCPV6"))
        $commandOptions += $eth0 + $eth1 + $eth2
    }
    default {
        WriteErrorString "Error: Invalid deploymentOption ($deploymentOption)."
        CleanExit
    }
}


[IO.File]::AppendAllLines($ovfFile, [string[]]("settingsJSON="+"$settingsJSON"))
$ovfProperties = Get-Content -Raw $ovfFile
$userData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($ovfProperties))

$subnet0 = $settings.GoogleCloud.subnet0
$subnet1 = $settings.GoogleCloud.subnet1
$subnet2 = $settings.GoogleCloud.subnet2
$vpcHostProjectId = $settings.GoogleCloud.vpcHostProjectId
$sharedVpcForSubnet0 = $settings.GoogleCloud.sharedVpcForSubnet0
$sharedVpcForSubnet1 = $settings.GoogleCloud.sharedVpcForSubnet1
$sharedVpcForSubnet2 = $settings.GoogleCloud.sharedVpcForSubnet2
$privateIPAddress0 = $settings.GoogleCloud.privateIPAddress0
$privateIPAddress1 = $settings.GoogleCloud.privateIPAddress1
$privateIPAddress2 = $settings.GoogleCloud.privateIPAddress2
$publicIPAddress0 = $settings.GoogleCloud.publicIPAddress0
$publicIPAddress1 = $settings.GoogleCloud.publicIPAddress1
$publicIPAddress2 = $settings.GoogleCloud.publicIPAddress2


$result=@{}
$result["projectId"]=$projectId
$result["imageName"]=$gceImageName
$result["imageProjectId"]=$gceImageProject
$result["machineType"]=$machineType
$result["zone"]=$zone
$result["region"]=$region

$result["subnet0"]=$subnet0
$result["subnet1"]=$subnet1
$result["subnet2"]=$subnet2

$result["vpcHostProjectId"]=$vpcHostProjectId

$result["sharedVpcForSubnet0"]=$sharedVpcForSubnet0
$result["sharedVpcForSubnet1"]=$sharedVpcForSubnet1
$result["sharedVpcForSubnet2"]=$sharedVpcForSubnet2

$result["privateIPAddress0"]=$privateIPAddress0
$result["privateIPAddress1"]=$privateIPAddress1
$result["privateIPAddress2"]=$privateIPAddress2

$result["publicIPAddress0"]=$publicIPAddress0
$result["publicIPAddress1"]=$publicIPAddress1
$result["publicIPAddress2"]=$publicIPAddress2

$result["labels"]=$labels
$result["tags"]=$tags
$result["serviceAccount"]=$serviceAccount
$result["userData"]=$userData
$result | ConvertTo-Json -Compress