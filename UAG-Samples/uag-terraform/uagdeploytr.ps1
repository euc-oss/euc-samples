#
# Load the dependent PowerShell Module
#

$uagSettings = @{}
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
$uagSettings["datacenter"]=$settings.vSphere.datacenter
$uagSettings["datastore"]=$settings.vSphere.datastore
$uagSettings["pool"]=$settings.vSphere.pool
$uagSettings["cluster"]=$settings.Vsphere.cluster
$uagSettings["network0"]=$settings.vSphere.network0
$uagSettings["network1"]=$settings.vSphere.network1
$uagSettings["network2"]=$settings.vSphere.network2
$uagSettings["host"]=$settings.vSphere.host
$uagSettings["ovf_source"]=$settings.vSphere.ovf_source
$uagSettings["ovf_path"]=$settings.vSphere.ovf_path
$uagSettings["uagSize"]=$settings.vSphere.uagSize
$uagSettings["allow_unverified_ssl_cert"]=$settings.vSphere.allow_unverified_ssl_cert

$apName=$settings.General.name
$ceipEnabled=$settings.General.ceipEnabled

$ds=$settings.General.ds

$diskMode=$settings.General.diskMode

#
# Assign and validate network settings
#

$dns=$settings.General.dns
$defaultGateway=$settings.General.defaultGateway
$v6DefaultGateway=$settings.General.v6DefaultGateway
$forwardrules=$settings.General.forwardrules
$netInternet=$settings.General.netInternet
$ip0=$settings.General.ip0
$routes0=$settings.General.routes0
$policyRouteGateway0=$settings.General.policyRouteGateway0
$netmask0=$settings.General.netmask0

$netManagementNetwork=$settings.General.netManagementNetwork
$ip1=$settings.General.ip1
$routes1=$settings.General.routes1
$policyRouteGateway1=$settings.General.policyRouteGateway1
$netmask1=$settings.General.netmask1

$netBackendNetwork=$settings.General.netBackendNetwork
$ip2=$settings.General.ip2
$routes2=$settings.General.routes2
$policyRouteGateway2=$settings.General.policyRouteGateway2
$netmask2=$settings.General.netmask2
$rootPasswordExpirationDays=$settings.General.rootPasswordExpirationDays
$passwordPolicyMinLen=$settings.General.passwordPolicyMinLen
$passwordPolicyMinClass=$settings.General.passwordPolicyMinClass
$passwordPolicyDifok=$settings.General.passwordPolicyDifok
$passwordPolicyUnlockTime=$settings.General.passwordPolicyUnlockTime
$passwordPolicyFailedLockout=$settings.General.passwordPolicyFailedLockout
$enabledAdvancedFeatures=$settings.General.enabledAdvancedFeatures
$adminPasswordMinLen=$settings.General.adminPasswordPolicyMinLen
$adminPasswordLockoutTime=$settings.General.adminPasswordPolicyUnlockTime
$adminPasswordFailedLockoutCount=$settings.General.adminPasswordPolicyFailedLockoutCount
$adminSessionIdleTimeoutMinutes=$settings.General.adminSessionIdleTimeoutMinutes
$configURL = $settings.General.configURL
$configKey = $settings.General.configKey
$configURLThumbprints = $settings.General.configURLThumbprints
$configURLHttpProxy = $settings.General.configURLHttpProxy
$adminCsrSubject = $settings.General.adminCsrSubject
$adminCsrSAN = $settings.General.adminCsrSAN
$additionalDeploymentMetadata = $settings.General.additionalDeploymentMetadata


if ((!$ip0) -And (!$ip1) -And (!$ip2)) {

	#
	# No IP addresses specified so we will use DHCP for address allocation
	#

	$ipAllocationPolicy = "dhcpPolicy"

} else {

	$ipAllocationPolicy = "fixedPolicy"

}

$deploymentOption=GetDeploymentSettingOption $settings

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

$uagSettings["warning"]=$warningMessage

 $settingsJSON=GetJSONSettings $settings $newAdminUserPwd

#
# idp-metadata settings
#
# $idpMetadata = "\'idp-metadata\': {}"

 $jsonString=GetSettingsJSONProperty $settingsJSON

$uagSettings["settings"]=$settingsJSON
$uagSettings["settingsJSON"]=$jsonString

$uagSettings["rootPassword"]=$rootPwd

$uagSettings["osLoginUsername"]=$osLoginUsername

$osMaxLoginLimit = ReadOsMaxLoginLimit $settings
$uagSettings["osMaxLoginLimit"]=$osMaxLoginLimit

$uagSettings["adminPassword"]=$adminPwd

switch -Wildcard ($deploymentOption) {

	'onenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
        $mask_length0 = GetMaskLength $settings "0"
    }
	'twonic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
        $mask_length0 = GetMaskLength $settings "0"

        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += "$netOptions1"
        $mask_length1 = GetMaskLength $settings "1"
    }
	'threenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
        $mask_length0 = GetMaskLength $settings "0"

        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += "$netOptions1"
        $mask_length1 = GetMaskLength $settings "1"

        $netOptions2 = GetNetOptions $settings "2"
        $ovfOptions += "$netOptions2"
        $mask_length2 = GetMaskLength $settings "2"
    }
}

$uagSettings["ip0"]=$ip0
$uagSettings["netmask0"]=$netmask0
$uagSettings["maskLength0"]=$mask_length0.ToString()
$uagSettings["cidr0"]="$ip0/$mask_length0"
$ipMode0=$settings.General.$ipMode0
$uagSettings["ipMode0"]=$ipMode0

$uagSettings["ip1"]=$ip1
$uagSettings["netmask1"]=$netmask1
$uagSettings["maskLength1"]=$mask_length1.ToString()
$uagSettings["cidr1"]="$ip1/$mask_length1"
$ipMode0=$settings.General.$ipMode1
$uagSettings["ipMode1"]=$ipMode1

$uagSettings["ip2"]=$ip2
$uagSettings["netmask2"]=$netmask2
$uagSettings["maskLength2"]=$mask_length2.ToString()
$uagSettings["cidr2"]="$ip2/$mask_length2"
$ipMode0=$settings.General.$ipMode2
$uagSettings["ipMode2"]=$ipMode2

$uagSettings["ipAllocationPolicy"]=$ipAllocationPolicy
$uagSettings["deploymentOption"]=$deploymentOption

$uagSettings["DNS"]=$dns

$uagSettings["rootPasswordExpirationDays"]=$rootPasswordExpirationDays

$uagSettings["passwordPolicyMinLen"]=$passwordPolicyMinClass

$uagSettings["passwordPolicyMinClass"]=$passwordPolicyMinClass

$uagSettings["passwordPolicyDifok"]=$passwordPolicyDifok

$uagSettings["passwordPolicyUnlockTime"]=$passwordPolicyUnlockTime

$uagSettings["passwordPolicyFailedLockout"]=$passwordPolicyFailedLockout

#Admin Password policy settings

$uagSettings["adminPasswordPolicyFailedLockoutCount"]=$adminPasswordPolicyFailedLockoutCount

$uagSettings["adminPasswordPolicyMinLen"]=$adminPasswordMinLen

$uagSettings["adminPasswordPolicyUnlockTime"]=$adminPasswordLockoutTime

$uagSettings["adminSessionIdleTimeoutMinutes"]=$adminSessionIdleTimeoutMinutes

$adminMaxConcurrentSessions = ValidateAdminMaxConcurrentSessions $settings
$uagSettings["adminMaxConcurrentSessions"]=$adminMaxConcurrentSessions

$rootSessionIdleTimeoutSeconds = ValidateRootSessionIdleTimeoutSeconds $settings
$uagSettings["rootSessionIdleTimeoutSeconds"]=$rootSessionIdleTimeoutSeconds

$commandsFirstBoot = ValidateCustomBootTimeCommands $settings "commandsFirstBoot"
$uagSettings["commandsFirstBoot"]=$commandsFirstBoot

$commandsEveryBoot = ValidateCustomBootTimeCommands $settings "commandsEveryBoot"
$uagSettings["commandsEveryBoot"]=$commandsEveryBoot

$uagSettings["defaultGateway"]=$defaultGateway

$uagSettings["v6DefaultGateway"]=$v6DefaultGateway

$uagSettings["forwardrules"]=$forwardrules

$uagSettings["routes0"]=$routes0

$uagSettings["routes1"]=$routes1

$uagSettings["routes2"]=$routes2

$uagSettings["policyRouteGateway0"]=$policyRouteGateway0

$uagSettings["policyRouteGateway1"]=$policyRouteGateway1

$uagSettings["policyRouteGateway2"]=$policyRouteGateway2

#
# .ovf definition defaults this to True so on vSphere we only need to set it if False.
#

$uagSettings["ceipEnabled"]=$ceipEnabled

$uagSettings["dsComplianceOS"]=""
if ($settings.General.dsComplianceOS -eq "true") {
    updatePasswordPolicyForDsComplianceOS $settings
    $uagSettings["dsComplianceOS"]="True"
}

$uagSettings["tlsPortSharingEnabled"]=""
if ($settings.General.tlsPortSharingEnabled -eq "true") {
    $uagSettings["tlsPortSharingEnabled"]="True"
}

$uagSettings["sshEnabled"]=""
if ($settings.General.sshEnabled -eq "true") {
    $uagSettings["sshEnabled"]="True"
}

$uagSettings["sshPasswordAccessEnabled"]=""
if ($settings.General.sshPasswordAccessEnabled -eq "false") {
    $uagSettings["sshPasswordAccessEnabled"]="False"
}

$uagSettings["sshKeyAccessEnabled"]=""
if ($settings.General.sshKeyAccessEnabled -eq "true") {
    $uagSettings["sshKeyAccessEnabled"]="True"
}

$sshBannerText=ReadLoginBannerText $settings
$uagSettings["sshLoginBannerText"]=$sshBannerText

$sshInterface = validateSSHInterface $settings
$uagSettings["sshInterface"]=$sshInterface

$sshPort = $settings.General.sshPort
$uagSettings["sshPort"]=""
if ($sshPort.length -gt 0 -and ($sshPort -match '^[0-9]+$')) {
    $uagSettings["sshPort"]=$sshPort
}

$secureRandomSrc=ReadSecureRandomSource $settings
$uagSettings["secureRandomSource"]=$secureRandomSrc

$uagSettings["Internet"]=$netInternet

$uagSettings["ManagementNetwork"]=$netManagementNetwork

$uagSettings["BackendNetwork"]=$netBackendNetwork

$uagSettings["diskMode"]=$diskMode


$uagSettings["enabledAdvancedFeatures"]=$enabledAdvancedFeatures

$uagSettings["configURL"]=$configURL

$uagSettings["configKey"]=$configKey

$uagSettings["configURLThumbprints"]=$configURLThumbprints

$uagSettings["configURLHttpProxy"]=$configURLHttpProxy

$uagSettings["adminCsrSubject"]=$adminCsrSubject

$uagSettings["adminCsrSAN"]=$adminCsrSAN

$uagSettings["additionalDeploymentMetadata"]=$additionalDeploymentMetadata

$uagSettingsObj=[pscustomobject]$uagSettings
$uagSettingsObj | ConvertTo-Json -Compress

