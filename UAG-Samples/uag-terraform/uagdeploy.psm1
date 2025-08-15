param(
	[Parameter(Mandatory=$false)] [string] $awAPIServerPwd,
	[Parameter(Mandatory=$false)] [string] $awTunnelGatewayAPIServerPwd,
	[Parameter(Mandatory=$false)] [string] $awCGAPIServerPwd,
	[Parameter(Mandatory=$false)] [string] $awSEGAPIServerPwd
)
#
# Function to parse token values from a .ini configuration file
#

function ImportIni {
	param ($file)

	$ini = @{}
	switch -regex -file $file
	{
		"^\s*#" {
			continue
		}
		"^\[(.+)\]$" {
			$section = $matches[1]
			$ini[$section] = @{}
		}
		"([A-Za-z0-9#_]+)=(.+)" {
			$name,$value = $matches[1..2]
			$ini[$section][$name] = $value.Trim()
		}
	}
	$ini
}

#
# Function to write an error message in red with black background
#

function WriteErrorString {
	param ($string)

	if ($isTerraform -eq "true") {
		Write-Error $string
		Exit 1

	}  else {
		write-host $string -foregroundcolor red -backgroundcolor black
	}
}

#
# Function to prompt the user for an UAG VM name and validate the input
#

function GetAPName {
	$valid=0
	while (! $valid) {
		if ($isTerraform -eq "true") {
			WriteErrorString "Error: Virtual machine name not provided"
		}
		$apName = Read-host "Enter a name for this VM"
		if (($apName.length -lt 1) -Or ($apName.length -gt 32)) {
			WriteErrorString "Error: Virtual machine name must be between 1 and 32 characters in length"
		} else {
			$valid=1
		}
	}
	$apName
}

function GetSyslogSettings {
	Param ($settings)
	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "syslogServerSettings$i"

		$sysLogType = $settings.$iniGroup.sysLogType
		$mqttTopic = $settings.$iniGroup.mqttTopic
		$syslogSettingName = $settings.$iniGroup.syslogSettingName
		if ($sysLogType.length -gt 0) {
			$sysLogType = ValidateSyslogTypeAndPromptForCorrection $sysLogType "$iniGroup > syslogType"
			if ($icount -eq 0)
			{
				$syslogServerSettings = "\'syslogServerSettings\': [ "
			}
			else
			{
				$syslogServerSettings += ","
			}

			$icount++

			$syslogServerSettings += "{ \'sysLogType\': \'$sysLogType\'"

			$syslogFormat=$settings.$iniGroup.syslogFormat
			if ($syslogFormat.length -gt 0)
			{
				$syslogFormat = ValidateSyslogFormatAndPromptForCorrection $syslogFormat "$iniGroup > syslogFormat"
				$syslogServerSettings += ","
				$syslogServerSettings += "\'syslogFormat\': \'$syslogFormat\'"
			}

			#Validate syslog category
			$syslogCategory = $settings.$iniGroup.syslogCategory
			if ($syslogCategory.length -gt 0)
			{
				$syslogCategory = ValidateSyslogCategoryAndPromptForCorrection $syslogCategory "$iniGroup > syslogCategory"
				$syslogServerSettings += ","
				$syslogServerSettings += "\'syslogCategory\': \'$syslogCategory\'"
			}
			if ($syslogSettingName.length -gt 0) {
				ValidateSyslogSettingName $iniGroup $syslogSettingName
				$syslogServerSettings += ","
				$syslogServerSettings += "\'syslogSettingName\': \'$syslogSettingName\'"
			}
			if($settings.$iniGroup.syslogSystemMessagesEnabledV2 -eq "true" -Or $settings.General.syslogSystemMessagesEnabled -eq "true"){
				$syslogServerSettings += ","
				$syslogServerSettings += "\'syslogSystemMessagesEnabledV2\': \'true\'"
			} 	else {
				$syslogServerSettings += ","
				$syslogServerSettings += "\'syslogSystemMessagesEnabledV2\': \'false\'"
			}
			#Validate syslog url
			$syslogUrl = $settings.$iniGroup.syslogUrl
			if (($sysLogType -eq "UDP") -Or ($sysLogType -eq "TCP"))
			{

				if ($syslogUrl.length -gt 0)
				{
					$syslogUrl = ValidateNewSyslogUrlInputAndPromptForCorrection $syslogUrl "$iniGroup > syslogUrl"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'syslogUrl\': \'$syslogUrl\'"
				}
				else
				{
					WriteErrorString "Error syslogUrl is mandatory in $iniGroup"
					Exit
				}
			}
			if (($sysLogType -eq "MQTT"))
			{

				if($syslogFormat -eq "JSON_TITAN")
				{

					$syslogServerSettings += ","
					$syslogServerSettings += "\'syslogCategoryList\':"
					$syslogServerSettings += "["
					$syslogCategoryListSet = New-Object System.Collections.Generic.HashSet[String]
					$tempString=""
					for($j=1;$j -lt 4;$j++)
					{
						$tempSyslogCategoryList="syslogCategoryList$j"
						$syslogCategoryList=$settings.$iniGroup.$tempSyslogCategoryList
						if ($syslogCategoryList.length -gt 0 ) {
							$syslogCategoryList = ValidateSyslogCategoryListAndPromptForCorrectionForTitan $syslogCategoryList "$iniGroup > syslogCategoryList$j"
							if($syslogCategoryListSet.Add($syslogCategoryList))
							{
								$tempString += "\'$syslogCategoryList\'"
								$tempString += ","
							}else{
								Write-Host "Duplicate entry $syslogCategoryList in $iniGroup >syslogCategoryList$j, so ignoring it"
							}
						}
					}

					if($tempString -eq "")
					{
						WriteErrorString "syslogCategoryList is not provided in $iniGroup , configure using the key syslogCategoryList1 or syslogCategoryList2 or syslogCategoryList3"
						Exit
					}
					$tempString = $tempString.trim(",")
					$syslogServerSettings += $tempString
					$syslogServerSettings += "]"
				}
				if ($syslogUrl.length -gt 0)
				{
					$syslogUrl = ValidateNewSyslogMqttUrlInputAndPromptForCorrection $syslogUrl "$iniGroup > syslogUrl"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'syslogUrl\': \'$syslogUrl\'"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'mqttTopic\': \'$mqttTopic\'"
					if($settings.$iniGroup.validateServerCertificate -eq "false"){
						$syslogServerSettings += ","
						$syslogServerSettings += "\'validateServerCertificate\': \'false\'"
					} 	else {
						$syslogServerSettings += ","
						$syslogServerSettings += "\'validateServerCertificate\': \'true\'"
					}
				}
				else
				{
					WriteErrorString "Error syslogUrl is mandatory in $iniGroup"
					Exit
				}

				$mqttClientCertCertPem = $settings.$iniGroup.mqttClientCertCertPem
				$mqttClientCertKeyPem = $settings.$iniGroup.mqttClientCertKeyPem
				$mqttServerCACertPem = $settings.$iniGroup.mqttServerCACertPem
				if ($mqttClientCertCertPem.length -gt 0 -And $mqttClientCertKeyPem.length -gt 0 -And $mqttServerCACertPem.length -gt 0) {
					$syslogServerSettings += ","
					$syslogServerSettings += "\'tlsMqttServerSettings\':{"

					$certContent = GetPEMCertificateContent $mqttClientCertCertPem "mqttClientCertCertPem"
					$syslogServerSettings += "\'mqttClientCertCertPem\': \'" + $certContent + "\'"

					$rsaprivkey = GetPEMPrivateKeyContent $mqttClientCertKeyPem "mqttClientCertKeyPem"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'mqttClientCertKeyPem\': \'" + $rsaprivkey + "\'"

					$certContent = GetPEMCertificateContent $mqttServerCACertPem "mqttServerCACertPem"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'mqttServerCACertPem\': \'" + $certContent + "\'"

					$syslogServerSettings += "}"

				} elseif ($mqttClientCertCertPem.length -gt 0 -Or $mqttClientCertKeyPem.length -gt 0 -Or $mqttServerCACertPem.length -gt 0) {
					#where one or two cert settings are missing
					WriteErrorString "Error: Either all Server CA, Client Cert and Client Key settings or none are required for MQTT configuration in $iniGroup"
					Exit
				}
			}

			if ($sysLogType -eq "TLS") {
				$syslogHost = $null
				$syslogTlsPort = $null
				if($settings.$iniGroup.tlsSyslogServerSettings.length -gt 0) {
					$hostName,$port,$acceptedPeer = $settings.$iniGroup.tlsSyslogServerSettings.split('|')
					if($hostName.length -gt 0) {
						$syslogHost = $hostName
					}
					if($port.length -gt 0) {
						$syslogTlsPort = $port
					}
				}
				$syslogServerSettings += ","
				$syslogServerSettings += "\'tlsSyslogServerSettings\':{"
				if($settings.$iniGroup.hostname.length -gt 0 -Or $syslogHost.length -gt 0) {
					if($settings.$iniGroup.hostname.length -gt 0) {
						$syslogHostName = $settings.$iniGroup.hostname
						$syslogServerSettings += "\'hostname\': \'$syslogHostName\'"
					}
					if($syslogHost.length -gt 0) {
						$syslogHostName = $syslogHost
						$syslogServerSettings += "\'hostname\': \'$syslogHostName\'"
					}
				} else {
					WriteErrorString "Error hostname is mandatory in $iniGroup"
					Exit
				}
				if($settings.$iniGroup.port.length -gt 0 -Or $syslogTlsPort.length -gt 0) {
					if($settings.$iniGroup.port.length -gt 0) {
						$syslogPort = $settings.$iniGroup.port
						$syslogServerSettings += ","
						$syslogServerSettings += "\'port\': \'$syslogPort\'"
					} else {
						$syslogPort = $syslogTlsPort
						$syslogServerSettings += ","
						$syslogServerSettings += "\'port\': \'$syslogPort\'"
					}
				} else {
					WriteErrorString "Error port is mandatory in $iniGroup"
					Exit
				}
				$syslogServerCACertPemV2 = $settings.$iniGroup.syslogServerCACertPemV2
				$syslogClientCertPemV2 = $settings.$iniGroup.syslogClientCertPemV2
				$syslogClientCertKeyPemV2 = $settings.$iniGroup.syslogClientCertKeyPemV2

				$syslogClientCert=$settings.General.syslogClientCertPem
				$syslogClientCertKey=$settings.General.syslogClientCertKeyPem
				$sysLogCACert=$settings.$iniGroup.syslogServerCACertPem

				$isCertificateValid = $false
				if ($sysLogCACert.length -eq 0 -And $syslogServerCACertPemV2.length -eq 0) {
					WriteErrorString "Error Server CA is mandatory for Syslog TLS configutaion in $iniGroup"
					Exit
				}
				if (($syslogClientCertPemV2.length -gt 0 -And $syslogClientCertKeyPemV2.length -eq 0) -Or
						($syslogClientCertPemV2.length -eq 0 -And $syslogClientCertKeyPemV2.length -gt 0) -Or
						($syslogClientCert.length -eq 0 -And $syslogClientCertKey.length -gt 0) -Or
						(($syslogClientCert.length -gt 0 -And $syslogClientCertKey.length -eq 0))) {
					WriteErrorString "Error Both Client Cert and Client Key is mandatory for Syslog TLS configuration in $iniGroup"
					Exit
				}
				if($sysLogCACert.length -gt 0) {
					$certContent = GetPEMCertificateContent $sysLogCACert "sysLogCACert"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'syslogServerCACertPemV2\': \'" + $certContent + "\'"
					if ($syslogClientCert.length -gt 0 -And $syslogClientCertKey.length -gt 0) {
						$certContent = GetPEMCertificateContent $syslogClientCert "syslogClientCert"
						$syslogServerSettings += ","
						$syslogServerSettings += "\'syslogClientCertPemV2\': \'" + $certContent + "\'"

						$rsaprivkey = GetPEMPrivateKeyContent $syslogClientCertKey "syslogClientCertKey"
						$syslogServerSettings += ","
						$syslogServerSettings += "\'syslogClientCertKeyPemV2\': \'" + $rsaprivkey + "\'"
					}
					$syslogServerSettings += "}"
					$isCertificateValid = $true
				}
				if ($isCertificateValid -ne $true) {
					$certContent = GetPEMCertificateContent $syslogServerCACertPemV2 "syslogServerCACertPemV2"
					$syslogServerSettings += ","
					$syslogServerSettings += "\'syslogServerCACertPemV2\': \'" + $certContent + "\'"
					if ($syslogClientCertPemV2.length -gt 0 -And $syslogClientCertKeyPemV2.length -gt 0) {
						$certContent = GetPEMCertificateContent $syslogClientCertPemV2 "syslogClientCertPemV2"
						$syslogServerSettings += ","
						$syslogServerSettings += "\'syslogClientCertPemV2\': \'" + $certContent + "\'"

						$rsaprivkey = GetPEMPrivateKeyContent $syslogClientCertKeyPemV2 "syslogClientCertKeyPemV2"
						$syslogServerSettings += ","
						$syslogServerSettings += "\'syslogClientCertKeyPemV2\': \'" + $rsaprivkey + "\'"
					}
					$syslogServerSettings += "}"
					$isCertificateValid = $true
				}
				if($isCertificateValid -eq $fasle) {
					$syslogServerSettings += "}"
				}
			}
			if ($icount -gt 0) {
				$syslogServerSettings += " }"
			}
		}
	}

	if ($icount -gt 0) {
		$syslogServerSettings += "]"
	}

	$syslogAuditUrlSettings = GetSyslogAuditSettings($settings)

	#Build syslogSettings DTO
	if((-not ([string]::IsNullOrEmpty($syslogServerSettings))) -Or (-not ([string]::IsNullOrEmpty($syslogAuditUrlSettings)))){
		$syslogSettings += "\'syslogSettings\' : {"
		if(-not ([string]::IsNullOrEmpty($syslogServerSettings)))
		{
			$syslogSettings += $syslogServerSettings
			if(-not ([string]::IsNullOrEmpty($syslogAuditUrlSettings)))
			{
				$syslogSettings +=","
			}
		}

		if(-not ([string]::IsNullOrEmpty($syslogAuditUrlSettings))){
			$syslogSettings += $syslogAuditUrlSettings
		}
		$syslogSettings += "}"
	}

	$syslogSettings

}

function ValidateNewSyslogUrlInputAndPromptForCorrection {
	Param ($str, $uriLabel)

	$sl = $str.trim()
	$res = ((ValidateStringIsURI $sl '^syslog$') -or (ValidateHostPort $sl))
	if ($res -eq $false){
		WriteErrorString "Syslog URL is not in an acceptable format for field $uriLabel. Syslog can be host name or IP address, optionally with syslog:// scheme and port. Provided input: $str"
		$str = Read-Host "Please provide a valid input."
		return ValidateNewSyslogUrlInputAndPromptForCorrection $str $uriLabel
	}
	return $str
}
function ValidateNewSyslogMqttUrlInputAndPromptForCorrection {
	Param ($str, $uriLabel)

	$sl = $str.trim()
	$res = ((ValidateStringIsURI $sl '^tcp$') -or (ValidateHostPort $sl))
	if ($res -eq $false){
		WriteErrorString "Syslog URL is not in an acceptable format for field $uriLabel. Syslog can be host name or IP address, optionally with tcp:// scheme and port. Provided input: $str"
		$str = Read-Host "Please provide a valid input."
		return ValidateNewSyslogMqttUrlInputAndPromptForCorrection $str $uriLabel
	}
	return $str
}

function ValidateSyslogTypeAndPromptForCorrection {
	Param($str, $uriLabel)

	$sl = $str.trim()
	if ($sl.length -gt 0)
	{

		if (-Not(($sl -eq "UDP") -Or ($sl -eq "TLS") -Or ($sl -eq "TCP") -Or ($sl -eq "MQTT")))
		{
			WriteErrorString "Error: Invalid sysLogType value specified  for field $uriLabel. It can be one of UDP/TLS/TCP/MQTT "
			$str = Read-Host "Please provide a valid input."
			return ValidateSyslogTypeAndPromptForCorrection $str $uriLabel
			#Exit
		}
	}
	else
	{
		$str = "UDP"
	}
	return $str
}

function ValidateSyslogCategoryAndPromptForCorrection
{
	Param($str, $uriLabel)

	$sl = $str.trim()
	if ($sl.length -gt 0)
	{

		if ($sl -in "ALL", "AUDIT_ONLY")
		{
			return $sl;
		}
		WriteErrorString "Error: Invalid syslogCategory value specified for field $uriLabel. It can be one of ALL/AUDIT_ONLY "
		$str = Read-Host "Please provide a valid input."
		return ValidateSyslogCategoryAndPromptForCorrection $str

	}
	else
	{
		$str = "ALL"
	}
	return $str
}

function ValidateSyslogCategoryListAndPromptForCorrectionForTitan
{
	Param($str, $uriLabel)
	$sl = $str.trim()
	if ($sl.length -gt 0)
	{
		if ($sl -in "TRACEABILITY", "DEPLOYMENT","STATS")
		{
			return $sl;
		}
		WriteErrorString "Error: Invalid syslogCategoryList value specified for field $uriLabel. It can be one of TRACEABILITY/DEPLOYMENT/STATS"
		$str = Read-Host "Please provide a valid input."
		return ValidateSyslogCategoryListAndPromptForCorrectionForTitan $str
	}

	return $str.trim()
}
function ValidateSyslogFormatAndPromptForCorrection
{
	Param($str, $uriLabel)
	$sl = $str.trim()
	if ($sl.length -gt 0)
	{
		if ($sl -in "TEXT", "JSON_TITAN")
		{
			return $sl;
		}
		WriteErrorString "Error: Invalid syslogFormat value specified for field $uriLabel. It can be one of TEXT or JSON_TIAN "
		$str = Read-Host "Please provide a valid input."
		return ValidateSyslogFormatAndPromptForCorrection $str
	}
	else
	{
		$str = "TEXT"
	}
	return $str
}
function GetTLSSyslogServer
{
	param($str)
	$tlsServer = "\'tlsSyslogServerSettings\': {"
	$hostName, $port, $acceptedPeer = $str.split('|')
	$tlsServer += "\'hostname\': \'$hostName\'"
	if ($port.length -gt 0)
	{
		$tlsServer += ","
		$tlsServer += "\'port\': \'$port\'"
	}
	$tlsServer += "}"
	return $tlsServer
}


function GetSyslogAuditSettings
{
	Param ($settings)

	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "auditSyslogServerSettings$i"
		$syslogUrl = $settings.$iniGroup.syslogUrl
		if($syslogUrl.length -gt 0){
			if ($icount -eq 0) {
				$syslogSettings = "\'auditSyslogServerSettings\': [ "
			} else {
				$syslogSettings += ","
			}

			$syslogSettings += "{"
			$icount++
			$syslogUrl = ValidateNewSyslogUrlInputAndPromptForCorrection $syslogUrl "$iniGroup > syslogUrl"
			$syslogSettings += "\'syslogUrl\': \'$syslogUrl\'"
			if ($icount -gt 0) {
				$syslogSettings += " }"
			}
		}

	}

	if ($icount -gt 0) {
		$syslogSettings += "]"
	}
	#Write-Host "`nSyslog Audit setting is $syslogSettings"
	$syslogSettings
}
#
# Function to decrypt an encrypted password
#

function ConvertFromSecureToPlain {

	param( [Parameter(Mandatory=$true)][System.Security.SecureString] $SecurePassword)

	# Create a "password pointer".
	$PasswordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)

	# Get the plain text version of the password.
	$PlainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordPointer)

	# Free the pointer.
	[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPointer)

	# Return the plain text password.
	$PlainTextPassword

}


function ValidateStringIsNumeric {
	param( [Parameter(Mandatory=$true)] $numericString, $fieldName, $iniGroup)

	if ($numericString.length -gt 0) {
		try {
			$number = [int]$numericString
		} catch {
			WriteErrorString "Error: $fieldName in the section $iniGroup is not an integer"
			Exit
		}
	}
}



#
# Function to prompt the user for an UAG root password and validate the input
#

function GetRootPwd {
	param( [Parameter(Mandatory=$true)] $apName,
		[Parameter(Mandatory=$true)] $settings,
		[Parameter(Mandatory=$true)] $osLoginUsername)

	if ($settings.General.passwordPolicyMinLen) {
		[int]$passwordPolicyMinLen=GetValue General passwordPolicyMinLen $settings.General.passwordPolicyMinLen 6 64 characters False
	}
	else {
		# Default Min length
		[int]$passwordPolicyMinLen=6
	}
	[int]$countClass  = 0
	$passwordPolicyMinClass=$settings.General.passwordPolicyMinClass
	$match=0
	while (! $match) {
		$valid=0
		while (! $valid) {
			$rootPwd = Read-Host -assecurestring "Enter $osLoginUsername user password for" $apName
			$rootPwd = ConvertFromSecureToPlain $rootPwd

			if ( $passwordPolicyMinLen -and ($rootPwd.length -lt $passwordPolicyMinLen))
			{
				WriteErrorString "Error: Password must contain at least $passwordPolicyMinLen characters"
				Continue
			}
			if (([regex]"[0-9]").Matches($rootPwd).Count -ge 1 ) {
				$countClass++;
			}
			if (([regex]"[A-Z]").Matches($rootPwd).Count -ge 1 ) {
				$countClass++;
			}
			if (([regex]"[a-z]").Matches($rootPwd).Count -ge 1 ) {
				$countClass++;
			}
			if (([regex]"[!@#$%*()]").Matches($rootPwd).Count -ge 1 ) {
				$countClass++;
			}
			if ( $passwordPolicyMinClass -and ($countClass -lt $passwordPolicyMinClass )) {
				WriteErrorString "Error: Password must contain characters from  $passwordPolicyMinClass different classes (Lowercase / Uppercase / Numeric/ Special Characters)"
				$countClass=0
				Continue
			}
			$valid=1
		}

		$rootPwd2 = Read-Host -assecurestring "Re-enter $osLoginUsername user password"
		$rootPwd2 = ConvertFromSecureToPlain $rootPwd2
		if ($rootPwd -ne $rootPwd2) {
			WriteErrorString "Error: re-entered password does not match"
		} else {
			$match=1
		}
	}
	$rootPwd = $rootPwd -replace '"', '\"'
	$rootPwd = $rootPwd -replace "'", "\047"
	$rootPwd
}

#
# Function to prompt the user for an UAG admin password and validate the input
#

function GetAdminPwd {
	param( [Parameter(Mandatory=$true)] $apName, $settings)
	WriteErrorString "Either an admin password must be specified or SAML Authentication should be enabled if access to the UAG Admin UI and REST API is required."
	GetUserPwd $apName "admin" $true $settings
}


#
# Function to prompt user for an Admin UI password and validate the input
#
function GetUserPwd {
	param( [Parameter(Mandatory=$true)] $apName,
		[Parameter(Mandatory=$true)] $userName,
		[Parameter(Mandatory=$true)] $isOptional, $settings
	)

	$match=0
	while (! $match) {
		$valid=0
		while (! $valid) {
			if($isOptional) {
				$userPwd = Read-Host -assecurestring "Enter password for "$userName" for the Admin UI access for "$apName". Hit return to skip this."
			} else {
				$userPwd = Read-Host -assecurestring "Enter password for "$userName" for the Admin UI access for "$apName
			}

			$userPwd = ConvertFromSecureToPlain $userPwd
			if ($isOptional -and $userPwd.length -eq 0) {
				return
			}

			$isStrongPwd = CheckStrongPwd $userPwd $settings
			if($isStrongPwd.length -gt 0) {
				WriteErrorString $isStrongPwd
				Continue
			}
			$valid=1
		}

		$userPwd2 = Read-Host -assecurestring "Re-enter the password"
		$userPwd2 = ConvertFromSecureToPlain $userPwd2
		if ($userPwd -ne $userPwd2) {
			WriteErrorString "Error: re-entered password does not match"
		} else {
			$match=1
		}
	}
	$userPwd = $userPwd -replace '"', '\"'
	$userPwd = $userPwd -replace "'", "\047"
	$userPwd
}

#
# Function to prompt the user for whether to join Customer Experience Improvement Program (CEIP)
# Default is yes.
#

function GetCeipEnabled {
	param( [Parameter(Mandatory=$true)] $apName)
	write-host "Join the Omnissa Customer Experience Improvement Program?

This product participates in Omnissa's Customer Experience Improvement Program (CEIP).
The CEIP provides Omnissa with information that enables Omnissa to improve its products and services,
to fix problems, and to advise you on how best to deploy and use our products. As part of the CEIP,
Omnissa collects technical information about your organization's use of Omnissa products and services
on a regular basis in association with your organization's Omnissa license key(s).
This information does not personally identify any individual.

For additional information regarding the CEIP, please see the Trust Center at https://www.omnissa.com/trust-center/.

If you prefer not to participate in Omnissa's CEIP, you should enter no.

You may join or leave Omnissa's CEIP for this product at any time. In the UAG Admin UI in System Configuration,
there is a setting 'Join CEIP' which can be set to yes or no and has immediate effect.

To Join the Omnissa Customer Experience Improvement Program with Unified Access Gateway,
either enter yes or just hit return as the default for this setting is yes."

	$valid=$false
	while (! $valid) {
		$yorn = Read-Host "Join CEIP for" $apName "? (default is yes for UAG 3.1 and newer)"
		if (($yorn -eq "yes") -Or ($yorn -eq "")) {
			$ceipEnabled = $true
			$valid=$true
			break
		} elseif ($yorn -eq "no") {
			$ceipEnabled = $false
			$valid=$true
			break
		}
		WriteErrorString 'Error: please enter "yes" or "no", or just hit return for yes.'
	}
	$ceipEnabled
}

function GetTrustedCertificates {
	param($edgeService, $iniKeyName, $jsonKey)
	#Add Trusted certificates entries in json
	$allCerts = "\'$jsonKey\': [ "
	for($i=1;;$i++)
	{
		$cert = "$iniKeyName$i"
		$cert = $settings.$edgeService.$cert
		if($cert.length -gt 0)
		{
			if (!(Test-path $cert)) {
				WriteErrorString "Error: PEM Certificate file not found ($cert)"
				Exit
			}
			else
			{
				$content = (Get-Content $cert | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

				if ($content -like "*-----BEGIN CERTIFICATE-----*") {
					#Write-host "valid cert"
				} else {
					WriteErrorString "Error: Invalid certificate file It must contain -----BEGIN CERTIFICATE-----."
					Exit
				}
				$fileName = $cert.SubString($cert.LastIndexof('\')+1)
				#Write-Host "$fileName"
				$allCerts += "{ \'name\': \'$fileName\'"
				$allCerts += ","
				$allCerts += "\'data\': \'"
				$allCerts += $content
				$allCerts += "\'"
				$allCerts += "},"
			}
		}
		else {
			$allCerts = $allCerts.Substring(0, $allCerts.Length-1)
			#Write-Host "$($i-1) Certificates Added successfully"
			break;
		}
	}
	$allCerts += "]"

	$allCerts
}

function GetHostEntries {
	param($edgeService)
	# Add all host entries into json
	$allHosts = "\'hostEntries\': [ "
	for($i=1;;$i++)
	{
		$hostEntry = "hostEntry$i"
		$hostEntry = $settings.$edgeService.$hostEntry
		if($hostEntry.length -gt 0)
		{
			$allHosts += "\'"+$hostEntry+"\',"
		}
		else {
			$allHosts = $allHosts.Substring(0, $allHosts.Length-1)
			#Write-Host "$($i-1) Host entries Added successfully"
			break;
		}
	}
	$allHosts += "]"

	$allHosts
}
function GetProxySettings {
	Param ($settings)

	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "OutboundProxySettings$i"

		$proxyName = $settings.$iniGroup.name
		$proxyType = $settings.$iniGroup.proxyType

		if ($proxyName.length -gt 0) {

			ValidateSettingName "OutboundProxySettings$i" $proxyName

			if ($icount -eq 0) {
				$proxySettings = "\'outboundProxySettingsList\': { \'outboundProxySettingsList\': [ "
			} else {
				$proxySettings += ","
			}


			$icount++
			$proxySettings += "{ \'name\': \'$proxyName\'"

			$proxyAuthType = $settings.$iniGroup.authType
			if ($proxyAuthType -gt 0 ) {

				if (($proxyAuthType -eq "Basic") -Or ($proxyAuthType -eq "NTLM")) {
					$proxySettings += ","
					$proxySettings += "\'authType\': \'$proxyAuthType\'"
				} else {
					WriteErrorString "Error: Invalid Authentication Type in $iniGroup"
					Exit
				}

				$proxyUserName = $settings.$iniGroup.userName

				if ($proxyUserName.length -gt 0) {
					$valid=0
					while (! $valid) {
						$prompt='Enter the password for the outbound proxy setting ' + $proxyUserName+''
						$pwd = Read-Host -assecurestring $prompt
						$pwd = ConvertFromSecureToPlain $pwd
						if ( $pwd.length -gt 0) {
							$valid=1
						}
					}
					$proxySettings += ","
					$proxySettings += "\'userName\': \'$proxyUserName\'"
					$proxySettings += ","
					$proxySettings += "\'password\': \'$pwd\'"
				} else {
					WriteErrorString "Error: Username not specified in $iniGroup"
					Exit
				}

				if ($proxyAuthType -eq "NTLM") {
					$proxyDomain = $settings.$iniGroup.domain
					$proxyWorkstation = $settings.$iniGroup.workstation

					if ($proxyDomain.length -gt 0) {
						$proxySettings += ","
						$proxySettings += "\'domain\': \'$proxyDomain\'"
					}
					if ($proxyWorkstation.length -gt 0) {
						$proxySettings += ","
						$proxySettings += "\'workstation\': \'$proxyWorkstation\'"
					}
				}

			}

			$jcount = 0
			for($j=1;$j -lt 100;$j++)
			{
				$includedUrlName = "includedHosts$j"
				$includedUrlValue = $settings.$iniGroup.$includedUrlName
				if($includedUrlValue.length -gt 0)
				{

					if ($jcount -eq 0)
					{
						$proxySettings += ","
						$proxySettings += "\'includedHosts\': [ "
					}
					Elseif ($jcount -gt 0)
					{
						$proxySettings += ","
					}
					$proxySettings += "\'$includedUrlValue\'"

					$jcount++

				}
			}
			if ($jcount -gt 0) {
				$proxySettings += " ]"
			}

			$proxyTestUrl = $settings.$iniGroup.testHostUrl
			if ($proxyTestUrl.length -gt 0) {
				$proxySettings += ","
				$proxySettings += "\'testHostUrl\': \'$proxyTestUrl\'"
			}

			#Adding Proxy Server URL
			$proxyServerUrl = $settings.$iniGroup.proxyUrl
			if ($proxyServerUrl.length -gt 0) {

				$proxyServerUrl = ValidateWebURIAndPromptForCorrection $proxyServerUrl "$iniGroup > proxyUrl" $false

				$proxySettings += ","
				$proxySettings += "\'proxyUrl\': \'$proxyServerUrl\'"

				#Adding trusted certificates
				if ($settings.$iniGroup.trustedCert1.length -gt 0) {
					$trustedCertificates = GetTrustedCertificates $iniGroup "trustedCert" "trustedCertificates"
					$proxySettings += ","
					$proxySettings += $trustedCertificates
				}

			} ElseIf ($jcount -eq 0) {
				WriteErrorString "Error: Proxy Server Url is  mandatory in $iniGroup"
				Exit
			}

			if ($icount -gt 0) {
				$proxySettings += " }"
			}
		}
	}

	if ($icount -gt 0) {
		$proxySettings += "] }"
	}

	$proxySettings
}

function GetJWTSettings {
	Param ($settings)

	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "JWTSettings$i"

		$jwtName = $settings.$iniGroup.name

		if ($jwtName.length -gt 0) {
			ValidateSettingName "JWTSettings$i" $jwtName

			if ($icount -eq 0) {
				$jwtSettings = "\'jwtSettingsList\': { \'jwtSettingsList\': [ "
			} else {
				$jwtSettings += ","
			}

			$icount++
			$jwtSettings += "{ \'name\': \'$jwtName\'"

			$jwtIssuer = $settings.$iniGroup.issuer
			if ($jwtIssuer.length -gt 0) {
				$jwtSettings += ","
				$jwtSettings += "\'issuer\': \'$jwtIssuer\'"
			}


			$jcount = 0
			for($j=1;$j -lt 100;$j++)
			{
				$keyFileName = "publicKey$j"
				$keyFileVal = $settings.$iniGroup.$keyFileName
				if($keyFileVal.length -gt 0)
				{
					if (!(Test-path $keyFileVal)) {
						WriteErrorString "Error: JWT public key file not found ($keyFileVal) in $iniGroup"
						Exit
					}

					$content = (Get-Content $keyFileVal | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

					if ($content -like "*-----BEGIN PUBLIC KEY-----*") {
						#Write-host "valid key file"
					} else {
						WriteErrorString "Error: Invalid JWT public key file in $iniGroup. It must contain -----BEGIN PUBLIC KEY----- in $iniGroup."
						Exit
					}
					$fileName = $keyFileVal.SubString($keyFileVal.LastIndexof('\')+1)

					if ($fileName -eq "Public_Key_From_URL") {
						WriteErrorString "Error: A static public key file cannot have the name : Public_Key_From_URL in $iniGroup"
						Exit
					}

					if ($jcount -eq 0) {
						$jwtSettings += ","
						$jwtSettings += "\'publicKeys\': [ "
					} Elseif ($jcount -gt 0) {
						$jwtSettings += ","
					}

					$jcount++
					$jwtSettings += "{ \'name\': \'$fileName\'"
					$jwtSettings += ","
					$jwtSettings += "\'data\': \'"
					$jwtSettings += $content
					$jwtSettings += "\'"
					$jwtSettings += "}"
				}
			}
			if ($jcount -gt 0) {
				$jwtSettings += " ]"
			}

			#Adding public key URL
			$jwtPublicKeyUrl = $settings.$iniGroup.url
			if ($jwtPublicKeyUrl.length -gt 0) {
				$jwtPublicKeyUrl = ValidateWebURIAndPromptForCorrection $jwtPublicKeyUrl "$iniGroup > url" $false
				#
				# Strip the final :443 if specified as that is the default anyway
				#

				if ($jwtPublicKeyUrl.Substring($jwtPublicKeyUrl.length - 4, 4) -eq ":443") {
					$jwtPublicKeyUrl=$jwtPublicKeyUrl.Substring(0, $jwtPublicKeyUrl.IndexOf(":443"))
				}

				$jwtSettings += ","
				$jwtSettings += "\'publicKeyURLSettings\': { "
				$jwtSettings += "\'url\': \'$jwtPublicKeyUrl\'"

				#Adding thumbprints
				$jwtPublicKeyUrlThumbprints=$settings.$iniGroup.urlThumbprints
				if ($jwtPublicKeyUrlThumbprints.length -gt 0) {
					# Remove invalid thumbprint characters
					$jwtPublicKeyUrlThumbprints = SanitizeThumbprints $jwtPublicKeyUrlThumbprints
					$jwtPublicKeyUrlThumbprints = validateAndUpdateThumbprints $jwtPublicKeyUrlThumbprints $settings.General.minSHAHashSize "JWT-$jwtName"
					$jwtSettings += ","
					$jwtSettings += "\'urlThumbprints\': \'$jwtPublicKeyUrlThumbprints\'"
				}

				#Adding trusted certificates
				if ($settings.$iniGroup.trustedCert1.length -gt 0) {
					$trustedCertificates = GetTrustedCertificates $iniGroup "trustedCert" "trustedCertificates"
					$jwtSettings += ","
					$jwtSettings += $trustedCertificates
					$edgeServiceSettingsVIEW += $trustedCertificates
				}


				#Adding public key refresh interval
				if ($settings.$iniGroup.publicKeyRefreshInterval.length -gt 0) {
					try {
						$publicKeyRefreshInterval = [int]$settings.$iniGroup.publicKeyRefreshInterval
					} catch {
						WriteErrorString "Error: publicKeyRefreshInterval in $iniGroup is not an integer"
						Exit
					}
					if (($publicKeyRefreshInterval -ne 0) -and (($publicKeyRefreshInterval -lt 10) -or ($publicKeyRefreshInterval -gt 86400))) {
						WriteErrorString "Error: Public key refresh interval can be either 0 or between 10 secs - 86400 secs (both inclusive) in $iniGroup"
						Exit
					}
					$jwtSettings += ","
					$jwtSettings += "\'urlResponseRefreshInterval\': \'$publicKeyRefreshInterval\'"
				}

				$jwtSettings += " }"

			} ElseIf ($jcount -eq 0) {
				WriteErrorString "Error: At least one static public key or a public key URL is mandatory in $iniGroup"
				Exit
			}

			if ($icount -gt 0) {
				$jwtSettings += " }"
			}
		}
	}

	if ($icount -gt 0) {
		$jwtSettings += "] }"
	}

	$jwtSettings
}

function GetJWTIssuerSettings {
	Param ($settings)

	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "JWTIssuerSettings$i"

		$jwtName = $settings.$iniGroup.name

		if ($jwtName.length -gt 0) {
			ValidateSettingName "JWTIssuerSettings$i" $jwtName

			if ($icount -eq 0) {
				$jwtSettings = "\'jwtIssuerSettingsList\': { \'jwtIssuerSettingsList\': [ "
			} else {
				$jwtSettings += ","
			}

			$icount++
			$jwtSettings += "{ \'name\': \'$jwtName\'"

			$jwtIssuer = $settings.$iniGroup.issuer
			if ($jwtIssuer.length -gt 0) {
				$jwtSettings += ","
				$jwtSettings += "\'issuer\': \'$jwtIssuer\'"
			}

			$privateKeyPem = $settings.$iniGroup.pemPrivKey
			$certChainPem = $settings.$iniGroup.pemCerts
			$pfxKeystore = $settings.$iniGroup.pfxCerts
			$signingKeyConfigured = "false"
			if ($certChainPem.length -gt 0) {
				if ($privateKeyPem.length -eq 0) {
					WriteErrorString "Error: JWT Issuer PEM private key file privateKeyPem not specified in $iniGroup"
					CleanExit
				}

				$signingKeyConfigured = "true"
				# Read the PEM contents and remove any preamble before ----BEGIN
				$privateKeyPemContent = (Get-Content $privateKeyPem | Out-String) -replace "'", "\\047" -replace "`r`n", "\\n" -replace """", ""
				$privateKeyPemContent = $privateKeyPemContent.Substring($privateKeyPemContent.IndexOf("-----BEGIN"))
				if (!($privateKeyPemContent -like "*-----BEGIN*")) {
					WriteErrorString "Error: [$iniGroup] Invalid certs PEM file (privateKeyPemContent) specified. It must contain a certificate in $iniGroup."
					Exit
				}

				$certChainContent = GetPEMCertificateContent $certChainPem "certChainPem"

				$jwtSettings += ","
				$jwtSettings += " \'jwtSigningPemCertSettings\': {"
				$jwtSettings += ( "\'privateKeyPem\': \'" + $privateKeyPemContent + "\', \'certChainPem\': \'" + $certChainContent +"\'")
				$jwtSettings += "}"

			}
			elseif ($pfxKeystore.length -gt 0) {

				if (!(Test-path $pfxKeystore)) {
					WriteErrorString "Error: PFX Certificate file not found ($pfxKeystore) in $iniGroup"
					CleanExit
				}

				$signingKeyConfigured = "true"
				$pfxKeystore = Resolve-Path -Path $pfxKeystore

				$pfxPassword = GetPfxPassword $pfxKeystore JWTIssuerSettings$i

				if (!(isValidPfxFile $pfxKeystore $pfxPassword)) {
					CleanExit
				}

				$Content = [System.IO.File]::ReadAllBytes($pfxKeystore)
				$certsFilePfxB64 = [System.Convert]::ToBase64String($Content)

				$pfxCertAlias=$settings.Horizon.pfxCertAlias
				$jwtSettings += ","
				$jwtSettings += " \'jwtSigningPfxCertSettings\': {"
				$jwtSettings +=  ( "\'pfxKeystore\': \'" + $certsFilePfxB64 + "\', \'password\': \'" + $pfxPassword )
				if ($pfxCertAlias.length -gt 0) {
					$jwtSettings += "\', \'alias\': \'"
					$jwtSettings += $pfxCertAlias
				}
				$jwtSettings += "\' }"

			}

			if($signingKeyConfigured -eq "false") {
				WriteErrorString "Error: Signing certificates(either PEM or PFX) are required for the JWT issuer $jwtName in $iniGroup"
				CleanExit
			}

			$encryptionPublicKeyConfigured = "false"
			$keyFileName = "encryptionPublicKey"
			$keyFileVal = $settings.$iniGroup.$keyFileName
			if($keyFileVal.length -gt 0)
			{
				$encryptionPublicKeyConfigured = "true";
				if (!(Test-path $keyFileVal)) {
					WriteErrorString "Error: JWT public key file not found ($keyFileVal) in $iniGroup"
					Exit
				}

				$content = (Get-Content $keyFileVal | Out-String) -replace "'", "\\047" -replace "`r`n", "\\n"

				if ($content -like "*-----BEGIN PUBLIC KEY-----*") {
					#Write-host "valid key file"
				} else {
					WriteErrorString "Error: Invalid JWT public key file in $iniGroup. It must contain -----BEGIN PUBLIC KEY----- in $iniGroup."
					Exit
				}
				$fileName = $keyFileVal.SubString($keyFileVal.LastIndexof('\')+1)

				if ($fileName -eq "Public_Key_From_URL") {
					WriteErrorString "Error: A static public key file cannot have the name : Public_Key_From_URL in $iniGroup"
					Exit
				}
				$jwtSettings += ","
				$jwtSettings += "\'encryptionPublicKey\': [ "
				$jwtSettings += "{ \'name\': \'$fileName\'"
				$jwtSettings += ","
				$jwtSettings += "\'data\': \'"
				$jwtSettings += $content
				$jwtSettings += "\'"
				$jwtSettings += "}]"
			}

			#Adding public key URL
			$jwtPublicKeyUrl = $settings.$iniGroup.url
			if ($jwtPublicKeyUrl.length -gt 0) {
				if($encryptionPublicKeyConfigured -eq "true") {
					WriteErrorString "Error: Either Encryption public key or Dynamic public key url can be configured for the JWT issuer $jwtName in $iniGroup"
					CleanExit
				}

				$jwtPublicKeyUrl = ValidateWebURIAndPromptForCorrection $jwtPublicKeyUrl "$iniGroup > url" $false
				#
				# Strip the final :443 if specified as that is the default anyway
				#

				if ($jwtPublicKeyUrl.Substring($jwtPublicKeyUrl.length - 4, 4) -eq ":443") {
					$jwtPublicKeyUrl=$jwtPublicKeyUrl.Substring(0, $jwtPublicKeyUrl.IndexOf(":443"))
				}

				$jwtSettings += ","
				$jwtSettings += "\'encryptionPublicKeyURLSettings\': { "
				$jwtSettings += "\'url\': \'$jwtPublicKeyUrl\'"

				#Adding thumbprints
				$jwtPublicKeyUrlThumbprints=$settings.$iniGroup.urlThumbprints
				if ($jwtPublicKeyUrlThumbprints.length -gt 0) {
					# Remove invalid thumbprint characters
					$jwtPublicKeyUrlThumbprints = SanitizeThumbprints $jwtPublicKeyUrlThumbprints
					$jwtPublicKeyUrlThumbprints = validateAndUpdateThumbprints $jwtPublicKeyUrlThumbprints $settings.General.minSHAHashSize "JWTIssuer-$jwtName"
					$jwtSettings += ","
					$jwtSettings += "\'urlThumbprints\': \'$jwtPublicKeyUrlThumbprints\'"
				}

				#Adding trusted certificates
				if ($settings.$iniGroup.trustedCert1.length -gt 0) {
					$trustedCertificates = GetTrustedCertificates $iniGroup "trustedCert" "trustedCertificates"
					$jwtSettings += ","
					$jwtSettings += $trustedCertificates
					$edgeServiceSettingsVIEW += $trustedCertificates
				}


				#Adding public key refresh interval
				if ($settings.$iniGroup.publicKeyRefreshInterval.length -gt 0) {
					try {
						$publicKeyRefreshInterval = [int]$settings.$iniGroup.publicKeyRefreshInterval
					} catch {
						WriteErrorString "Error: publicKeyRefreshInterval in $iniGroup is not an integer "
						Exit
					}
					if (($publicKeyRefreshInterval -ne 0) -and (($publicKeyRefreshInterval -lt 10) -or ($publicKeyRefreshInterval -gt 86400))) {
						WriteErrorString "Error: Public key refresh interval can be either 0 or between 10 secs - 86400 secs (both inclusive) in $iniGroup"
						Exit
					}
					$jwtSettings += ","
					$jwtSettings += "\'urlResponseRefreshInterval\': \'$publicKeyRefreshInterval\'"
				}

				$jwtSettings += " }"

			} #ElseIf ($jcount -eq 0) {
			#  WriteErrorString "Error: At least one static public key or a public key URL is mandatory in $iniGroup"
			#  Exit
			#}

			if ($icount -gt 0) {
				$jwtSettings += " }"
			}
		}
	}

	if ($icount -gt 0) {
		$jwtSettings += "] }"
	}

	$jwtSettings
}


function GetSAMLServiceProviderMetadata {
	Param ($settings)

	$samlMetadata = "\'serviceProviderMetadataList\': { "
	$samlMetadata += "\'items\': [ "
	$spCount=0

	for($i=1;$i -lt 99;$i++)
	{
		$spNameLabel = "spName$i"
		$spName = $settings.SAMLServiceProviderMetadata.$spNameLabel
		$metadataXmlLabel = "metadataXml$i"
		$metadataXml = $settings.SAMLServiceProviderMetadata.$metaDataXmlLabel
		$encryptAssertionLabel = "encryptAssertion$i"
		$encryptAssertion = $settings.SAMLServiceProviderMetadata.$encryptAssertionLabel
		if($spName.length -gt 0)
		{
			ValidateSettingName "SAMLServiceProviderMetadata > spName$i" $spName

			if ($metaDataXml.length -eq 0) {
				WriteErrorString "Error: Missing $metaDataXmlLabel"
				Exit
			}

			if (!(Test-path $metaDataXml)) {
				WriteErrorString "Error: SAML Metada file not found ($metaDataXml)"
				Exit
			}
			$content = (Get-Content $metaDataXml | Out-String) -replace "'", "\\047" -replace "`r`n", "\\n" -replace """", "\\"""

			if ($content -like "*urn:oasis:names:tc:SAML:2.0:metadata*") {
				#Write-host "valid metadata"
			} else {
				WriteErrorString "Error: Invalid metadata specified in $metaDataXml"
				Exit
			}

			if ($spCount -gt 0) {
				$samlMetadata += ", "
			}
			$samlMetadata += "{ \'spName\': \'$spName\'"
			$samlMetadata += ","
			$samlMetadata += "\'metadataXml\': \'"
			$samlMetadata += $content
			$samlMetadata += "\'"
			if ($encryptAssertion -ieq "true") {
				$samlMetadata +=", \'encryptAssertion\': \'true\'"
			} else {
				$samlMetadata+=", \'encryptAssertion\': \'false\'"
			}
			$samlMetadata += "}"

			$spCount++
		}

	}
	$samlMetadata += "] }"
	$samlMetadata
}

function GetSsoSamlIdpSetting {
	Param ($settings)
	$uagSsoSamlIdpHostName=$settings.SsoSamlIdpSetting.hostName
	$uagSsoSamlIdpUseHostBasedId=$settings.SsoSamlIdpSetting.useHostBasedId
	$ssoIdpSetting="\'ssoSamlIdpSetting\': {"
	if ($uagSsoSamlIdpHostName.length -gt 0) {
		$hostNameValid = ValidateHostNameOrIP $uagSsoSamlIdpHostName
		if (!$hostNameValid) {
			WriteErrorString "Error: The UAG SSO host name $uagSsoSamlIdpHostName under section SsoSamlIdpSetting is invalid."
			Exit
		}
		$ssoIdpSetting+="\'hostName\': \'$uagSsoSamlIdpHostName\'"
		if ($uagSsoSamlIdpUseHostBasedId -ieq "true") {
			$ssoIdpSetting+=", \'useHostBasedId\': \'true\'"
		} else {
			$ssoIdpSetting+=", \'useHostBasedId\': \'false\'"
		}
	}
	$ssoIdpSetting+="}"
	$ssoIdpSetting
}


function GetSAMLIdentityProviderMetadata {
	Param ($settings)

	$sslCertsFile=$settings.SAMLIdentityProviderMetadata.pemCerts

	if ($sslCertsFile.length -gt 0) {

		if (!(Test-path $sslCertsFile)) {
			WriteErrorString "Error: [SAMLIdentityProviderMetadata] PEM Certificate file not found ($sslCertsFile)"
			Exit
		}

		$rsaPrivKeyFile=$settings.SAMLIdentityProviderMetadata.pemPrivKey

		if ($rsaPrivKeyFile.length -eq 0) {
			WriteErrorString "Error: [SAMLIdentityProviderMetadata] PEM RSA private key file pemPrivKey not specified"
			Exit
		}

		if (!(Test-path $rsaPrivKeyFile)) {
			WriteErrorString "Error: [SAMLIdentityProviderMetadata]PEM RSA private key file not found ($rsaPrivKeyFile)"
			Exit
		}

		#
		# Read the PEM contents and remove any preamble before ----BEGIN
		#

		$sslcerts = (Get-Content $sslCertsFile | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""
		$sslcerts = $sslcerts.Substring($sslcerts.IndexOf("-----BEGIN"))

		if (!($sslcerts -like "*-----BEGIN*")) {
			WriteErrorString "Error: [SAMLIdentityProviderMetadata] Invalid certs PEM file (pemCerts) specified. It must contain a certificate."
			Exit
		}

		$rsaprivkey = (Get-Content $rsaPrivKeyFile | Out-String) -replace "'", "\\047" -replace "`r`n", "\\n" -replace """", ""
		$rsaprivkey = $rsaprivkey.Substring($rsaprivkey.IndexOf("-----BEGIN"))

		if ($rsaprivkey -like "*-----BEGIN RSA PRIVATE KEY-----*") {
			if ($isTerraform -ne "true") {
				Write-host "Deployment will use the specified [SAMLIdentityProviderMetadata] certificate and private key"
			}
		} else {
			WriteErrorString "Error: [SAMLIdentityProviderMetadata] Invalid private key PEM file (pemPrivKey) specified. It must contain an RSA private key."
			Exit
		}
	}

	$samlMetadata="\'identityProviderMetaData\': { "

	#
	# If the signing certificate/key is not specified, we use {} which results in a self-signed cert/key being generated by UAG automatically
	#

	if ($sslcerts.length -gt 0) {
		$samlMetadata="\'identityProviderMetaData\': { \'privateKeyPem\': \'"
		$samlMetadata+=$rsaprivkey
		$samlMetadata+="\', \'certChainPem\': \'"
		$samlMetadata+=$sslcerts
		$samlMetadata+="\'"
	}

	$samlMetadata+=" }"

	$samlMetadata
}

function IsPfxPasswordProtected {
	param($sslCertsFilePfx)

	try {
		$response = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -Args $sslCertsFilePfx, '', 'DefaultKeySet'
	} catch {
		if ($_.Exception.InnerException.HResult -eq 0x80070056 -or $_.Exception.InnerException.HResult -eq 0x23076071) { # ERROR_INVALID_PASSWORD
			return $true
		}
	}
	return $false
}

function GetPfxPassword {
	param($sslCertsFilePfx, $section)

	$pwd = ""

	if (IsPfxPasswordProtected $sslCertsFilePfx) {

		$pfxFilename = Split-Path $sslCertsFilePfx -leaf

		while (! $valid) {
			if ( $isTerraform -eq "true") {
				$pwd = $json.($section+"-PfxPassword")
			} else {
				$prompt='Enter the password for the specified [' + $section + '] PFX certificate file '+$pfxFilename+''
				$pwd = Read-Host -assecurestring $prompt
				$pwd = ConvertFromSecureToPlain $pwd
			}
			$valid=1


			try {
				$response = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -Args $sslCertsFilePfx, $pwd
			} catch {
				if ($_.Exception.InnerException.HResult -eq 0x80070056 -or $_.Exception.InnerException.HResult -eq 0x23076071) { # ERROR_INVALID_PASSWORD
					WriteErrorString "Error: Incorrect $section PfxPassword - please try again"
					$valid = 0
				}
			}
		}
	}

	$pwd
}

function isValidPfxFile {
	param($sslCertsFilePfx, $pwd)

	try {
		$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -Args $sslCertsFilePfx, $pwd
	} catch {
		WriteErrorString "Error: The specified PFX certificate file is invalid ($sslCertsFilePfx)"
		return $false
	}

	if (!$cert.HasPrivateKey) {
		WriteErrorString "Error: The specified PFX Certificate file does not contain a private key ($sslCertsFilePfx)"
		return $false
	}

	return $true
}

#
# Processes normal 443 or Admin 9443 cert. Called as:
# GetCertificateWrapper $setings
# or GetCertificateWrapper $setings "Admin"
#

function GetCertificateWrapper {
	Param ($settings, $admin)

	$section="SSLcert" + $admin

	$sslCertsFile=$settings.$section.pemCerts

	$sslCertsFilePfx=$settings.$section.pfxCerts

	if ($sslCertsFile.length -gt 0) {

		if (!(Test-path $sslCertsFile)) {
			WriteErrorString "Error: PEM Certificate file not found ($sslCertsFile)"
			Exit
		}

		$rsaPrivKeyFile=$settings.$section.pemPrivKey

		if ($rsaPrivKeyFile.length -eq 0) {
			WriteErrorString "Error: PEM RSA private key file pemPrivKey not specified"
			Exit
		}

		if (!(Test-path $rsaPrivKeyFile)) {
			WriteErrorString "Error: PEM RSA private key file not found ($rsaPrivKeyFile)"
			Exit
		}

		#
		# Read the PEM contents and remove any preamble before ----BEGIN
		#

		$sslcerts = (Get-Content $sslCertsFile | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""

		$sslcerts = $sslcerts.Substring($sslcerts.IndexOf("-----BEGIN"))

		if (!($sslcerts -like "*-----BEGIN*")) {
			WriteErrorString "Error: Invalid certs PEM file (pemCerts) specified. It must contain a certificate."
			Exit
		}

		$rsaprivkey = (Get-Content $rsaPrivKeyFile | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""

		$rsaprivkey = $rsaprivkey.Substring($rsaprivkey.IndexOf("-----BEGIN"))

		if ($rsaprivkey -like "*-----BEGIN RSA PRIVATE KEY-----*") {
			if ($isTerraform -ne "true") {
				Write-host "Deployment will use the specified SSL/TLS server certificate ($section)"
			}
		} else {
			WriteErrorString "Error: Invalid private key PEM file (pemPrivKey) specified. It must contain an RSA private key."
			Exit
		}
	} elseif ($sslCertsFilePfx.length -gt 0) {
		if (!(Test-path $sslCertsFilePfx)) {
			WriteErrorString "Error: PFX Certificate file not found ($sslCertsFilePfx)"
			Exit
		}

		$sslCertsFilePfx = Resolve-Path -Path $sslCertsFilePfx

		$pfxPassword = GetPfxPassword $sslCertsFilePfx $section

		if (!(isValidPfxFile $sslCertsFilePfx $pfxPassword)) {
			Exit
		}

		$Content = [System.IO.File]::ReadAllBytes($sslCertsFilePfx)
		$sslCertsFilePfxB64 = [System.Convert]::ToBase64String($Content)

		$pfxCertAlias=$settings.$section.pfxCertAlias


	} else {
		if ($isTerraform -ne "true") {
			Write-host "Deployment will use a self-signed SSL/TLS server certificate ($section)"
		}
	}

	if ($sslcerts.length -gt 0) {
		$certificateWrapper="\'certificateWrapper" + $admin + "\': { \'privateKeyPem\': \'"
		$certificateWrapper+=$rsaprivkey
		$certificateWrapper+="\', \'certChainPem\': \'"
		$certificateWrapper+=$sslcerts
		$certificateWrapper+="\' }"
	} elseif ($sslCertsFilePfxB64.length -gt 0) {
		$certificateWrapper="\'pfxCertStoreWrapper" + $admin + "\': { \'pfxKeystore\': \'"
		$certificateWrapper+=$sslCertsFilePfxB64
		$certificateWrapper+="\', \'password\': \'"
		$pfxPassword = $pfxPassword -replace "\\", "\\\\"
		$certificateWrapper+=$pfxPassword
		if ($pfxCertAlias.length -gt 0) {
			$certificateWrapper+="\', \'alias\': \'"
			$certificateWrapper+=$pfxCertAlias
		}
		$certificateWrapper+="\' }"
	}

	$certificateWrapper

}

function GetHorizonCertificatePEM {
	Param ($settings, $HorizonCertificateName)

	$CertificateFile=$settings.Horizon.$HorizonCertificateName

	if ($CertificateFile.length -le 0) {
		return
	}

	if (!(Test-path $CertificateFile)) {
		WriteErrorString "Error: PEM Certificate file not found ($CertificateFile)"
		Exit
	}

	$certificatePEM = (Get-Content $CertificateFile | Out-String) -replace "'", "\\047" -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

	if ($certificatePEM -like "*-----BEGIN CERTIFICATE-----*") {
		if ($isTerraform -ne "true") {
			Write-host "Deployment will use the specified [Horizon] $HorizonCertificateName"
		}
	} else {
		WriteErrorString "Error: Invalid PEM file ([Horizon] $HorizonCertificateName) specified. It must contain -----BEGIN CERTIFICATE-----."
		Exit
	}

	$certificatePEM
}

#
# Process PFX certificate
#

function GetPFXCertificate {
	param($edgeService)

	$pfxCertsFile=$settings.$edgeService.pfxCerts

	if ($pfxCertsFile.length -gt 0) {
		if (!(Test-path $pfxCertsFile)) {
			WriteErrorString "Error: $edgeService PFX Certificate file not found ($pfxCertsFile)"
			Exit
		}

		$pfxCertsFile = Resolve-Path -Path $pfxCertsFile
		$Content = [System.IO.File]::ReadAllBytes($pfxCertsFile)
		$pfxCertsFilePfxB64 = [System.Convert]::ToBase64String($Content)
	}

	$pfxCertsFilePfxB64
}

#
# Horizon View settings
#

function GetEdgeServiceSettingsVIEW
{
	Param ($settings)

	$proxyDestinationUrl = $settings.Horizon.proxyDestinationUrl
	if ($proxyDestinationUrl.length -gt 0)
	{
		$proxyDestinationUrl = ValidateWebURIAndPromptForCorrection $proxyDestinationUrl 'Horizon > proxyDestinationUrl' $false
	}

	#
	# Strip the final :443 if specified as that is the default anyway
	#
	if ($proxyDestinationUrl.length -gt 0 -And $proxyDestinationUrl.Substring($proxyDestinationUrl.length - 4, 4) -eq ":443")
	{
		$proxyDestinationUrl = $proxyDestinationUrl.Substring(0,$proxyDestinationUrl.IndexOf(":443"))
	}

	$proxyDestinationUrlThumbprints = $settings.Horizon.proxyDestinationUrlThumbprints

	# Remove invalid thumbprint characters
	$proxyDestinationUrlThumbprints = SanitizeThumbprints $proxyDestinationUrlThumbprints

	$blastExternalUrl = $settings.Horizon.blastExternalUrl
	$blastInternalUrl = $settings.Horizon.blastInternalUrl

	$pcoipExternalUrl = $settings.Horizon.pcoipExternalUrl
	if ($pcoipExternalUrl.length -gt 0)
	{
		if (([regex]"[.]").Matches($pcoipExternalUrl).Count -ne 3)
		{
			WriteErrorString "Error: Invalid pcoipExternalUrl value specified ($pcoipExternalUrl). It must contain an IPv4 address."
			Exit
		}
	}

	$tunnelExternalUrl = $settings.Horizon.tunnelExternalUrl

	# if none of proxy destination url and blast/pcopip/tunnel urls are set then we return. If any one of these are set then we continue enabling the horizon
	# setting!!
	if ($proxyDestinationUrl.length -le 0 -And $pcoipExternalUrl.length -le 0 -And $blastExternalUrl.length -le 0  -And $blastInternalUrl.length -le 0 -And $tunnelExternalUrl.length -le 0) {
		return
	}

	$edgeServiceSettingsVIEW += "{ \'identifier\': \'VIEW\'"
	$edgeServiceSettingsVIEW += ","
	$edgeServiceSettingsVIEW += "\'enabled\': true"
	if ($proxyDestinationUrl.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'proxyDestinationUrl\': \'" + $proxyDestinationUrl + "\'"
	}
	if ($proxyDestinationUrlThumbprints.length -gt 0) {
		if ($proxyDestinationUrl.length -le 0) {
			WriteErrorString "Error: Cannot set proxyDestinationUrlThumbprints without proxy destination"
			Exit
		}
	}

	$xmlSigningSwitch = $settings.Horizon.xmlSigningSwitch
	if ($xmlSigningSwitch.length -eq 0) {	# set default to AUTO
		$xmlSigningSwitch = "AUTO"
	} else {
		$xmlSigningSwitch = $xmlSigningSwitch.ToUpper();
	}

	if (($xmlSigningSwitch -eq "AUTO") -or ($xmlSigningSwitch -eq "ON") -or ($xmlSigningSwitch -eq "OFF")) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += " \'xmlSigningSwitch\': \'" + $xmlSigningSwitch + "\'"
	} else {
		WriteErrorString "Error: xmlSigningSwitch field can be set to AUTO, ON or OFF"
		CleanExit
	}

	$privateKeyPem = $settings.Horizon.privateKeyPem
	$certChainPem = $settings.Horizon.certChainPem
	$pfxKeystore = $settings.Horizon.pfxKeystore
	if ($certChainPem.length -gt 0) {

		if ($privateKeyPem.length -eq 0) {
			WriteErrorString "Error: XML API Signing PEM private key file privateKeyPem not specified"
			CleanExit
		}

		$privateKeyPemContent = GetPEMPrivateKeyContent $privateKeyPem "privateKeyPem"
		$certChainContent = GetPEMCertificateContent $certChainPem "certChainPem"

		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += " \'xmlSigningPemCertSettings\': {"
		$edgeServiceSettingsVIEW += ( "\'privateKeyPem\': \'" + $privateKeyPemContent + "\', \'certChainPem\': \'" + $certChainContent +"\'")
		$edgeServiceSettingsVIEW += "}"

	}
	elseif ($pfxKeystore.length -gt 0) {

		if (!(Test-path $pfxKeystore)) {
			WriteErrorString "Error: PFX Certificate file not found ($pfxKeystore)"
			CleanExit
		}

		$pfxKeystore = Resolve-Path -Path $pfxKeystore

		$pfxPassword = GetPfxPassword $pfxKeystore Horizon

		if (!(isValidPfxFile $pfxKeystore $pfxPassword)) {
			CleanExit
		}

		$Content = [System.IO.File]::ReadAllBytes($pfxKeystore)
		$certsFilePfxB64 = [System.Convert]::ToBase64String($Content)

		$pfxCertAlias=$settings.Horizon.pfxCertAlias
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += " \'xmlSigningPfxCertSettings\': {"
		$edgeServiceSettingsVIEW +=  ( "\'pfxKeystore\': \'" + $certsFilePfxB64 + "\', \'password\': \'" + $pfxPassword )
		if ($pfxCertAlias.length -gt 0) {
			$edgeServiceSettingsVIEW += "\', \'alias\': \'"
			$edgeServiceSettingsVIEW += $pfxCertAlias
		}
		$edgeServiceSettingsVIEW += "\' }"

	}



	if ($pcoipExternalUrl.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'pcoipEnabled\':true"
		if ($settings.Horizon.pcoipDisableLegacyCertificate -eq "true") {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'pcoipDisableLegacyCertificate\': true"
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'pcoipExternalUrl\': \'"+$pcoipExternalUrl+"\'"
	} else {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'pcoipEnabled\':false"
	}

	if (($blastExternalUrl.length -gt 0 ) -or ($blastInternalUrl.length -gt 0)) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'blastEnabled\':true"

		if ($blastExternalUrl.length -gt 0) {
			$blastExternalUrl = ValidateWebURIOrHostPortAndPromptForCorrection $blastExternalUrl "Horizon > blastExternalUrl" $false
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastExternalUrl\': \'"+$blastExternalUrl+"\'"
		}

		if ($blastInternalUrl.length -gt 0) {
			$blastInternalUrl = ValidateWebURIOrHostPortAndPromptForCorrection $blastInternalUrl "Horizon > blastInternalUrl" $false
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastInternalUrl\': \'"+$blastInternalUrl+"\'"
		}

		$blastUrls = $settings.Horizon.additionalBlastExternalUrls
		if ($blastUrls.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastUrls\': \'"+$blastUrls+"\'"
		}

		$proxyBlastPemCert = GetHorizonCertificatePEM $settings "proxyBlastPemCert"
		if ($proxyBlastPemCert.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyBlastPemCert\': \'"+$proxyBlastPemCert+"\'"
		}
		$blastAllowedHostHeaderValues = $settings.Horizon.blastAllowedHostHeaderValues
		if ($blastAllowedHostHeaderValues.length -gt 0) {
			$blastAllowedHostHeaderValues = ValidateBlastAllowedHostHeaderValuesAndPromptForCorrection $blastAllowedHostHeaderValues
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastAllowedHostHeaderValues\': \'"+$blastAllowedHostHeaderValues+"\'"
		}
		$proxyBlastSHA1Thumbprint=$settings.Horizon.proxyBlastSHA1Thumbprint
		if ($proxyBlastSHA1Thumbprint.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyBlastSHA1Thumbprint\': \'"+$proxyBlastSHA1Thumbprint+"\'"
		}
		$proxyBlastSHA256Thumbprint=$settings.Horizon.proxyBlastSHA256Thumbprint
		if ($proxyBlastSHA256Thumbprint.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyBlastSHA256Thumbprint\': \'"+$proxyBlastSHA256Thumbprint+"\'"
		}

		$global:blastReverseExternalUrlPort="0"
		$blastReverseExternalUrlInside = $settings.Horizon.blastReverseExternalUrlInside
		if ($blastReverseExternalUrlInside.length -gt 0) {
			$blastReverseExternalUrlInside = ValidateBlastReverseExternalUrl $blastReverseExternalUrlInside "Horizon > blastReverseExternalUrlInside"
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastReverseExternalUrlInside\': \'"+$blastReverseExternalUrlInside+"\'"
		}

		$blastReverseExternalUrlOutside = $settings.Horizon.blastReverseExternalUrlOutside
		if ($blastReverseExternalUrlOutside.length -gt 0) {
			$blastReverseExternalUrlOutside = ValidateBlastReverseExternalUrl $blastReverseExternalUrlOutside "Horizon > blastReverseExternalUrlOutside"
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastReverseExternalUrlOutside\': \'"+$blastReverseExternalUrlOutside+"\'"
		}

		$blastReverseJwtIssuer = $settings.Horizon.jwtIssuerSettings

		if ($blastReverseExternalUrlOutside.length -gt 0 -Or $blastReverseExternalUrlInside.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'blastReverseConnectionEnabled\': true"
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'jwtIssuerSettings\': \'"+$blastReverseJwtIssuer+"\'"
		}
	} else {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'blastEnabled\':false"
	}

	$blastSettings = "Horizon/Blast"
	$subSettings = $settings.$blastSettings
	if ($subSettings.length -gt 0) {
		$viewBlastSettings = GetHorizonBlastSettings $settings
		if ($viewBlastSettings.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += $viewBlastSettings
		}
	}

	if ($settings.Horizon.udpTunnelServerEnabled -eq "false") {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'udpTunnelServerEnabled\':false"
	}

	if ($tunnelExternalUrl.length -gt 0) {
		$tunnelExternalUrl = ValidateWebURIOrHostPortAndPromptForCorrection $tunnelExternalUrl "Horizon > tunnelExternalUrl" $false
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'tunnelEnabled\':true"
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'tunnelExternalUrl\': \'"+$tunnelExternalUrl+"\'"
		$proxyTunnelPemCert = GetHorizonCertificatePEM $settings "proxyTunnelPemCert"
		if ($proxyTunnelPemCert.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyTunnelPemCert\': \'"+$proxyTunnelPemCert+"\'"
		}
		$tunnelUrls = $settings.Horizon.additionalTunnelExternalUrls
		if ($tunnelUrls.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'tunnelUrls\': \'"+$tunnelUrls+"\'"
		}
		$proxyTunnelSHA1Thumbprint=$settings.Horizon.proxyTunnelSHA1Thumbprint
		if ($proxyTunnelSHA1Thumbprint.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyTunnelSHA1Thumbprint\': \'"+$proxyTunnelSHA1Thumbprint+"\'"
		}
		$proxyTunnelSHA256Thumbprint=$settings.Horizon.proxyTunnelSHA256Thumbprint
		if ($proxyTunnelSHA256Thumbprint.length -gt 0) {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyTunnelSHA256Thumbprint\': \'"+$proxyTunnelSHA256Thumbprint+"\'"
		}
	} else {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'tunnelEnabled\':false"
	}

	if (($settings.Horizon.trustedCert1.length -gt 0) -Or (($settings.Horizon.hostEntry1.length -gt 0))) {

		$edgeServiceSettingsVIEW += ","
		$trustedCertificates = GetTrustedCertificates "Horizon" "trustedCert" "trustedCertificates"
		$edgeServiceSettingsVIEW += $trustedCertificates

		$edgeServiceSettingsVIEW += ","
		$hostEntries = GetHostEntries "Horizon"
		$edgeServiceSettingsVIEW += $hostEntries
	}

	if ($settings.Horizon.proxyPattern.length -gt 0) {
		if ($proxyDestinationUrl.length -le 0) {
			WriteErrorString "Error: Cannot set proxy pattern without proxy destination"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$settings.Horizon.proxyPattern = $settings.Horizon.proxyPattern -replace "\\", "\\\\"
		$edgeServiceSettingsVIEW += "\'proxyPattern\': \'"+$settings.Horizon.proxyPattern+"\'"
	} Elseif ($proxyDestinationUrl.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'proxyPattern\':\'(/|/view-client(.*)|/portal(.*)|/appblast(.*)|/iwa(.*))\'"
	}

	$canonicalizationEnabled=$settings.Horizon.canonicalizationEnabled
	if ($null -ne $canonicalizationEnabled )
	{
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'canonicalizationEnabled\': \'" + $canonicalizationEnabled + "\'"
	}

	$authMethods=$settings.Horizon.authMethods
	$enableAuthOnRedirectedSite = $settings.Horizon.enableAuthOnRedirectedSite
	if ($authMethods.length -gt 0)
	{
		if ($proxyDestinationUrl.length -le 0)
		{
			WriteErrorString "Error: Cannot set auth methods without proxy destination"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'authMethods\': \'"+$authMethods+"\'"
	}

	$samlSP=$settings.Horizon.samlSP
	if ($samlSP.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'samlSP\': \'"+$samlSP+"\'"
	}

	if ($settings.Horizon.enableAuthOnRedirectedSite -eq "true") {
		if ($authMethods.length -le 0 -or $authMethods -eq "sp-auth" -or $authMethods -like "*saml-auth*" -or $authMethods -like "*oidc-auth*" -or $authMethods -like "*unauthenticated*") {
			WriteErrorString "Error: Cannot set 'enableAuthOnRedirectedSite' to true with the following values of 'authMethods' :"
			WriteErrorString "1) not specified"
			WriteErrorString "2) specified as 'sp-auth'"
			WriteErrorString "3) containing 'saml-auth'"
			WriteErrorString "4) containing 'unauthenticated'"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'enableAuthOnRedirectedSite\': true"
	} elseif ($authMethods -like "*certificate-auth*" -And $samlSP.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'enableAuthOnRedirectedSite\': true"
	}

	$windowsSSOEnabled=$settings.Horizon.windowsSSOEnabled
	if ($windowsSSOEnabled.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'windowsSSOEnabled\': "+$windowsSSOEnabled
	}

	$matchWindowsUserName=$settings.Horizon.matchWindowsUserName
	if ($matchWindowsUserName.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'matchWindowsUserName\': "+$matchWindowsUserName
	}

	$oidcConfigurationId=$settings.Horizon.oidcConfigurationId
	if ($oidcConfigurationId.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'oidcConfigurationId\': \'"+$oidcConfigurationId+"\'"
	}

	$proxyDestinationPreLoginMessageEnabled=$settings.Horizon.proxyDestinationPreLoginMessageEnabled
	if ($proxyDestinationPreLoginMessageEnabled.length -gt 0) {
		if ($proxyDestinationPreLoginMessageEnabled -eq "false" -Or $proxyDestinationPreLoginMessageEnabled -eq "true") {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyDestinationPreLoginMessageEnabled\': \'"+$proxyDestinationPreLoginMessageEnabled+"\'"
		} else {
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'proxyDestinationPreLoginMessageEnabled\': \'true\'"
			WriteErrorString ": Allowed values for proxyDestinationPreLoginMessageEnabled flag can be true or false, setting to default value true."
		}
	}

	$rewriteOriginHeader=$settings.Horizon.rewriteOriginHeader
	if ($rewriteOriginHeader.length -gt 0) {
		if ($proxyDestinationUrl.length -le 0 -And $rewriteOriginHeader -eq "true") {
			WriteErrorString "Error: Cannot enable rewrite origin header without proxy destination"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'rewriteOriginHeader\': "+$rewriteOriginHeader
	}

	$endpointComplianceCheckProvider=$settings.Horizon.endpointComplianceCheckProvider
	if ($endpointComplianceCheckProvider.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'devicePolicyServiceProvider\': \'"+$endpointComplianceCheckProvider+"\'"
	}

	$complianceCheckOnAuthentication=$settings.Horizon.complianceCheckOnAuthentication
	if ($complianceCheckOnAuthentication -ieq "false" ) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'complianceCheckOnAuthentication\': \'"+$complianceCheckOnAuthentication+"\'"
	} else {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'complianceCheckOnAuthentication\': \'true\'"
	}

	if ($settings.Horizon.securityHeaders.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$securityHeaders = $settings.Horizon.securityHeaders
		$securityHeaders = $securityHeaders -replace "'", "\\047"
		$edgeServiceSettingsVIEW += "\'securityHeaders\': "+$securityHeaders
	}

	if ($settings.Horizon.radiusClassAttributeList.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'radiusClassAttributeList\': \'"+$settings.Horizon.radiusClassAttributeList+"\'"
	}

	if ($settings.Horizon.disclaimerText.length -gt 0) {
		$settings.Horizon.disclaimerText = $settings.Horizon.disclaimerText -replace "\\\\","\" -replace "'","\\047" -replace '\"','\\\"' -replace "\\n","\\n"
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'disclaimerText\': \'"+$settings.Horizon.disclaimerText+"\'"
	}

	$csIPMode=$settings.Horizon.proxyDestinationIPSupport
	if ($csIPMode.length -gt 0) {
		if ($csIPMode -ne "IPV4" -And $csIPMode -ne "IPV6" -And $csIPMode -ne "IPV4_IPV6") {
			WriteErrorString "Error: Invalid proxyDestinationIPSupport value specified. It can be IPV4 or IPV6 or IPV4_IPV6"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'proxyDestinationIPSupport\': \'"+$csIPMode.ToUpper()+"\'"
	}

	$clientEncryptionMode=GetClientEncryptionMode $settings
	if ($clientEncryptionMode.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'clientEncryptionMode\': \'"+$clientEncryptionMode+"\'"
	}

	if ($settings.Horizon.redirectHostMappingList.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'redirectHostMappingList\': \'"+$settings.Horizon.redirectHostMappingList+"\'"
	}

	if ($settings.Horizon.redirectHostPortMappingList.length -gt 0) {
		$redirectHostPortMappingList = ValidateRedirectHostPortMappingListAndPromptForCorrection $settings.Horizon.redirectHostPortMappingList "Horizon > redirectHostPortMappingList"
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'redirectHostPortMappingList\': \'"+$redirectHostPortMappingList+"\'"
	}

	if ($settings.Horizon.idpEntityID.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'idpEntityID\': \'"+$settings.Horizon.idpEntityID+"\'"
	}

	if ($settings.Horizon.allowedAudiences.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'allowedAudiences\': \'"+$settings.Horizon.allowedAudiences+"\'"
	}

	$radiusLabelMaxLength = 20

	if ($settings.Horizon.radiusUsernameLabel.length -gt 0) {
		ValidateLabelLength radiusUsernameLabel $settings.Horizon.radiusUsernameLabel $radiusLabelMaxLength
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'radiusUsernameLabel\': \'"+$settings.Horizon.radiusUsernameLabel+"\'"
	}

	if ($settings.Horizon.radiusPasscodeLabel.length -gt 0) {
		ValidateLabelLength radiusPasscodeLabel $settings.Horizon.radiusPasscodeLabel $radiusLabelMaxLength
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'radiusPasscodeLabel\': \'"+$settings.Horizon.radiusPasscodeLabel+"\'"
	}

	if ($settings.Horizon.hostRedirectionEnabled -eq "true") {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'hostRedirectionEnabled\':true"
	}

	if ($settings.Horizon.jwtSettings.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'jwtSettings\': \'"+$settings.Horizon.jwtSettings+"\'"

		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'jwtAudiences\': [ "

		$icount = 0
		for ($i=1; $i -lt 100; $i++) {
			$jwtAudienceName = "jwtAudience$i"
			if ($settings.Horizon.$jwtAudienceName.length -gt 0) {

				if ($icount -gt 0) {
					$edgeServiceSettingsVIEW += ","
				}
				$icount++
				$edgeServiceSettingsVIEW += "\'"+$settings.Horizon.$jwtAudienceName+"\'"
			}
		}
		$edgeServiceSettingsVIEW += " ]"
	}

	if ($settings.Horizon.logoutOnCertRemoval -eq "true") {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'logoutOnCertRemoval\': true"
	}

	if ($settings.Horizon.samlUnauthUsernameAttribute.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'samlUnauthUsernameAttribute\': \'"+$settings.Horizon.samlUnauthUsernameAttribute+"\'"
	}

	if ($settings.Horizon.defaultUnauthUsername.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'defaultUnauthUsername\': \'"+$settings.Horizon.defaultUnauthUsername+"\'"
	}

	if ($settings.Horizon.gatewayLocation.length -gt 0) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'gatewayLocation\': \'"+$settings.Horizon.gatewayLocation+"\'"
	}

	$edgeServiceSettingsVIEW += ","
	$edgeServiceSettingsVIEW += "\'customExecutableList\': "+(readContentList $settings.Horizon "customExecutable")

	if ($settings.Horizon.foreverAppsEnabled.length -gt 0 ) {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'foreverAppsEnabled\': \'"+$settings.Horizon.foreverAppsEnabled+"\'"
	} else {
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'foreverAppsEnabled\': \'true\'"
	}

	if ($proxyDestinationUrlThumbprints.length -gt 0) {

		if ($settings.Horizon.minSHAHashSize.length -gt 0 ) {
			$minSHAHashSize = $settings.Horizon.minSHAHashSize
			if ($minSHAHashSize -eq "Default") {
				$minSHAHashSize = "SHA-256"
			}
			$minSHAHashSize = ValidateMinSHAHashSize $minSHAHashSize
			$proxyDestinationUrlThumbprints = validateAndUpdateThumbprints $proxyDestinationUrlThumbprints $minSHAHashSize "Horizon"
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'minSHAHashSize\':\'" + $minSHAHashSize + "\'"
		} elseif($settings.General.minSHAHashSize.length -gt 0) {
			$minSHAHashSize = ValidateMinSHAHashSize $settings.General.minSHAHashSize
			$proxyDestinationUrlThumbprints = validateAndUpdateThumbprints $proxyDestinationUrlThumbprints $minSHAHashSize "Horizon"
			$edgeServiceSettingsVIEW += ","
			$edgeServiceSettingsVIEW += "\'minSHAHashSize\':\'" + $minSHAHashSize + "\'"
		}
		else {
			$proxyDestinationUrlThumbprints = validateAndUpdateThumbprints $proxyDestinationUrlThumbprints "SHA-256" "Horizon"
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'proxyDestinationUrlThumbprints\': \'"+$proxyDestinationUrlThumbprints+"\'"
	}

	if (($settings.Horizon.disableHtmlAccess.length -gt 0) -and ($settings.Horizon.disableHtmlAccess.Trim().ToLower() -eq "true")) {
		$edgeServiceSettingsVIEW += ",\'disableHtmlAccess\': true"
	}

	$edgeServiceSettingsVIEW += " }"

	$edgeServiceSettingsVIEW
}

function GetHorizonBlastSettings
{
	param ($settings)
	$iniSection = "Horizon/Blast"
	$HorizonBlastSettings = $settings.$iniSection
	$blastSettings = "\'blastSettings\': { "
	$blastSettings += "\'blastStandardFeatures\': [ "
	$icount = 0
	$availableStandardFeatures = @("Clipboard redirection","MKSVchan", "HTML5/GeoLocation redirection", "html5mmr", "Serial port/Scanner redirection", "NLR3hv;NLW3hv",
	"RdeServer", "VMwareRde;UNITY_UPDATE_CHA", "TSMMR", "tsmmr",
	"Printer redirection", "PrintRedir", "CDR", "tsdr", "USB redirection", "UsbRedirection", "SDRTrans", "Storage Drive Redirection", "TlmStat", "TlmStat Telemetry",
	"VMWscan", "View Scanner", "fido2", "FIDO2 Redirection")
	for ($i = 1; $i -lt 100; $i++) {
		$standardFeatureName = "standardFeature$i"

		if ($HorizonBlastSettings.$standardFeatureName.length -gt 0)
		{
			$standardFeatureName=$HorizonBlastSettings.$standardFeatureName
			if(-not ($standardFeatureName -in  $availableStandardFeatures)){
				$featuresList = $availableStandardFeatures -join ","
				WriteErrorString "Blast standard feature name '$standardFeatureName' should be one of these:  $featuresList"
				CleanExit
			}
			if ($icount -gt 0)
			{
				$blastSettings += ","
			}
			$icount++
			$blastSettings += "\'" + $standardFeatureName + "\'"
		}
	}
	$blastSettings += " ]"
	$blastSettings += ","
	$blastSettings += "\'blastCustomFeatures\': [ "
	$icount = 0
	for ($i = 1; $i -lt 100; $i++) {
		$customFeatureName = "customFeature$i"
		if ($HorizonBlastSettings.$customFeatureName.length -gt 0)
		{
			if ($icount -gt 0)
			{
				$blastSettings += ","
			}
			$icount++
			$encodedName = stringToBase64($HorizonBlastSettings.$customFeatureName)
			$blastSettings += "\'" + $encodedName + "\'"
		}
	}
	$blastSettings += " ]"
	$blastSettings += " }"

	$blastSettings
}


#
# This function provide the list of string based attributes
#
function readContentList{

	param ($settings, $attributeName)

	$listContent = "["
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "$attributeName$i"
		$value = $settings.$iniGroup
		if ($value.length -eq 0)
		{
			continue
		}
		if($listContent.Length -eq 1){
			$listContent += "\'$value\'";
		}
		else
		{
			$listContent += ",\'$value\'"
		}

	}

	$listContent += "]"

	$listContent
}

#
# Web Reverse Proxy settings
#

function GetEdgeServiceSettingsWRP {
	Param ($settings, $id)

	$WebReverseProxy = "WebReverseProxy"+$id

	$proxyDestinationUrl=$settings.$WebReverseProxy.proxyDestinationUrl

	if ($proxyDestinationUrl.length -le 0) {
		return
	}

	$proxyDestinationUrl = ValidateWebURIAndPromptForCorrection $proxyDestinationUrl "$WebReverseProxy > proxyDestinationUrl" $false

	$edgeServiceSettingsWRP += "{ \'identifier\': \'WEB_REVERSE_PROXY\'"
	$edgeServiceSettingsWRP += ","
	$edgeServiceSettingsWRP += "\'enabled\': true"
	$edgeServiceSettingsWRP += ","

	$instanceId=$settings.$WebReverseProxy.instanceId

	if (!$instanceId) {
		$instanceId=""
	}

	if (!$id) {
		$id=""
	}

	if ($instanceId.length -eq 0) {
		if ($id.length -eq 0) {
			$id="0"
		}
		$instanceId=$id
	}

	$edgeServiceSettingsWRP += "\'instanceId\': \'"+$instanceId+"\'"
	$edgeServiceSettingsWRP += ","

	if (($settings.$WebReverseProxy.trustedCert1.length -gt 0) -Or (($settings.$WebReverseProxy.hostEntry1.length -gt 0))) {

		$trustedCertificates = GetTrustedCertificates $WebReverseProxy "trustedCert" "trustedCertificates"
		$edgeServiceSettingsWRP += $trustedCertificates
		$edgeServiceSettingsWRP += ","

		$hostEntries = GetHostEntries $WebReverseProxy
		$edgeServiceSettingsWRP += $hostEntries
		$edgeServiceSettingsWRP += ","
	}

	$edgeServiceSettingsWRP += "\'proxyDestinationUrl\': \'"+$proxyDestinationUrl+"\'"

	$proxyDestinationUrlThumbprints=$settings.$WebReverseProxy.proxyDestinationUrlThumbprints

	if ($proxyDestinationUrlThumbprints.length -gt 0) {
		# Remove invalid thumbprint characters
		$proxyDestinationUrlThumbprints = SanitizeThumbprints $proxyDestinationUrlThumbprints
		$proxyDestinationUrlThumbprints = validateAndUpdateThumbprints $proxyDestinationUrlThumbprints $settings.General.minSHAHashSize $WebReverseProxy
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'proxyDestinationUrlThumbprints\': \'"+$proxyDestinationUrlThumbprints+"\'"
	}

	if ($settings.$WebReverseProxy.proxyPattern.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$settings.$WebReverseProxy.proxyPattern = $settings.$WebReverseProxy.proxyPattern -replace "\\", "\\\\"
		$edgeServiceSettingsWRP += "\'proxyPattern\': \'"+$settings.$WebReverseProxy.proxyPattern+"\'"
	} else {
		WriteErrorString "Error: Missing proxyPattern in [WebReverseProxy]."
		Exit
	}

	$canonicalizationEnabled=$settings.$WebReverseProxy.canonicalizationEnabled
	if ($canonicalizationEnabled -ne $null )
	{
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'canonicalizationEnabled\': \'" + $canonicalizationEnabled + "\'"
	}

	if ($settings.$WebReverseProxy.unSecurePattern.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'unSecurePattern\': \'"+$settings.$WebReverseProxy.unSecurePattern+"\'"
	}

	if ($settings.$WebReverseProxy.authCookie.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'authCookie\': \'"+$settings.$WebReverseProxy.authCookie+"\'"
	}

	if ($settings.$WebReverseProxy.loginRedirectURL.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'loginRedirectURL\': \'"+$settings.$WebReverseProxy.loginRedirectURL+"\'"
	}

	$authMethods=$settings.$WebReverseProxy.authMethods
	if ($authMethods.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'authMethods\': \'"+$authMethods+"\'"
	}

	if ($settings.$WebReverseProxy.proxyHostPattern.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'proxyHostPattern\': \'"+$settings.$WebReverseProxy.proxyHostPattern+"\'"
	}

	if ($settings.$WebReverseProxy.keyTabPrincipalName.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'keyTabPrincipalName\': \'"+$settings.$WebReverseProxy.keyTabPrincipalName+"\'"
	}

	if ($settings.$WebReverseProxy.targetSPN.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'targetSPN\': \'"+$settings.$WebReverseProxy.targetSPN+"\'"
	}

	if ($settings.$WebReverseProxy.idpEntityID.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'idpEntityID\': \'"+$settings.$WebReverseProxy.idpEntityID+"\'"
	}

	if ($settings.$WebReverseProxy.landingPagePath.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'landingPagePath\': \'"+$settings.$WebReverseProxy.landingPagePath+"\'"
	}

	if ($settings.$WebReverseProxy.userNameHeader.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'userNameHeader\': \'"+$settings.$WebReverseProxy.userNameHeader+"\'"
	}

	if ($settings.$WebReverseProxy.wrpAuthConsumeType.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'wrpAuthConsumeType\': \'"+$settings.$WebReverseProxy.wrpAuthConsumeType+"\'"
	}

	if ($settings.$WebReverseProxy.securityHeaders.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$securityHeaders = $settings.$WebReverseProxy.securityHeaders
		$securityHeaders = $securityHeaders -replace "'", "\\047"
		$edgeServiceSettingsWRP += "\'securityHeaders\': "+$securityHeaders
	}

	if ($settings.$WebReverseProxy.samlAttributeHeaderMap.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'samlAttributeHeaderMap\': "+$settings.$WebReverseProxy.samlAttributeHeaderMap
	}

	if ($settings.$WebReverseProxy.allowedAudiences.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'allowedAudiences\': \'"+$settings.$WebReverseProxy.allowedAudiences+"\'"
	}

	if ($settings.$WebReverseProxy.healthCheckUrl.length -gt 0) {
		$edgeServiceSettingsWRP += ","
		$edgeServiceSettingsWRP += "\'healthCheckUrl\': \'"+$settings.$WebReverseProxy.healthCheckUrl+"\'"
	}

	$edgeServiceSettingsWRP += "}"

	$edgeServiceSettingsWRP
}

#
# Function to prompt the user for an Airwatch password and attempt to validate the input with the
# Airwatch service. If we are not able to validate the password, we allow the user to continue.
# If we positively determine that the password is invalid (Unauthorized), we re-prompt.
#

function GetAirwatchPwd {
	param($apiServerUrl, $apiServerUsername, $organizationGroupCode)

	while (! $valid) {
		if ($organizationGroupCode.length -gt 0) {
			$prompt='Enter the UEM Console '+$apiServerUrl+' password for user "'+$apiServerUsername+'" (group code "'+$organizationGroupCode+'")'
		} else {
			$prompt='Enter the UEM Console '+$apiServerUrl+' password for user "'+$apiServerUsername+'"'
		}
		$pwd = Read-Host -assecurestring $prompt
		if ($pwd.length -eq 0) {
			Continue
		}
		$pwd = ConvertFromSecureToPlain $pwd
		$secpasswd = ConvertTo-SecureString $pwd -AsPlainText -Force
		$cred = New-Object System.Management.Automation.PSCredential ($apiServerUsername, $secpasswd)
		$valid=1
		$uri=$apiServerUrl+"/API/mdm/gateway/configuration?type=VPN&locationgroupcode="+$organizationGroupCode
		try {
			$response = Invoke-RestMethod -Uri $uri -Method "Post"  -Credential $cred -ContentType "application/json" -Body '{"randomString" : "abc123"}'
		} catch {
			if ($_.Exception.Response.StatusCode -eq "Unauthorized") {
				WriteErrorString "Incorrect password"
				$valid=0
			}
		}
	}

	$pwd
}

#
# Airwatch common settings
#

function GetEdgeServiceSettingsAWCommon {
	Param ($settings, $groupName, $pwd)

	$edgeServiceSettingsAWCommon += ","
	$edgeServiceSettingsAWCommon += "\'enabled\': true"
	$edgeServiceSettingsAWCommon += ","
	$edgeServiceSettingsAWCommon += "\'proxyDestinationUrl\': \'https://null\'"
	$edgeServiceSettingsAWCommon += ","
	$apiServerUrl = $settings.$groupName.apiServerUrl
	$apiServerUrl = ValidateWebURIAndPromptForCorrection $apiServerUrl "$groupName > apiServerUrl" $false

	$edgeServiceSettingsAWCommon += "\'apiServerUrl\': \'"+$apiServerUrl+"\'"
	$edgeServiceSettingsAWCommon += ","
	$apiServerUsername = $settings.$groupName.apiServerUsername
	$apiServerUsername = $apiServerUsername -replace '\\', '\\\\'
	$edgeServiceSettingsAWCommon += "\'apiServerUsername\': \'"+$apiServerUsername+"\'"

	if (!$pwd) {
		if ($isTerraform -eq "true") {
			WriteErrorString "Error: UEM console password for $groupName not provided"
		}
		$pwd = GetAirwatchPwd $apiServerUrl $settings.$groupName.apiServerUsername $settings.$groupName.organizationGroupCode
	}
	if ($pwd.length -gt 0) {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'apiServerPassword\': \'"+$pwd+"\'"
	}
	$awServerHostName = ValidateHostPortAndPromptForCorrection $settings.$groupName.airwatchServerHostname "$groupName > airwatchServerHostname"
	$edgeServiceSettingsAWCommon += ","
	$edgeServiceSettingsAWCommon += "\'organizationGroupCode\': \'"+$settings.$groupName.organizationGroupCode+"\'"
	$edgeServiceSettingsAWCommon += ","
	$edgeServiceSettingsAWCommon += "\'airwatchServerHostname\': \'"+$awServerHostName+"\'"
	$edgeServiceSettingsAWCommon += ","

	$edgeServiceSettingsAWCommon += "\'airwatchAgentStartUpMode\': \'install\'"

	if ($settings.$groupName.reinitializeGatewayProcess.length -gt 0) {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'reinitializeGatewayProcess\': \'"+$settings.$groupName.reinitializeGatewayProcess+"\'"
	}

	if ($settings.$groupName.airwatchOutboundProxy -eq "true") {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'airwatchOutboundProxy\': \'true\'"
	}

	if ($settings.$groupName.outboundProxyPort.length -gt 0) {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'outboundProxyPort\': \'"+$settings.$groupName.outboundProxyPort+"\'"
	}

	if ($settings.$groupName.outboundProxyHost.length -gt 0) {
		$outboundProxyHost = ValidateHostPortAndPromptForCorrection $settings.$groupName.outboundProxyHost "$groupName > outboundProxyHost"
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'outboundProxyHost\': \'"+$outboundProxyHost+"\'"
	}

	if ($settings.$groupName.outboundProxyUsername.length -gt 0) {
		$edgeServiceSettingsAWCommon += ","
		$outboundProxyUsername = $settings.$groupName.outboundProxyUsername
		$outboundProxyUsername = $outboundProxyUsername -replace "\\", "\\\\"
		$edgeServiceSettingsAWCommon += "\'outboundProxyUsername\': \'"+$outboundProxyUsername+"\'"

		if ( $isTerraform -eq "true") {
			$pwd = $json.($groupName+"-OutboundProxyPassword")
		} else {
			$pwd = Read-Host -assecurestring "Enter the password for the Tunnel outbound proxy server"
			$pwd = ConvertFromSecureToPlain $pwd
		}
		if ($pwd.length -gt 0) {
			$edgeServiceSettingsAWCommon += ","
			$edgeServiceSettingsAWCommon += "\'outboundProxyPassword\': \'"+$pwd+"\'"
		}
	}

	if ($settings.$groupName.disableAutoConfigUpdate -eq "true") {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'disableAutoConfigUpdate\': \'true\'"
	}

	if ($settings.$groupName.ntlmAuthentication.length -gt 0) {
		$edgeServiceSettingsAWCommon += ","
		$edgeServiceSettingsAWCommon += "\'ntlmAuthentication\': \'"+$settings.$groupName.ntlmAuthentication+"\'"
	}

	$edgeServiceSettingsAWCommon
}

#
# Airwatch Tunnel Gateway settings
#

function GetEdgeServiceSettingsAWTGateway {
	Param ($settings, $groupName, $edgeServiceSettingsAWCommon)

	$edgeServiceSettingsAWTGateway += "{ \'identifier\': \'TUNNEL_GATEWAY\'"
	$edgeServiceSettingsAWTGateway += ","
	$edgeServiceSettingsAWTGateway += "\'airwatchComponentsInstalled\':\'TUNNEL\'"
	$edgeServiceSettingsAWTGateway += $edgeServiceSettingsAWCommon

	if ($settings.$groupName.tunnelConfigurationId.length -eq 0 -And $settings.$groupName.organizationGroupCode.length -eq 0) {
		WriteErrorString "Either Organization Group ID or Tunnel Configuration ID is required."
		Exit
	}

	if (($settings.$groupName.trustedCert1.length -gt 0) -Or (($settings.$groupName.hostEntry1.length -gt 0))) {
		$trustedCertificates = GetTrustedCertificates $groupName "trustedCert" "trustedCertificates"
		$edgeServiceSettingsAWTGateway += ","
		$edgeServiceSettingsAWTGateway += $trustedCertificates

		$hostEntries = GetHostEntries $groupName
		$edgeServiceSettingsAWTGateway += ","
		$edgeServiceSettingsAWTGateway += $hostEntries
	}
	if ($settings.$groupName.tunnelConfigurationId.length -gt 0) {
		$edgeServiceSettingsAWTGateway += ","
		$edgeServiceSettingsAWTGateway += "\'tunnelConfigurationId\': \'"+$settings.$groupName.tunnelConfigurationId+"\'"
	}
	$edgeServiceSettingsAWTGateway += "}"

	$edgeServiceSettingsAWTGateway
}

#
# Airwatch CG settings
#

function GetEdgeServiceSettingsAWCG {
	Param ($settings, $groupName, $edgeServiceSettingsAWCommon)

	$edgeServiceSettingsAWCG += "{ \'identifier\': \'CONTENT_GATEWAY\'"
	$edgeServiceSettingsAWCG += ","
	$edgeServiceSettingsAWCG += "\'airwatchComponentsInstalled\':\'CG\'"
	$edgeServiceSettingsAWCG += $edgeServiceSettingsAWCommon

	if ($settings.$groupName.cgConfigId.length -gt 0) {
		$edgeServiceSettingsAWCG += ","
		$edgeServiceSettingsAWCG += "\'cgConfigurationId\': \'"+$settings.$groupName.cgConfigId+"\'"
	}

	if (($settings.$groupName.trustedCert1.length -gt 0) -Or (($settings.$groupName.hostEntry1.length -gt 0))) {
		$trustedCertificates = GetTrustedCertificates $groupName "trustedCert" "trustedCertificates"
		$edgeServiceSettingsAWCG += ","
		$edgeServiceSettingsAWCG += $trustedCertificates

		$hostEntries = GetHostEntries $groupName
		$edgeServiceSettingsAWCG += ","
		$edgeServiceSettingsAWCG += $hostEntries
	}

	$edgeServiceSettingsAWCG += "}"

	$edgeServiceSettingsAWCG
}

#
# Airwatch SEG settings
#

function GetEdgeServiceSettingsAWSEG {
	Param ($settings, $groupName, $edgeServiceSettingsAWCommon)

	$edgeServiceSettingsAWSEG += "{ \'identifier\': \'SEG\'"
	$edgeServiceSettingsAWSEG += ","
	$edgeServiceSettingsAWSEG += "\'airwatchComponentsInstalled\':\'SEG\'"
	$edgeServiceSettingsAWSEG += $edgeServiceSettingsAWCommon

	if ($settings.$groupName.memConfigurationId.length -gt 0) {
		$edgeServiceSettingsAWSEG += ","
		$edgeServiceSettingsAWSEG += "\'memConfigurationId\': \'"+$settings.$groupName.memConfigurationId+"\'"
	}

	if (($settings.$groupName.trustedCert1.length -gt 0) -Or (($settings.$groupName.hostEntry1.length -gt 0))) {
		$trustedCertificates = GetTrustedCertificates $groupName "trustedCert" "trustedCertificates"
		$edgeServiceSettingsAWSEG += ","
		$edgeServiceSettingsAWSEG += $trustedCertificates

		$hostEntries = GetHostEntries $groupName
		$edgeServiceSettingsAWSEG += ","
		$edgeServiceSettingsAWSEG += $hostEntries
	}


	if ($settings.$groupName.pfxCerts.length -gt 0) {
		$pfxCertificate = GetPFXCertificate  $groupName
		$edgeServiceSettingsAWSEG += ","
		$edgeServiceSettingsAWSEG += "\'pfxCerts\': \'"+$pfxCertificate+"\'"

		$pfxCertificatePassword = GetPfxPassword $settings.$groupName.pfxCerts  $groupName
		$edgeServiceSettingsAWSEG += ","
		$edgeServiceSettingsAWSEG += "\'pfxCertsPassword\': \'"+$pfxCertificatePassword+"\'"

		$pfxCertAlias=$settings.$groupName.pfxCertAlias
		if ($pfxCertAlias.length -gt 0) {
			$edgeServiceSettingsAWSEG += ","
			$edgeServiceSettingsAWSEG += "\'pfxCertAlias\': \'"+$pfxCertAlias+"\'"
		}
	}

	$edgeServiceSettingsAWSEG += "}"

	$edgeServiceSettingsAWSEG
}

function ValidateFileWithExtension {
	param ($file, $extn, $type)

	if ($file.length -gt 0) {
		if (!(Test-path $file)) {
			WriteErrorString "Error: ($file) file not found"
			Exit
		}else{
			$extension = [IO.Path]::GetExtension($file)
			if ($extension -ne $extn )
			{
				WriteErrorString "Error:Please provide valid $type file with extension ($extn)"
				Exit
			}

		}
	}
}

function GetAuthMethodSettingsCertificate {
	Param ($settings)

	$CertificateAuthCertsFile=$settings.CertificateAuth.pemCerts

	if ($CertificateAuthCertsFile.length -le 0) {
		return
	}

	if (!(Test-path $CertificateAuthCertsFile)) {
		WriteErrorString "Error: PEM Certificate file not found ($CertificateAuthCertsFile)"
		Exit
	}

	$CertificateAuthCerts = (Get-Content $CertificateAuthCertsFile | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

	if ($CertificateAuthCerts -like "*-----BEGIN CERTIFICATE-----*") {
		if ($isTerraform -ne "true") {
			Write-host "Deployment will use the specified Certificate Auth PEM file"
		}
	} else {
		WriteErrorString "Error: Invalid PEM file ([CertificateAuth] pemCerts) specified. It must contain -----BEGIN CERTIFICATE-----."
		Exit
	}

	$authMethodSettingsCertificate += "{ \'name\': \'certificate-auth\'"
	$authMethodSettingsCertificate += ","
	$authMethodSettingsCertificate += "\'enabled\': true"

	if ($settings.CertificateAuth.enableCertRevocation -eq "true") {
		$crlEnabled="false"
		$ocspEnabled="false"
		if ($settings.CertificateAuth.enableCertCRL -eq "true") {
			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'enableCertCRL\': \'true\'"
			$crlEnabled="true"
		} else {
			# We have to set enableCertCRL as false if not set by user. Else auth broker sets it to true by default and it may fail
			# in runtime if the certificate does not have a CRL!!
			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'enableCertCRL\': \'false\'"
		}

		if ($settings.CertificateAuth.crlLocation.length -gt 0) {
			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'crlLocation\': \'"+$settings.CertificateAuth.crlLocation+"\'"
			$crlEnabled="true"
		}

		# Not used by authbroker anymore. However having this in case script used with older ova's.
		if ($settings.CertificateAuth.crlCacheSize.length -gt 0) {
			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'crlCacheSize\': \'"+$settings.CertificateAuth.crlCacheSize+"\'"
		}

		if ($settings.CertificateAuth.enableOCSP -eq "true") {
			$ocspEnabled="true"
			$ocspURLSource = GetOCSPUrlSource($settings)

			if ($settings.CertificateAuth.enableOCSPCRLFailover -eq "true")
			{
				if ($crlEnabled -eq "false") {
					WriteErrorString "CRL should be setup to enable OCSP to CRL failover"
					Exit
				}
				$authMethodSettingsCertificate += ","
				$authMethodSettingsCertificate += "\'enableOCSPCRLFailover\': \'true\'"
			} else {
				# We have to set enableOCSPCRLFailover as false if not set by user. Else auth broker sets it to true by default and it will fail
				# during configuration or runtime if the certificate does not have a CRL or CRL settings not configured!!
				$authMethodSettingsCertificate += ","
				$authMethodSettingsCertificate += "\'enableOCSPCRLFailover\': \'false\'"
			}

			if ($settings.CertificateAuth.sendOCSPNonce -eq "true")
			{
				$authMethodSettingsCertificate += ","
				$authMethodSettingsCertificate += "\'sendOCSPNonce\': \'true\'"
			}

			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'enableOCSP\': \'true\'"
			$authMethodSettingsCertificate += ","
			$authMethodSettingsCertificate += "\'ocspURLSource\': \'"+$ocspURLSource+"\'"

			if ($settings.CertificateAuth.ocspURL.length -gt 0) {
				$ocspURL = ValidateWebURIAndPromptForCorrection $settings.CertificateAuth.ocspURL "CertificateAuth > ocspURL" $false
				$authMethodSettingsCertificate += ","
				$authMethodSettingsCertificate += "\'ocspURL\': \'"+$ocspURL+"\'"
			}

		}
		if ($crlEnabled -eq "false" -And $ocspEnabled -eq "false") {
			WriteErrorString "Enable either CRL or OCSP to enable cert revocation check"
			Exit
		}
		$authMethodSettingsCertificate += ","
		$authMethodSettingsCertificate += "\'enableCertRevocation\': \'true\'"
	}

	$authMethodSettingsCertificate += ","
	$authMethodSettingsCertificate += "\'caCertificates\': \'"
	$authMethodSettingsCertificate += $CertificateAuthCerts
	$authMethodSettingsCertificate += "\'"
	$authMethodSettingsCertificate += "}"

	$authMethodSettingsCertificate
}

function GetAuthMethodSettingsSecurID {
	Param ($settings)

	#New Authbroker settings v21.11
	$securidServerConfigFile=$settings.SecurIDAuth.serverConfigFile
	$serverHostnameRest=$settings.SecurIDAuth.serverHostname
	if ($serverHostnameRest.length -gt 0) {

		$authMethodSettingsSecurID += "{ \'name\': \'securid-auth\'"
		$authMethodSettingsSecurID += ","
		$authMethodSettingsSecurID += "\'enabled\': true"



		$hostname=$settings.SecurIDAuth.hostname
		if ($hostname.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$hostname = ValidateHostPortAndPromptForCorrection $hostname "SecurIDAuth > hostname"
			$authMethodSettingsSecurID += "\'hostname\':  \'"+$hostname+"\'"
		}

		if ($serverHostnameRest.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$serverHostnameRest = ValidateHostPortAndPromptForCorrection $serverHostnameRest "SecurIDAuth > serverHostnameRest"
			$authMethodSettingsSecurID += "\'serverHostnameRest\':  \'"+$serverHostnameRest+"\'"
		}

		$serverPortRest=$settings.SecurIDAuth.serverPort
		$authMethodSettingsSecurID += ","
		$validPort = ValidatePort $serverPortRest
		if ($serverPortRest.length -gt 0 -And $validPort -eq "true") {
			$authMethodSettingsSecurID += "\'serverPortRest\':  \'"+$serverPortRest+"\'"
		} else {
			$authMethodSettingsSecurID += "\'serverPortRest\': \'5555\'"
		}

		$accessKeyRest=$settings.SecurIDAuth.accessKey
		if ($accessKeyRest.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$authMethodSettingsSecurID += "\'accessKeyRest\':  \'"+$accessKeyRest+"\'"
		}

		$certificateRestPath=$settings.SecurIDAuth.pemCerts
		if ($certificateRestPath.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$certificateRest = GetPEMCertificateContent $certificateRestPath "certificateRest"
			$authMethodSettingsSecurID += "\'certificateRest\':  \'"+$certificateRest+"\'"
		}

		$authenticationTimeoutRest=$settings.SecurIDAuth.authenticationTimeout
		$authMethodSettingsSecurID += ","
		$validAttemptTimeout = ValidateNumber ($authenticationTimeoutRest)
		if ($authenticationTimeoutRest.length -gt 0 -And $validAttemptTimeout -eq "true") {
			$authMethodSettingsSecurID += "\'authenticationTimeoutRest\':  \'"+$authenticationTimeoutRest+"\'"
		} else {
			$authMethodSettingsSecurID += "\'authenticationTimeoutRest\': \'180\'"
		}

		$nameIdSuffix=$settings.SecurIDAuth.nameIdSuffix
		if ($nameIdSuffix.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$authMethodSettingsSecurID += "\'nameIdSuffix\':  \'"+$nameIdSuffix+"\'"
		}

		$authMethodSettingsSecurID += "}"
	}

	#Old Authbroker Settings v21.06
	elseif ($securidServerConfigFile.length -gt 0) {

		if (!(Test-path $securidServerConfigFile)) {
			WriteErrorString "Error: SecurID config file not found ($securidServerConfigFile)"
			Exit
		}

		$Content = [System.IO.File]::ReadAllBytes($securidServerConfigFile)
		$securidServerConfigB64 = [System.Convert]::ToBase64String($Content)

		$authMethodSettingsSecurID += "{ \'name\': \'securid-auth\'"
		$authMethodSettingsSecurID += ","
		$authMethodSettingsSecurID += "\'enabled\': true"


		$externalHostName=$settings.SecurIDAuth.externalHostName
		if ($externalHostName.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$externalHostName = ValidateHostPortAndPromptForCorrection $externalHostName "SecurIDAuth > externalHostName"
			$authMethodSettingsSecurID += "\'externalHostName\':  \'"+$externalHostName+"\'"
		}

		$internalHostName=$settings.SecurIDAuth.internalHostName
		if ($internalHostName.length -gt 0) {
			$authMethodSettingsSecurID += ","
			$internalHostName = ValidateHostPortAndPromptForCorrection $internalHostName "SecurIDAuth > internalHostName"
			$authMethodSettingsSecurID += "\'internalHostName\':  \'"+$internalHostName+"\'"
		}

		$authMethodSettingsSecurID += ","
		$authMethodSettingsSecurID += "\'serverConfig\': \'"
		$authMethodSettingsSecurID += $securidServerConfigB64
		$authMethodSettingsSecurID += "\'"
		$authMethodSettingsSecurID += "}"
	}


	$authMethodSettingsSecurID
}

function GetRADIUSSharedSecret {
	param($hostName, $prefix)

	if ($isTerraform -eq "true") {
		$pwd = $json.($prefix+"-RadiusSharedSecret")
		if ($pwd.length -eq 0) {
			WriteErrorString "Error: $prefix Radius Shared Secret not provided"
		}
	} else {
		while (1) {
			$prompt='Enter the RADIUS server shared secret for host '+$hostName
			$pwd = Read-Host -assecurestring $prompt

			if ($pwd.length -gt 0) {
				$pwd = ConvertFromSecureToPlain $pwd
				Break
			}
		}
	}

	$pwd
}

function GetAuthMethodSettingsRADIUS {
	Param ($settings)

	$hostName=$settings.RADIUSAuth.hostName

	if ($hostName.length -le 0) {
		return
	}

	$hostName = ValidateHostPortAndPromptForCorrection $hostName "RADIUSAuth > hostName"

	$authMethodSettingsRADIUS += "{ \'name\': \'radius-auth\'"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'enabled\': true"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'hostName\':  \'"+$hostName+"\'"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'displayName\':  \'RadiusAuthAdapter\'"

	$sharedSecret = GetRADIUSSharedSecret $hostName "Primary"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'sharedSecret\':  \'"+$sharedSecret+"\'"

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.authType.length -gt 0) {
		$authType = $settings.RADIUSAuth.authType -replace "MSCHAPv2", "MSCHAP2"
		$authMethodSettingsRADIUS += "\'authType\':  \'"+$authType+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'authType\':  \'PAP\'"
	}

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.authPort.length -gt 0) {
		$authMethodSettingsRADIUS += "\'authPort\':  \'"+$settings.RADIUSAuth.authPort+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'authPort\':  \'1812\'"
	}

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.radiusDisplayHint.length -gt 0) {
		$authMethodSettingsRADIUS += "\'radiusDisplayHint\':  \'"+$settings.RADIUSAuth.radiusDisplayHint+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'radiusDisplayHint\': \'two-factor\'"
	}


	if ($settings.RADIUSAuth.accountingPort.length -gt 0) {
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'accountingPort\':  \'"+$settings.RADIUSAuth.accountingPort+"\'"
	}

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.serverTimeout.length -gt 0) {
		$authMethodSettingsRADIUS += "\'serverTimeout\':  \'"+$settings.RADIUSAuth.serverTimeout+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'serverTimeout\':  \'5\'"
	}

	if ($settings.RADIUSAuth.realmPrefix.length -gt 0) {
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'realmPrefix\':  \'"+$settings.RADIUSAuth.realmPrefix+"\'"
	}

	if ($settings.RADIUSAuth.realmSuffix.length -gt 0) {
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'realmSuffix\':  \'"+$settings.RADIUSAuth.realmSuffix+"\'"
	}

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.numAttempts.length -gt 0) {
		$authMethodSettingsRADIUS += "\'numAttempts\':  \'"+$settings.RADIUSAuth.numAttempts+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'numAttempts\': \'3\'"
	}

	if ($settings.RADIUSAuth.enableBasicMSCHAPv2Validation_1 -eq "true" ) {
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'enableBasicMSCHAPv2Validation_1\':  true"
	}

	if ($settings.RADIUSAuth.hostName_2.length -gt 0) {
		$hostName_2 = ValidateHostPortAndPromptForCorrection $settings.RADIUSAuth.hostName_2 "RADIUSAuth > hostName_2"
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'hostName_2\':  \'"+$hostName_2+"\'"

		$authMethodSettingsRADIUS += ","
		if ($settings.RADIUSAuth.authType_2.length -gt 0) {
			$authType = $settings.RADIUSAuth.authType_2 -replace "MSCHAPv2", "MSCHAP2"
			$authMethodSettingsRADIUS += "\'authType_2\':  \'"+$authType+"\'"
		} else {
			$authMethodSettingsRADIUS += "\'authType_2\':  \'PAP\'"
		}

		$authMethodSettingsRADIUS += ","
		if ($settings.RADIUSAuth.authPort_2.length -gt 0) {
			$authMethodSettingsRADIUS += "\'authPort_2\':  \'"+$settings.RADIUSAuth.authPort_2+"\'"
		} else {
			$authMethodSettingsRADIUS += "\'authPort_2\':  \'1812\'"
		}

		if ($settings.RADIUSAuth.accountingPort_2.length -gt 0) {
			$authMethodSettingsRADIUS += ","
			$authMethodSettingsRADIUS += "\'accountingPort_2\':  \'"+$settings.RADIUSAuth.accountingPort_2+"\'"
		}

		$authMethodSettingsRADIUS += ","
		if ($settings.RADIUSAuth.numAttempts_2.length -gt 0) {
			$authMethodSettingsRADIUS += "\'numAttempts_2\':  \'"+$settings.RADIUSAuth.numAttempts_2+"\'"
		} else {
			$authMethodSettingsRADIUS += "\'numAttempts_2\': \'3\'"
		}

		$sharedSecret_2 = GetRADIUSSharedSecret $hostName_2 "Secondary"
		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'sharedSecret_2\':  \'"+$sharedSecret_2+"\'"

		if ($settings.RADIUSAuth.realmPrefix_2.length -gt 0) {
			$authMethodSettingsRADIUS += ","
			$authMethodSettingsRADIUS += "\'realmPrefix_2\':  \'"+$settings.RADIUSAuth.realmPrefix_2+"\'"
		}

		if ($settings.RADIUSAuth.realmSuffix_2.length -gt 0) {
			$authMethodSettingsRADIUS += ","
			$authMethodSettingsRADIUS += "\'realmSuffix_2\':  \'"+$settings.RADIUSAuth.realmSuffix_2+"\'"
		}

		$authMethodSettingsRADIUS += ","
		if ($settings.RADIUSAuth.serverTimeout_2.length -gt 0) {
			$authMethodSettingsRADIUS += "\'serverTimeout_2\':  \'"+$settings.RADIUSAuth.serverTimeout_2+"\'"
		} else {
			$authMethodSettingsRADIUS += "\'serverTimeout_2\':  \'5\'"
		}

		if ($settings.RADIUSAuth.enableBasicMSCHAPv2Validation_2 -eq "true" ) {
			$authMethodSettingsRADIUS += ","
			$authMethodSettingsRADIUS += "\'enableBasicMSCHAPv2Validation_2\':  true"
		}

		$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'enabledAux\': true"

	}

	$authMethodSettingsRADIUS += "}"

	$authMethodSettingsRADIUS
}

#
# Get UAG system settings
#

function GetSystemSettings {
	Param ($settings)

	$systemSettings = "\'systemSettings\':"
	$systemSettings += "{"

	if ($settings.General.ssl30Enabled -eq "true" ) {
		$systemSettings += "\'ssl30Enabled\': \'true\'"
	} else {
		$systemSettings += "\'ssl30Enabled\': \'false\'"
	}

	if ($settings.General.headersToBeLogged.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'headersToBeLogged\': \'"+$settings.General.headersToBeLogged+"\'"
	}

	if ($settings.General.cipherSuites.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'cipherSuites\': \'"+$settings.General.cipherSuites+"\'"
	}

	if ($settings.General.outboundCipherSuites.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'outboundCipherSuites\': \'"+$settings.General.outboundCipherSuites+"\'"
	}

	if ($settings.General.sslProvider.length -gt 0 ) {
		$sslProvider = $settings.General.sslProvider
		if ($sslProvider -eq "OPENSSL" -Or $sslProvider -eq "JDK") {
			$systemSettings += ","
			$systemSettings += "\'sslProvider\': \'" + $sslProvider + "\'"
		} else {
			WriteErrorString "Error: Invalid SSL Provider type specified. It can be JDK or OPENSSL (default)."
			CleanExit
		}
	}

	if ($settings.General.tlsNamedGroups.length -gt 0) {
		if ($settings.General.sslProvider -ne "JDK") {
			WriteErrorString "Error: TLS Named Groups can be configured only with '[General]sslProvider' field set to 'JDK'."
			CleanExit
		} else {
			$systemSettings += ","
			$systemSettings += "\'tlsNamedGroups\': \'" + $settings.General.tlsNamedGroups + "\'"
		}
	}

	if ($settings.General.tlsSignatureSchemes.length -gt 0) {
		if ($settings.General.sslProvider -ne "JDK") {
			WriteErrorString "Error: TLS Signature Schemes can be configured only with '[General]sslProvider' field set to 'JDK'."
			CleanExit
		} else {
			$systemSettings += ","
			$systemSettings += "\'tlsSignatureSchemes\': \'" + $settings.General.tlsSignatureSchemes + "\'"
		}
	}

	if ($settings.General.tls11Enabled.length -gt 0 ) {
		$systemSettings += ","
		$systemSettings += "\'tls11Enabled\': \'"+$settings.General.tls11Enabled+"\'"
	} else {
		$systemSettings += ","
		$systemSettings += "\'tls11Enabled\': \'false\'"
	}

	if ($settings.General.tls12Enabled -eq "false" ) {
		$systemSettings += ","
		$systemSettings += "\'tls12Enabled\': \'false\'"
	} else {
		$systemSettings += ","
		$systemSettings += "\'tls12Enabled\': \'true\'"
	}

	# Only when tls13Enabled property tls13Enabled property is passed through ini configuration, include it in
	# system settings. If tls13Enabled property is not configured, it will use the default value configured in
	# backend for FIPS and NON-FIPS mode.
	if ($settings.General.tls13Enabled.length -gt 0 ) {
		$systemSettings += ","
		$systemSettings += "\'tls13Enabled\': \'"+$settings.General.tls13Enabled+"\'"
	}

	if ($settings.General.snmpEnabled -eq "true" ) {
		$systemSettings += ","
		$systemSettings += "\'snmpEnabled\': \'true\'"
	}

	if ($settings.SnmpSettings.length -gt 0) {
		$snmpSettings = GetSnmpSettings $settings
		if ($snmpSettings.length -gt 0) {
			$systemSettings += ","
			$systemSettings += $snmpSettings
		}
	}

	if ($settings.HeapDumpSettings.length -gt 0) {
		$heapDumpSettings = GetHeapDumpSettings $settings
		if ($heapDumpSettings.length -gt 0) {
			$systemSettings += ","
			$systemSettings += $heapDumpSettings
		}
	}

	if ($settings.General.ntpServers.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'ntpServers\': \'"+$settings.General.ntpServers+"\'"
	}

	if ($settings.General.fallBackNtpServers.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'fallBackNtpServers\': \'"+$settings.General.fallBackNtpServers+"\'"
	}

	if ($settings.General.hostClockSyncEnabled -eq "true" ) {
		$systemSettings += ","
		$systemSettings += "\'hostClockSyncEnabled\': \'true\'"
	}

	$maxSystemCPUAllowedValue = GetValue General maxSystemCPUAllowed $settings.General.maxSystemCPUAllowed 1 100 percent False
	if ($maxSystemCPUAllowedValue.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'maxSystemCPUAllowed\': \'$maxSystemCPUAllowedValue\'"
	}

	$requestTimeoutValue = GetValue General requestTimeoutMsec $settings.General.requestTimeoutMsec 1 300000 millisecs True
	if ($requestTimeoutValue.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'requestTimeoutMsec\': \'$requestTimeoutValue\'"
	}

	$bodyReceiveTimeoutValue = GetValue General bodyReceiveTimeoutMsec $settings.General.bodyReceiveTimeoutMsec 1 300000 millisecs True
	if ($bodyReceiveTimeoutValue.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'bodyReceiveTimeoutMsec\': \'$bodyReceiveTimeoutValue\'"
	}


	#   if ($settings.General.source -like "*-fips-*") {
	#       $systemSettings += "\'cipherSuites\': \'TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
	#       $systemSettings += ", "
	#       $systemSettings += "\'ssl30Enabled\': false, \'tls10Enabled\': false, \'tls11Enabled\': false, \'tls12Enabled\': true"
	#   } else {
	#       $systemSettings += "\'cipherSuites\': \'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
	#       $systemSettings += ", "
	#       $systemSettings += "\'ssl30Enabled\': false, \'tls10Enabled\': false, \'tls11Enabled\': true, \'tls12Enabled\': true"
	#   }

	if ($settings.WebReverseProxy.proxyDestinationUrl.length -gt 0) {
		$systemSettings += ", "
		$systemSettings += "\'cookiesToBeCached\': \'none\'"
	}
	if ($settings.General.maxConnectionsAllowedPerSession.length -gt 0) {
		ValidateStringIsNumeric $settings.General.maxConnectionsAllowedPerSession 'maxConnectionsAllowedPerSession' 'General'
		$systemSettings += ","
		$systemSettings += "\'maxConnectionsAllowedPerSession\': \'"+$settings.General.maxConnectionsAllowedPerSession+"\'"
	}
	if ($settings.General.syslogUrl.length -gt 0) {
		$systemSettings += ","
		$syslogUrlInput = ValidateSyslogUrlInputAndPromptForCorrection $settings.General.syslogUrl 'General > syslogUrl'
		$systemSettings += "\'syslogUrl\': \'"+$syslogUrlInput+"\'"
	}
	if ($settings.General.syslogAuditUrl.length -gt 0) {
		$systemSettings += ","
		$syslogAuditUrlInput = ValidateSyslogUrlInputAndPromptForCorrection $settings.General.syslogAuditUrl 'General > syslogAuditUrl'
		$systemSettings += "\'syslogAuditUrl\': \'"+$syslogAuditUrlInput+"\'"
	}
	if ($settings.General.syslogSystemMessagesEnabled -eq "true" ) {
		$systemSettings += ","
		$systemSettings += "\'syslogSystemMessagesEnabled\': \'true\'"
	}
	if ($settings.General.adminPasswordExpirationDays.length -gt 0) {
		if ($settings.General.adminPasswordExpirationDays -ge 0 -And $settings.General.adminPasswordExpirationDays -le 999) {
			$systemSettings += ","
			$systemSettings += "\'adminPasswordExpirationDays\': \'"+$settings.General.adminPasswordExpirationDays+"\'"
		} else {
			$systemSettings += ","
			$systemSettings += "\'adminPasswordExpirationDays\': \'90\'"
			WriteErrorString "Warning: Admin Password Expiration Days(adminPasswordExpirationDays) not in permitted range (0-999), defaulting to 90 days."
		}
	}
	if ($settings.General.monitoringUsersPasswordExpirationDays.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'monitoringUsersPasswordExpirationDays\': \'"+$settings.General.monitoringUsersPasswordExpirationDays+"\'"
	}
	if ($settings.General.rootPasswordExpirationDays.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'rootPasswordExpirationDays\': \'"+$settings.General.rootPasswordExpirationDays+"\'"
	}
	if ($settings.General.uagName.length -gt 0)
	{
		$uagNameValid = ValidateHostNameOrIP $settings.General.uagName
		if (!$uagNameValid) {
			WriteErrorString "The 'uagname' field must not contain any special characters or spaces"
			Exit
		}
		$systemSettings += ","
		$systemSettings += "\'uagName\': \'" + $settings.General.uagName + "\'"
	}
	if ($settings.General.dnsSearch.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'dnsSearch\': \'"+$settings.General.dnsSearch+"\'"
	}
	if ($settings.General.adminDisclaimerText.length -gt 0) {
		$settings.General.adminDisclaimerText = $settings.General.adminDisclaimerText -replace "\\\\","\" -replace "'","\\047" -replace '\"','\\\"' -replace "\\n","\\n"
		$systemSettings += ","
		$systemSettings += "\'adminDisclaimerText\': \'"+$settings.General.adminDisclaimerText+"\'"
	}
	if ($settings.General.monitorInterval.length -gt 0) {
		$monitorInterval = [int] $settings.General.monitorInterval
		if ($monitorInterval -lt 0 -Or $monitorInterval -gt 9999) {
			WriteErrorString "The value of 'monitorInterval' can be 0 or a positive integer less than or equal to 9999"
			Exit
		}
		$systemSettings += ","
		$systemSettings += "\'monitorInterval\': \'"+$monitorInterval+"\'"
	}
	if ($settings.General.samlCertRolloverSupported -eq "true" ) {
		$systemSettings += ","
		$systemSettings += "\'samlCertRolloverSupported\': \'true\'"
	}
	if ($settings.General.authenticationTimeout.length -gt 0)
	{
		$authenticationTimeout = [int] $settings.General.authenticationTimeout
		if ($authenticationTimeout -lt 0) {
			WriteErrorString "The value of 'authenticationTimeout' can be 0 or a positive integer"
			Exit
		}
		$systemSettings += ","
		$systemSettings += "\'authenticationTimeout\': \'"+$authenticationTimeout+"\'"
	}
	if ($settings.General.sessionTimeout.length -gt 0)
	{
		$sessionTimeout = [int] $settings.General.sessionTimeout
		if ($sessionTimeout -lt 0) {
			WriteErrorString "The value of 'sessionTimeout' can be 0 or a positive integer"
			Exit
		}
		$systemSettings += ","
		$systemSettings += "\'sessionTimeout\': \'"+$sessionTimeout+"\'"
	}



	$sysLogType=$settings.General.sysLogType
	if ($sysLogType.length -gt 0) {
		#if user does not provide syslogType value in system settings, not assuming to be UDP
		if ($sysLogType -ne "UDP" -And $sysLogType -ne "TLS" -And $sysLogType -ne "TCP") {
			WriteErrorString "Error: Invalid sysLogType value specified. It can be one of UDP/TLS/TCP"
			Exit
		}
		$systemSettings += ","
		$systemSettings += "\'sysLogType\': \'"+$sysLogType.ToUpper()+"\'"
	}

	if ($sysLogType -eq "TLS") {
		$sysLogCACert=$settings.General.syslogServerCACertPem
		if ($sysLogCACert.length -eq 0) {
			WriteErrorString "Error: For syslog settings with TLS mode need to provide a CA certificate (syslogServerCACertPem)"
			Exit
		}
		$certContent = GetPEMCertificateContent $sysLogCACert "syslogServerCACertPem"
		$systemSettings += ","
		$systemSettings += "\'syslogServerCACertPem\': \'"+$certContent+"\'"

		$syslogClientCert=$settings.General.syslogClientCertCertPem
		$syslogClientCertKey=$settings.General.syslogClientCertKeyPem

		if (($syslogClientCert.length -gt 0 -And $syslogClientCertKey.length -eq 0) -Or ($syslogClientCert.length -eq 0 -And $syslogClientCertKey.length -gt 0)) {
			WriteErrorString "Error: For syslog settings provide both client certificate (syslogClientCertCertPem) and key (syslogClientCertKeyPem)"
			Exit
		}

		if ($syslogClientCert.length -gt 0) {
			$certContent = GetPEMCertificateContent $syslogClientCert "syslogClientCertCertPem"
			$systemSettings += ","
			$systemSettings += "\'syslogClientCertCertPem\': \'"+$certContent+"\'"

			$rsaprivkey = GetPEMPrivateKeyContent $syslogClientCertKey "syslogClientCertKeyPem"
			$systemSettings += ","
			$systemSettings += "\'syslogClientCertKeyPem\': \'"+$rsaprivkey+"\'"
		}
		$sysLogList = GetTLSSyslogServerList $settings
		$systemSettings += ","
		$systemSettings += $sysLogList
	}

	if (($settings.General.sshEnabled -eq "true") -and ($settings.General.sshKeyAccessEnabled -eq "true")) {
		$sshPublicKeyList = GetSSHPublicKeys $settings
		$systemSettings += ","
		$systemSettings += $sshPublicKeyList
	}
	if ($settings.General.healthCheckUrl.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'healthCheckUrl\': \'"+$settings.General.healthCheckUrl+"\'"
	}
	if ($settings.General.enableHTTPHealthMonitor -eq "true") {
		$systemSettings += ","
		$systemSettings += "\'enableHTTPHealthMonitor\': true"
	}
	if ($settings.General.allowedHostHeaderValues.length -gt 0) {
		$systemSettings += ","
		$systemSettings += "\'allowedHostHeaderValues\': \'"+$settings.General.allowedHostHeaderValues+"\'"
	}
	if ($settings.General.extendedServerCertValidationEnabled -eq "true") {
		$systemSettings += ","
		$systemSettings += "\'extendedServerCertValidationEnabled\': true"
	}

	if ($settings.General.unrecognizedSessionsMonitoringEnabled -eq "false" ) {
		$systemSettings += ","
		$systemSettings += "\'unrecognizedSessionsMonitoringEnabled\': \'false\'"
	}

	if ($settings.General.minSHAHashSize.length -gt 0 ) {
		$minSHAHashSize = ValidateMinSHAHashSize $settings.General.minSHAHashSize
	} else {
		$settings.General.minSHAHashSize = "SHA-256"
	}
	$systemSettings += ","
	$systemSettings += "\'minSHAHashSize\':\'" + $minSHAHashSize + "\'"

	$systemSettings += "}"

	$systemSettings
}

function GetClientEncryptionMode {
	Param ($settings)

	$clientEncryptionMode=$settings.Horizon.clientEncryptionMode
	if ($clientEncryptionMode.length -gt 0) {
		$clientEncryptionMode = $clientEncryptionMode.ToUpper();
		if ($clientEncryptionMode -ne "DISABLED" -And $clientEncryptionMode -ne "ALLOWED" -And $clientEncryptionMode -ne "REQUIRED") {
			WriteErrorString "Error: Invalid client ecryption mode value specified. It can be DISABLED or ALLOWED or REQUIRED"
			Exit
		}
		$edgeServiceSettingsVIEW += ","
		$edgeServiceSettingsVIEW += "\'clientEncryptionMode\': \'"+$clientEncryptionMode+"\'"
	}
	else
	{
		$clientEncryptionMode = "ALLOWED"
	}

	$clientEncryptionMode
}

function GetHeapDumpSettings {
	param ($settings)

	$iniSection="HeapDumpSettings"
	$maxHeapDumpFileCount=$settings.$iniSection.maxHeapDumpFileCount
	$heapDumpCollectionThresholdPc=$settings.$iniSection.heapDumpCollectionThresholdPc
	$firstSettingPresent="false"
	$heapDumpSettings = "\'heapDumpSettings\':"
	$heapDumpSettings += "{"

	if ($maxHeapDumpFileCount.length -gt 0) {
		if ([int]$maxHeapDumpFileCount -lt 0 -Or [int]$maxHeapDumpFileCount -gt 10) {
			WriteErrorString "The value of 'maxHeapDumpFileCount' should be between 0 to 10, default value as 1"
			Exit
		}
		$firstSettingPresent="true"
		$heapDumpSettings += "\'maxHeapDumpFileCount\': \'"+$maxHeapDumpFileCount+"\'"
	}
	if ($heapDumpCollectionThresholdPc.length -gt 0) {
		if ([int]$heapDumpCollectionThresholdPc -lt 1 -Or [int]$heapDumpCollectionThresholdPc -gt 100) {
			WriteErrorString "The value of 'heapDumpCollectionThresholdPc' should be between 1 and 100, default value is 100"
			Exit
		}
		if ($firstSettingPresent -eq "true") {
			$heapDumpSettings += ","
		}
		$heapDumpSettings += "\'heapDumpCollectionThresholdPc\': \'"+$heapDumpCollectionThresholdPc+"\'"
	}
	$heapDumpSettings += "}"

	$heapDumpSettings
}

function GetOidcSharedSecret {
	Param ($settings, $oidcConfigurationId)

	if ($isTerraform -eq "true") {
		$pwd = $json.("oidcClientSecret")
		if ($pwd.length -eq 0) {
			WriteErrorString "Error: OIDC Client Secret not provided"
		}
	} else {
		$invalidOidcClientSecret=$true
		while ($invalidOidcClientSecret) {
			$prompt='Enter the Client Secret for Open ID Configuration '+$oidcConfigurationId
			$pwd = Read-Host -assecurestring $prompt

			if ($pwd.length -gt 0) {
				$pwd = ConvertFromSecureToPlain $pwd
				$invalidOidcClientSecret=$false
			}
		}
	}

	$pwd
}


function GetAuthMethodSettingsOidc {
	Param ($settings)
	for ($i=0; $i -lt 100; $i++) {
		if ($i -eq 0) {
			$id=""
		} else {
			$id=$i
		}
		$oidcConfig = ""

		$oidcConfig += GetOidcConfiguration $settings $id
		if ($oidcConfig.length -gt 0) {
			if ($i -gt 0) {
				$allOidcConfig += ", "
			}
			$allOidcConfig += $oidcConfig
		}
	}
	$allOidcConfigJson=""
	if ($allOidcConfig.length -gt 0){
		$allOidcConfigJson="\'oidcOpMetadataSettingsList\':{\'oidcOpMetadataSettingsList\':["+$allOidcConfig+"]}"
	}
	$allOidcConfigJson
}

function GetOidcConfiguration {
	Param ($settings, $id)

	$oidcSection = "OidcProviderSetting"+$id

	$oidcConfigurationId=$settings.$oidcSection.oidcConfigurationId
	if ($oidcConfigurationId.length -le 0) {
		return
	}
	$curOidcConfig="{\'oidcConfigurationId\': \'"+$oidcConfigurationId

	$oidcClientId=$settings.$oidcSection.oidcClientId
	if ($oidcClientId.length -le 0) {
		WriteErrorString "Error: Client ID (oidcClientId) is mandatory for Open ID Configuration: "+$oidcConfigurationId
		Exit
	}
	$curOidcConfig+="\',\'oidcClientId\': \'"+$oidcClientId

	$oidcClientSecret = GetOidcSharedSecret $settings $oidcConfigurationId

	$curOidcConfig+="\',\'oidcClientSecret\': \'"+$oidcClientSecret

	$oidcConfigUrl=$settings.$oidcSection.oidcConfigUrl
	if ($oidcConfigUrl.length -le 0) {
		WriteErrorString "Error: Config URL (oidcConfigUrl) is mandatory for Open ID Configuration: "+$oidcConfigurationId
		Exit
	}
	$curOidcConfig+="\',\'oidcConfigUrl\': \'"+$oidcConfigUrl

	$oidcForceAuthPrompt=$settings.$oidcSection.oidcForceAuthPrompt
	if (-Not($oidcForceAuthPrompt -ieq "true")) {
		$oidcForceAuthPrompt="false"
	}
	$curOidcConfig+="\',\'oidcForceAuthPrompt\': \'"+$oidcForceAuthPrompt

	$oidcTimeoutSeconds=$settings.$oidcSection.oidcTimeoutSeconds
	if ($oidcTimeoutSeconds.length -le 0) {
		$oidcTimeoutSeconds=60
	}
	$curOidcConfig+="\',\'timeoutSeconds\': "+$oidcTimeoutSeconds

	$oidcConfigUrlThumbprint=$settings.$oidcSection.oidcConfigUrlThumbprint
	if ($oidcConfigUrlThumbprint.length -gt 0) {
		$oidcConfigUrlThumbprint = validateAndUpdateThumbprints $oidcConfigUrlThumbprint $settings.General.minSHAHashSize $oidcSection
		$curOidcConfig+=",\'oidcConfigUrlThumbprint\': \'"+$oidcConfigUrlThumbprint+"\'"
	}

	$oidcTrustedCertificates=$settings.$oidcSection.oidcTrustedCertificates
	if ($oidcTrustedCertificates.length -gt 0) {
		$oidcTrustedCertificates = GetTrustedCertificates $oidcSection "oidcTrustedCertificates" "oidcTrustedCertificates"
		$curOidcConfig+= ","+$oidcTrustedCertificates
	}
	$curOidcConfig+="}"
	$curOidcConfig
}

function GetSnmpSettings {
	Param ($settings)

	$iniSection="SnmpSettings"
	$version=$settings.$iniSection.version

	if ($version.length -gt 0) {
		if ($version -ne "V1_V2C" -And $version -ne "V3") {
			WriteErrorString "Error: Invalid SNMP version value specified. It can be one of V1_V2C/V3"
			Exit
		}
	}

	if ($version.length -gt 0 -And $version -eq "V3") {
		$snmpSettings = "\'snmpSettings\':"
		$snmpSettings += "{"
		$snmpSettings += "\'version\': \'"+$version+"\'"

		$securityLevel=$settings.$iniSection.securityLevel

		if ($securityLevel.length -gt 0) {
			if ($securityLevel -ne "NO_AUTH_NO_PRIV" -And $securityLevel -ne "AUTH_NO_PRIV" -And $securityLevel -ne "AUTH_PRIV") {
				WriteErrorString "Error: Invalid security level value specified. It can be one of NO_AUTH_NO_PRIV/AUTH_NO_PRIV/AUTH_PRIV"
				Exit
			}
		}

		$snmpSettings += ","
		$snmpSettings += "\'securityLevel\': \'"+$securityLevel.ToUpper()+"\'"

		$usmUser=$settings.$iniSection.usmUser
		if ($usmUser.length -eq 0) {
			WriteErrorString "Error: SNMPv3 username is not specified"
			Exit
		}
		$usmUser=ValidateSNMPUserNameAndPromptForCorrection $usmUser
		$snmpSettings += ","
		$snmpSettings += "\'usmUser\': \'"+$usmUser+"\'"

		$engineID = $settings.$iniSection.engineID
		if ($engineID.length -gt 0) {
			$engineIDRegex = [regex]"^[\x00-\x7F]{1,27}$"
			if (!($engineIDRegex.Matches($engineID).Success)) {
				WriteErrorString "SNMP v3 engine ID can have only ASCII with maximum length of 27 characters"
				exit
			}

		}

		$snmpSettings += ","
		$snmpSettings += "\'engineID\': \'"+$engineID+"\'"

		if ($securityLevel -eq "AUTH_NO_PRIV"  -or $securityLevel -eq "AUTH_PRIV") {
			$authAlgorithm=$settings.$iniSection.authAlgorithm
			if ($authAlgorithm.length -gt 0) {
				$authAlgorithm = ValidateSNMPAuthAlgorithm $authAlgorithm
				$snmpSettings += ","
				$snmpSettings += "\'authAlgorithm\': \'"+$authAlgorithm.ToUpper()+"\'"
			}

			$authPassword=GetSnmpv3Password "authentication"
			$snmpSettings += ","
			$snmpSettings += "\'authPassword\': \'"+$authPassword+"\'"
		}

		if ($securityLevel -eq "AUTH_PRIV") {
			$privacyAlgorithm=$settings.$iniSection.privacyAlgorithm
			if ($privacyAlgorithm.length -gt 0) {
				if ($privacyAlgorithm -ne "DES" -And $privacyAlgorithm -ne "AES") {
					WriteErrorString "Error: Invalid privacy algorithm value specified. It can be one of DES/AES"
					Exit
				}
			}
			$snmpSettings += ","
			$snmpSettings += "\'privacyAlgorithm\': \'"+$privacyAlgorithm.ToUpper()+"\'"

			$privacyPassword=GetSnmpv3Password "privacy"
			$snmpSettings += ","
			$snmpSettings += "\'privacyPassword\': \'"+$privacyPassword+"\'"
		}

		$snmpSettings += "}"
	}
	elseif ($version.length -gt 0 -And $version -eq "V1_V2C") {
		$snmpSettings = "\'snmpSettings\':"
		$snmpSettings += "{"
		$snmpSettings += "\'version\': \'"+$version+"\'"

		$communityName = $settings.$iniSection.communityName
		if ($communityName.length -gt 0) {
			$snmpSettings += ","
			$snmpSettings += "\'communityName\': \'"+$communityName+"\'"
		}
		$snmpSettings += "}"
	}

	$snmpSettings
}

#
# Function to prompt user for SNMPv3 passwords and validate the input
#
function GetSnmpv3Password {
	param($securityLevel)

	if ($isTerraform -eq "true") {
		$password = $json.($securityLevel+"-Snmpv3Password")
		if ($password.length -eq 0) {
			WriteErrorString "Error: $securityLevel Snmpv3 Password not provided"
		} elseif ($password.length -lt 8) {
			WriteErrorString "Error: $securityLevel Snmpv3 Password must contain at least 8 characters"
		}
	} else {
		$match=0
		while (! $match) {
			$valid=0
			while (! $valid) {
				$password = Read-Host -assecurestring "Enter password for SNMPv3 "$securityLevel" algorithm "

				$password = ConvertFromSecureToPlain $password

				if($password.length -lt 8) {
					WriteErrorString "Error: Password must contain at least 8 characters"
					Continue
				}
				$valid=1
			}

			$confirmPassword = Read-Host -assecurestring "Re-enter the password"
			$confirmPassword = ConvertFromSecureToPlain $confirmPassword
			if ($password -ne $confirmPassword) {
				WriteErrorString "Error: re-entered password does not match"
			} else {
				$match=1
			}
		}
	}
	$password = $password -replace '"', '\"'
	$password = $password -replace "'", "\047"
	$password
}

function ValidateSNMPAuthAlgorithm {
	Param($authAlgorithm)
	if($authAlgorithm -in "MD5", "SHA", "SHA-224", "SHA-256", "SHA-384", "SHA-512" )
	{
		return $authAlgorithm;
	}
	WriteErrorString "Error: Invalid authentication algorithm value specified."
	$authAlgorithm = Read-Host "Please provide a valid input for 'authAlgorithm' (Allowed values : SHA/SHA-224/SHA-256/SHA-384/SHA-512)."
	return ValidateSNMPAuthAlgorithm $authAlgorithm
}

function ValidateSNMPUserNameAndPromptForCorrection {
	Param($usmUser)
	$usmUserRegex=[regex]"^(?!\.)([\w.](?!\.$))*$"
	if($usmUserRegex.Matches($usmUser).Success)
	{
		return $usmUser;
	}
	if ($isTerraform -eq "true") {
		WriteErrorString "Please provide a valid input: SNMP username supports uppercase, lowercase English alphabets, numbers, dot (.) and underscore (_). Maximum length is 32 characters"
	}
	$usmUser = Read-Host "Please provide a valid input: SNMP username supports uppercase, lowercase English alphabets, numbers, dot (.) and underscore (_). Maximum length is 32 characters"
	return ValidateSNMPUserNameAndPromptForCorrection $usmUser
}



function GetSSHPublicKeys {
	param($settings)
	$sshPublicKeyList = "\'sshPublicKeys\': [ "
	for($i=1;;$i++)
	{
		$sshKey = "sshPublicKey$i"
		$sshKey = $settings.General.$sshKey
		if($sshKey.length -gt 0)
		{
			if (!(Test-path $sshKey)) {
				WriteErrorString "Error: SSH public key file not found ($sshKey)"
				Exit
			}
			else
			{
				$content = (Get-Content $sshKey | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

				if ($content -like "*ssh-rsa*") {
					#Write-host "valid ssh public key"
				} else {
					WriteErrorString "Error: Invalid ssh public key file. It must contain ssh-rsa"
					Exit
				}
				$fileName = $sshKey.SubString($sshKey.LastIndexof('\')+1)
				$sshPublicKeyList += "{ \'name\': \'$fileName\'"
				$sshPublicKeyList += ","
				$sshPublicKeyList += "\'data\': \'"
				$sshPublicKeyList += $content
				$sshPublicKeyList += "\'"
				$sshPublicKeyList += "},"
			}
		}
		else {
			$sshPublicKeyList = $sshPublicKeyList.Substring(0, $sshPublicKeyList.Length-1)
			break;
		}
	}
	$sshPublicKeyList += "]"

	$sshPublicKeyList
}

function GetTLSSyslogServerList {
	param($settings)
	$sysLogList = "\'tlsSyslogServerSettings\': [ "
	for($i=1;;$i++)
	{

		$sysLogServer = "tlsSyslogServerSettings$i"
		$sysLogServer = $settings.General.$sysLogServer

		if ($sysLogServer.length -gt 0) {
			if ($i -gt 2) {
				WriteErrorString "Only two syslog servers are allowed"
				Exit
			}

			$hostName,$port,$acceptedPeer = $sysLogServer.split('|')
			$sysLogList += "{ \'hostname\': \'$hostName\'"

			if ($port.length -gt 0) {
				$sysLogList += ","
				$sysLogList += "\'port\': \'$port\'"
			}
			$sysLogList += "},"
		} else {
			$sysLogList = $sysLogList.Substring(0, $sysLogList.Length-1)
			break;
		}

	}
	$sysLogList += "]"
	$sysLogList
}

function GetPEMCertificateContent {
	Param ($cert, $field)
	if (!(Test-path $cert)) {
		WriteErrorString "Error: PEM Certificate file not found ($cert)"
		Exit
	}

	$certContent = (Get-Content $cert | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

	if ($certContent -like "*-----BEGIN CERTIFICATE-----*") {
		#Write-host "valid cert"
	} else {
		WriteErrorString "Error: Invalid certificate file for $field. It must contain -----BEGIN CERTIFICATE-----."
		Exit
	}
	$certContent
}

function GetPEMPrivateKeyContent {
	Param ($rsaPrivKeyFile, $field)
	if (!(Test-path $rsaPrivKeyFile)) {
		WriteErrorString "Error: RSA private key file not found ($rsaPrivKeyFile)"
		Exit
	}

	$rsaprivkey = (Get-Content $rsaPrivKeyFile | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""
	$rsaprivkey = $rsaprivkey.Substring($rsaprivkey.IndexOf("-----BEGIN"))

	if ($rsaprivkey -like "*-----BEGIN RSA PRIVATE KEY-----*") {
		#Write-Host "valid private key"
	} else {
		WriteErrorString "Error: Invalid private key PEM file specified for $field. It must contain an RSA private key."
		Exit
	}
	$rsaprivkey
}
#
# UAG Edge service settings
#

function GetEdgeServiceSettings {
	Param ($settings)

	$edgeCount = 0

	$edgeServiceSettings = "\'edgeServiceSettingsList\':"
	$edgeServiceSettings += "{ \'edgeServiceSettingsList\': ["

	#
	# Horizon View edge service
	#

	$edgeServiceSettingsVIEW += GetEdgeServiceSettingsVIEW($settings)
	if ($edgeServiceSettingsVIEW.length -gt 0) {
		$edgeServiceSettings += $edgeServiceSettingsVIEW
		$edgeCount++
	}

	#
	# Web Reverse Proxy edge services
	#

	for ($i=0; $i -lt 100; $i++) {

		if ($i -eq 0) {
			$id=""
		} else {
			$id=$i
		}
		$edgeServiceSettingsWRP = ""

		$edgeServiceSettingsWRP += GetEdgeServiceSettingsWRP $settings $id
		if ($edgeServiceSettingsWRP.length -gt 0) {
			if ($edgeCount -gt 0) {
				$edgeServiceSettings += ", "
			}
			$edgeServiceSettings += $edgeServiceSettingsWRP
			$edgeCount++
		}
	}

	if (($settings.AirWatch.tunnelGatewayEnabled -eq "true") -or ($settings.Airwatch.contentGatewayEnabled -eq "true")  -or `
        ($settings.Airwatch.secureEmailGatewayEnabled -eq "true")) {

		$groupName = "Airwatch"

		$edgeServiceSettingsAWCommon += GetEdgeServiceSettingsAWCommon $settings $groupName $awAPIServerPwd

		#
		# Airwatch Tunnel Gateway edge service
		#

		if ($settings.AirWatch.tunnelGatewayEnabled -eq "true") {
			$edgeServiceSettingsAWTGateway += GetEdgeServiceSettingsAWTGateway $settings $groupName $edgeServiceSettingsAWCommon

			if ($edgeServiceSettingsAWTGateway.length -gt 0) {
				if ($edgeCount -gt 0) {
					$edgeServiceSettings += ", "
				}
				$edgeServiceSettings += $edgeServiceSettingsAWTGateway
				$edgeCount++
			}
		}

		#
		# Airwatch SEG edge service
		#

		if ($settings.Airwatch.secureEmailGatewayEnabled -eq "true") {
			$edgeServiceSettingsAWCG += GetEdgeServiceSettingsAWSEG $settings $groupName $edgeServiceSettingsAWCommon
			if ($edgeServiceSettingsAWSEG.length -gt 0) {

				if ($edgeCount -gt 0) {
					$edgeServiceSettings += ", "
				}
				$edgeServiceSettings += $edgeServiceSettingsAWSEG
				$edgeCount++
			}
		}
	}


	if (($settings.AirWatch.tunnelGatewayEnabled -ne "true") -and ($settings.AirwatchTunnelGateway.apiServerUsername.length -gt 0)) {

		$groupName = "AirwatchTunnelGateway"

		$edgeServiceSettingsAWCommon = GetEdgeServiceSettingsAWCommon $settings $groupName $awTunnelGatewayAPIServerPwd

		#
		# Airwatch Tunnel Gateway edge service
		#

		$edgeServiceSettingsAWTGateway += GetEdgeServiceSettingsAWTGateway $settings $groupName $edgeServiceSettingsAWCommon

		if ($edgeServiceSettingsAWTGateway.length -gt 0) {
			if ($edgeCount -gt 0) {
				$edgeServiceSettings += ", "
			}
			$edgeServiceSettings += $edgeServiceSettingsAWTGateway
			$edgeCount++
		}
	}

	if (($settings.AirWatch.contentGatewayEnabled -ne "true") -and ($settings.AirwatchContentGateway.apiServerUsername.length -gt 0)) {

		$groupName = "AirwatchContentGateway"

		$edgeServiceSettingsAWCommon = GetEdgeServiceSettingsAWCommon $settings $groupName $awCGAPIServerPwd

		#
		# Airwatch CG edge service
		#

		$edgeServiceSettingsAWCG += GetEdgeServiceSettingsAWCG $settings $groupName $edgeServiceSettingsAWCommon

		if ($edgeServiceSettingsAWCG.length -gt 0) {
			if ($edgeCount -gt 0) {
				$edgeServiceSettings += ", "
			}
			$edgeServiceSettings += $edgeServiceSettingsAWCG
			$edgeCount++
		}
	}


	if (($settings.AirWatch.secureEmailGatewayEnabled -ne "true") -and ($settings.AirwatchSecureEmailGateway.apiServerUsername.length -gt 0)) {

		$groupName = "AirwatchSecureEmailGateway"

		$edgeServiceSettingsAWCommon = GetEdgeServiceSettingsAWCommon $settings $groupName $awSEGAPIServerPwd

		#
		# Airwatch SEG edge service
		#

		$edgeServiceSettingsAWSEG += GetEdgeServiceSettingsAWSEG $settings $groupName $edgeServiceSettingsAWCommon

		if ($edgeServiceSettingsAWSEG.length -gt 0) {
			if ($edgeCount -gt 0) {
				$edgeServiceSettings += ", "
			}
			$edgeServiceSettings += $edgeServiceSettingsAWSEG
			$edgeCount++
		}
	}

	$edgeServiceSettings += "] }"

	$edgeServiceSettings
}

#
# Auth Method settings
#

function GetAuthMethodSettings {
	Param ($settings)

	$authMethodSettingsCertificate = GetAuthMethodSettingsCertificate($settings)

	$authMethodSettingsSecurID = GetAuthMethodSettingsSecurID($settings)

	$authMethodSettingsRADIUS = GetAuthMethodSettingsRADIUS($settings)

	$authMethodSettings = "\'authMethodSettingsList\':"
	$authMethodSettings += "{ \'authMethodSettingsList\': ["

	$authCount=0

	if ($authMethodSettingsCertificate.length -gt 0) {
		$authMethodSettings += $authMethodSettingsCertificate
		$authCount++
	}

	if ($authMethodSettingsSecurID.length -gt 0) {
		if ($authCount -gt 0) {
			$authMethodSettings += ","
		}
		$authMethodSettings += $authMethodSettingsSecurID
		$authCount++
	}

	if ($authMethodSettingsRADIUS.length -gt 0) {
		if ($authCount -gt 0) {
			$authMethodSettings += ","
		}
		$authMethodSettings += $authMethodSettingsRADIUS
		$authCount++
	}

	$authMethodSettings += "] }"

	$authMethodSettings
}

function GetKeytabSettings {
	Param ($settings)

	$keyTabCount = 0

	$keytabSettings = "\'kerberosKeyTabSettingsList\':"
	$keytabSettings += "{ \'kerberosKeyTabSettings\': ["

	for($i=1; $i -le 100; $i++) {

		$section = "KerberosKeyTabSettings$i"

		if ($settings.$section.keyTab.length -gt 0) {

			if ($settings.$section.principalName.length -eq 0) {
				WriteErrorString "Error: Invalid .INI file. Missing principalName in [KerberosKeyTabSettings$i]."
				Exit
			}

			$fileName = $settings.$section.keyTab

			if (!(Test-path $filename)) {
				WriteErrorString "Error: keyTab file $fileName in [$section] not found"
				Exit
			}

			$fileName = Resolve-Path -Path $fileName
			$Content = [System.IO.File]::ReadAllBytes($fileName)
			$keyTabB64 = [System.Convert]::ToBase64String($Content)

			$principalName = $settings.$section.principalName

			if ($keyTabCount -gt 0) {
				$keytabSettings += ", "
			}

			$keytabSettings += "{"

			$keytabSettings += "\'principalName\': \'$principalName\'"
			$keytabSettings += ", "
			$keytabSettings += "\'keyTab\': \'$keyTabB64\'"
			$keytabSettings += "}"

			$keyTabCount++
		}
	}

	$keytabSettings += "]"
	$keytabSettings += "}"

	$keytabSettings
}

function GetkerberosRealmSettings {
	Param ($settings)

	$realmCount = 0

	$kerberosRealmSettings = "\'kerberosRealmSettingsList\':"
	$kerberosRealmSettings += "{ \'kerberosRealmSettingsList\': ["

	for($i=1; $i -le 100; $i++) {

		$section = "KerberosRealmSettings$i"

		if ($settings.$section.name.length -gt 0) {

			$name = $settings.$section.name

			$realmNameValid = ValidateHostNameOrIP $name
			if (!$realmNameValid) {
				WriteErrorString "Error: The realm name $name under section $section is invalid."
				Exit
			}

			if ($realmCount -gt 0) {
				$kerberosRealmSettings += ", "
			}

			$kerberosRealmSettings += "{"

			$kerberosRealmSettings += "\'name\': \'$name\'"
			$kerberosRealmSettings += ", "

			$kdcTimeout = $settings.$section.kdcTimeout

			$kerberosRealmSettings += "\'kdcHostNameList\': ["

			$hostCount = 0

			for($j=1; $j -le 100; $j++) {

				$hostLabel = "kdcHostNameList$j"
				$host = $settings.$section.$hostLabel

				if ($host.length -gt 0) {
					$host = ValidateHostPortAndPromptForCorrection $host "$section > $hostLabel"
					if ($hostCount -gt 0) {
						$kerberosRealmSettings += ", "
					}

					$kerberosRealmSettings += "\'$host\'"
					$hostCount++
				}

			}

			$kerberosRealmSettings += "]"

			if ($kdcTimeout.length -gt 0) {
				$kerberosRealmSettings += ", "
				$kerberosRealmSettings += "\'kdcTimeout\': \'$kdcTimeout\'"
			}

			$kerberosRealmSettings += "}"

			$realmCount++
		}
	}

	$kerberosRealmSettings += "]"
	$kerberosRealmSettings += "}"

	$kerberosRealmSettings
}

function GetIDPExternalMetadataSettings {
	Param ($settings)

	$metaDataCount = 0

	$externalMetadataSettings = "\'idPExternalMetadataSettingsList\':"
	$externalMetadataSettings += "{ \'idPExternalMetadataSettingsList\': ["

	for($i=1; $i -le 100; $i++) {

		$section = "IDPExternalMetadata$i"

		if ($settings.$section.metadataXmlFile.length -gt 0) {

			$fileName = $settings.$section.metadataXmlFile

			if (!(Test-path $filename)) {
				WriteErrorString "Error: metadataXmlFile file $fileName in [$section] not found"
				Exit
			}

			$fileName = Resolve-Path -Path $fileName
			$Content = [System.IO.File]::ReadAllBytes($fileName)
			$metaDataB64 = [System.Convert]::ToBase64String($Content)

			if ($metaDataCount -gt 0) {
				$externalMetadataSettings += ", "
			}

			$externalMetadataSettings += "{"

			$externalMetadataSettings += "\'metadata\': \'$metaDataB64\'"

			if ($settings.$section.entityID.length -gt 0) {
				$externalMetadataSettings += ","
				$externalMetadataSettings += "\'entityID\':  \'"+$settings.$section.entityID+"\'"
			}

			if ($settings.$section.forceAuthN -eq "true") {
				$externalMetadataSettings += ","
				$externalMetadataSettings += "\'forceAuthN\': true"
			}

			# added for the saml encryption configuratin.
			if ($settings.$section.encryptionCertificateType.length -gt 0){

				$encryptionCertType = $settings.$section.encryptionCertificateType.ToUpper()

				if ($encryptionCertType -ne "PEM") {
					WriteErrorString "Error: allowed certificate type(s) in IDPExternalMetadata is : PEM"
					Exit
				}

				$externalMetadataSettings += ","
				$externalMetadataSettings += "\'encryptionCertType\': \'" + $encryptionCertType + "\'"

				if ( $encryptionCertType -eq "PEM"){

					$externalMetadataSettings += ","
					$externalMetadataSettings += " \'certificateChainAndKeyWrapper\': {"

					$privateKeyPem = $settings.$section.privateKeyPem
					$certChainPem = $settings.$section.certChainPem

					if (($privateKeyPem.length -eq 0) -or ($certChainPem.length -eq 0)) {
						WriteErrorString "Error: To enable SAML Encryption, Please provide certificate chain and private key while certificate type is set to PEM"
						Exit
					}

					$privateKeyPemConent = GetPEMPrivateKeyContent $settings.$section.privateKeyPem "privateKeyPem"
					$certChainContent = GetPEMCertificateContent $settings.$section.certChainPem "certChainPem"

					$externalMetadataSettings += ( "\'privateKeyPem\': \'" + $privateKeyPemConent + "\', 'certChainPem\': \'" + $certChainContent +"\'")
					$externalMetadataSettings +="}"
				}
			}

			if ($settings.$section.allowUnencrypted -eq "true") {
				$externalMetadataSettings += ","
				$externalMetadataSettings += "\'allowUnencrypted\': true"
			}

			$externalMetadataSettings += "}"
			$metaDataCount++
		}
	}

	$externalMetadataSettings += "]"
	$externalMetadataSettings += "}"

	$externalMetadataSettings
}

function GetLoadBalancerSettings {
	Param ($settings)

	if ($settings.HighAvailability.groupID.length -gt 0) {

		if ($settings.HighAvailability.virtualIPAddress.length -eq 0) {
			WriteErrorString "Error: Invalid .INI file. Missing VirtualIPAddress in [HighAvailability]."
			Exit
		}

		$loadBalancerSettings = "\'loadBalancerSettings\': {"
		$loadBalancerSettings += "\'groupID\':  \'"+$settings.HighAvailability.GroupID+"\'"
		$loadBalancerSettings += ", "
		$loadBalancerSettings += "\'virtualIPAddress\':  \'"+$settings.HighAvailability.VirtualIPAddress+"\'"
		$loadBalancerSettings += ", "
		$loadBalancerSettings += "\'loadBalancerMode\':  \'ONEARM\'"
		$loadBalancerSettings += "}"

	}

	$loadBalancerSettings
}


function GetDevicePolicySettings {
	Param ($settings)

	$trueVal = "true"
	$falseVal = "false"
	$devicePolicySettingsPresent = $falseVal

	$devicePolicySettings = "\'devicePolicySettingsList\':"
	$devicePolicySettings += "{ \'devicePolicySettingsList\': [ "

	$obtainedOpswatDevicePolicySettings = GetOpswatDevicePolicySettings $settings
	if ($obtainedOpswatDevicePolicySettings.length -gt 0) {
		$devicePolicySettings += $obtainedOpswatDevicePolicySettings
		$devicePolicySettingsPresent = $trueVal
	}

	$obtainedWS1IntelRiskScoreDevicePolicySettings = GetWS1IntelRiskScoreDevicePolicySettings $settings
	if ($obtainedWS1IntelRiskScoreDevicePolicySettings.length -gt 0) {
		if ($devicePolicySettingsPresent -eq $trueVal) {
			$devicePolicySettings += ", "
		}
		$devicePolicySettings += $obtainedWS1IntelRiskScoreDevicePolicySettings
		$devicePolicySettingsPresent = $trueVal
	}

	if ($devicePolicySettingsPresent -eq $trueVal) {
		$devicePolicySettings += " ] }"
	} else {
		$devicePolicySettings = ""
	}

	$devicePolicySettings
}

function GetOpswatDevicePolicySettings {
	Param ($settings)

	if ($settings.OpswatEndpointComplianceCheckSettings.clientKey.length -gt 0) {

		$opswatDevicePolicySettings += "{"
		$opswatDevicePolicySettings += "\'name\':  \'OPSWAT\'"
		$opswatDevicePolicySettings += ", "
		$opswatDevicePolicySettings += "\'userName\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.clientKey+"\'"

		if ($settings.OpswatEndpointComplianceCheckSettings.clientSecret.length -gt 0) {
			$opswatDevicePolicySettings += ", "
			$opswatDevicePolicySettings += "\'password\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.clientSecret+"\'"
		} else {
			WriteErrorString "Error: Invalid .INI file. Missing clientSecret value in [OpswatEndpointComplianceCheckSettings]."
			Exit
		}

		if ($settings.OpswatEndpointComplianceCheckSettings.hostName.length -gt 0) {
			$opswatHostName = ValidateHostPortAndPromptForCorrection $settings.OpswatEndpointComplianceCheckSettings.hostName "OpswatEndpointComplianceCheckSettings > hostName"
			$opswatDevicePolicySettings += ", "
			$opswatDevicePolicySettings += "\'hostName\':  \'"+$opswatHostName+"\'"
		}

		if ([int]$settings.OpswatEndpointComplianceCheckSettings.complianceServerHealthCheckInterval -gt 0 -and [int]$settings.OpswatEndpointComplianceCheckSettings.complianceServerHealthCheckInterval -lt 121) {
			$opswatDevicePolicySettings += ", "
			$opswatDevicePolicySettings += "\'complianceServerHealthCheckInterval\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.complianceServerHealthCheckInterval+"\'"
		} else {
			WriteErrorString "Error: Invalid .INI file. Compliance server health check interval must be in between 1 to 120 (both inclusive) mins."
			Exit
		}

		#Gets the hash table which maps status bucket names as specified in INI fields to 1) the status to be specified in JSON and 2) the default value of each status
		$opswatStatusTable = GetOpswatDevicePolicyStatusTable

		$devicePolicyAllowedStatuses = GetDevicePolicyAllowedStatuses $settings OpswatEndpointComplianceCheckSettings $opswatStatusTable

		$complianceCheckIntervals = GetComplianceCheckIntervals OpswatEndpointComplianceCheckSettings $settings

		$hostedResources = GetDevicePolicySettingsHostedResources $settings

		$opswatDevicePolicySettings += $devicePolicyAllowedStatuses + $complianceCheckIntervals + $hostedResources + "}"
	}

	$opswatDevicePolicySettings
}

function GetWS1IntelRiskScoreDevicePolicySettings {
	Param ($settings)

	if ($settings.WorkspaceONEIntelligenceRiskScoreEndpointComplianceCheckSettings.workspaceOneIntelligenceSettingsName.length -gt 0) {

		$ws1IntelRiskScoreDevicePolicySettings += "{"
		$ws1IntelRiskScoreDevicePolicySettings += "\'name\':  \'Workspace_ONE_Intelligence_Risk_Score\'"
		$ws1IntelRiskScoreDevicePolicySettings += ", "
		$ws1IntelRiskScoreDevicePolicySettings += "\'workspaceOneIntelligenceSettingsName\':  \'"+$settings.WorkspaceONEIntelligenceRiskScoreEndpointComplianceCheckSettings.workspaceOneIntelligenceSettingsName+"\'"

		$complianceCheckIntervalValue = GetValue WorkspaceONEIntelligenceRiskScoreEndpointComplianceCheckSettings complianceCheckInterval $settings.WorkspaceONEIntelligenceRiskScoreEndpointComplianceCheckSettings.complianceCheckInterval 5 1440 mins True

		if ($complianceCheckIntervalValue.length -gt 0) {
			$ws1IntelRiskScoreDevicePolicySettings += ", "
			$ws1IntelRiskScoreDevicePolicySettings += "\'complianceCheckInterval\':  \'"+$complianceCheckIntervalValue+"\'"
		}

		#Gets the hash table which maps status bucket names as specified in INI fields to 1) the status to be specified in JSON and 2) the default value of each status
		$obtainedWS1IntelRiskScoreStatusTable = GetWS1IntelRiskScoreDevicePolicyStatusTable

		$devicePolicyAllowedStatuses = GetDevicePolicyAllowedStatuses $settings WorkspaceONEIntelligenceRiskScoreEndpointComplianceCheckSettings $obtainedWS1IntelRiskScoreStatusTable

		$ws1IntelRiskScoreDevicePolicySettings += $devicePolicyAllowedStatuses + "}"
	}

	$ws1IntelRiskScoreDevicePolicySettings
}

function GetDevicePolicySettingsHostedResources {
	Param ($settings)

	$platformTable = GetPlatformTable

	# "hostedResourceMap" JSON section begins
	$hostedResourceSettings = ","
	$hostedResourceSettings += "\'hostedResourceMap\': { "

	# Loop through all platforms present in hash table
	foreach ($entry in $platformTable.GetEnumerator()) {
		$platformNameInINI = $($entry.Name)
		$platformObj = $($entry.Value)

		#The name of the INI section would be OpswatEndpointComplianceCheckSettings-macOS OR OpswatEndpointComplianceCheckSettings-Windows
		$hostedResourceSectionName = "OpswatEndpointComplianceCheckSettings-$platformNameInINI"

		$url = $settings.$hostedResourceSectionName.url

		if ($url.length -gt 0) {
			$url = ValidateWebURIAndPromptForCorrection $url "$hostedResourceSectionName > url"

			# This gets the JSON key to be used for the specified platform name from the platformTable and adds that to JSON
			# e.g. - for macOS (name present in INI section), the JSON key is -- "Mac". With this, JSON section for
			# a specific platform begins, e.g. "Mac" : {
			$hostedResourceSettings += "\'" + $platformObj.jsonKey + "\': { "

			# "resourceURLSettings" (for a specific platform, e.g macOS or Windows) JSON section begins
			$hostedResourceSettings += "\'resourceURLSettings\': { "
			#Adding url
			$hostedResourceSettings += "\'url\': \'$url\'"

			#Adding thumbprints
			$urlThumbprints=$settings.$hostedResourceSectionName.urlThumbprints
			if ($urlThumbprints.length -gt 0) {
				# Removing invalid thumbprint characters
				$urlThumbprints = SanitizeThumbprints $urlThumbprints $true
				if ($urlThumbprints -ne "*") {
					$urlThumbprints = validateAndUpdateThumbprints $urlThumbprints $settings.General.minSHAHashSize "opswat"
				}
				$hostedResourceSettings += ","
				$hostedResourceSettings += "\'urlThumbprints\': \'$urlThumbprints\'"
			}

			#Adding trusted certificates
			if ($settings.$hostedResourceSectionName.trustedCert1.length -gt 0) {
				$trustedCertificates = GetTrustedCertificates $hostedResourceSectionName "trustedCert" "trustedCertificates"
				$hostedResourceSettings += ","
				$hostedResourceSettings += $trustedCertificates
			}


			#Adding response refresh interval
			$urlResponseRefreshIntervalValue = GetValue $hostedResourceSectionName urlResponseRefreshInterval $settings.$hostedResourceSectionName.urlResponseRefreshInterval 10 86400 secs True
			if ($urlResponseRefreshIntervalValue.length -gt 0) {
				$hostedResourceSettings += ","
				$hostedResourceSettings += "\'urlResponseRefreshInterval\': \'$urlResponseRefreshIntervalValue\'"
			}
			# "resourceURLSettings" (for a specific platform, e.g macOS or Windows) JSON section ends
			$hostedResourceSettings += " }"

			# "hostedResourceMetadata" (for a specific platform, e.g macOS or Windows) JSON section begins
			$hostedResourceSettings += ","
			$hostedResourceSettings += "\'hostedResourceMetadata\': { "

			# Getting the list of INI fields to be ignored for a specific platform
			$listOfFieldsToBeIgnored = $platformObj.listOfFieldsToBeIgnored

			# Getting the list of mandatory INI fields for a specific platform
			$mandatoryFields = $platformObj.mandatoryFields

			# Adding fields like name, params, executable (if not marked as ignored) in "hostedResourceMetadata" JSON section
			$hostedResourceSettings += addJsonElement $hostedResourceSectionName $mandatoryFields $listOfFieldsToBeIgnored name $settings.$hostedResourceSectionName.name

			$hostedResourceSettings += addJsonElement $hostedResourceSectionName $mandatoryFields $listOfFieldsToBeIgnored params $settings.$hostedResourceSectionName.params

			$hostedResourceSettings += addJsonElement $hostedResourceSectionName $mandatoryFields $listOfFieldsToBeIgnored executable $settings.$hostedResourceSectionName.executable

			if ($settings.$hostedResourceSectionName.flags.length -gt 0) {

				if (! ($settings.$hostedResourceSectionName.flags -match '^\w{1,64}(?:[, \t]+\w{1,64}){0,15}$')) {
					WriteErrorString "Error: Invalid flag value in [OpswatEndpointComplianceCheckSettings-$platformNameInINI]"
					Exit
				}

				$flagArray = $settings.$hostedResourceSectionName.flags -split "[\s,]+"

				if ( $flagArray.Length -gt 0) {
					$flags =  $flagArray -join "\',\'"
					$hostedResourceSettings += "\'flags\':{\'flag\':[\'$flags\']},"
				}
			}

			# Removing the extra delimiter (comma), if present at the end
			$hostedResourceSettings = removeTrailingDelimiter $hostedResourceSettings

			# "hostedResourceMetadata" JSON section ends
			$hostedResourceSettings += " }"

			# JSON section for a specific platform ends
			$hostedResourceSettings += " }"

			# A new platform section may begin now. Hence putting the delimiter
			$hostedResourceSettings += ","
		}
	}

	# Removing the extra delimiter (comma), if present at the end
	$hostedResourceSettings = removeTrailingDelimiter $hostedResourceSettings

	# "hostedResourceMap" JSON section ends
	$hostedResourceSettings += "}"

	$hostedResourceSettings
}

# Prepares a hashtable with key as platform name as specified in INI section and value as :
# 1) The JSON key string to be used for that platform
# 2) The list of INI fields to be ignored (and hence not fed to settings JSON) in that INI section, e.g  executable is
# only needed for macOS and not for Windows.
function GetPlatformTable {
	$platformTable = @{

		"macOS" = [pscustomobject]@{ jsonKey = "Mac"; listOfFieldsToBeIgnored = @(); mandatoryFields = @("executable") }

		"Windows" = [pscustomobject]@{ jsonKey = "Windows"; listOfFieldsToBeIgnored = @("executable"); mandatoryFields = @() }
	}

	$platformTable
}

function GetComplianceCheckIntervals {
	Param ($iniGroup, $settings)

	$complianceCheckTimeUnit = $settings.OpswatEndpointComplianceCheckSettings.complianceCheckTimeunit
	if ($complianceCheckTimeUnit.length -eq 0) {	# set default timeunit to minutes
		$complianceCheckTimeUnit = "MINUTES"
	} else {
		$complianceCheckTimeUnit = $complianceCheckTimeUnit.ToUpper();
	}

	if ($complianceCheckTimeUnit -eq "SECONDS") {
		$complianceCheckIntervalValue = GetValue $iniGroup complianceCheckInterval $settings.OpswatEndpointComplianceCheckSettings.complianceCheckInterval 300 84600 $complianceCheckTimeUnit True
		$complianceCheckFastIntervalValue = GetValue $iniGroup complianceCheckFastInterval $settings.OpswatEndpointComplianceCheckSettings.complianceCheckFastInterval 5 84600 $complianceCheckTimeUnit True
		$complianceCheckInitialDelay = GetValue $iniGroup complianceCheckInitialDelay $settings.OpswatEndpointComplianceCheckSettings.complianceCheckInitialDelay 5 3600 $complianceCheckTimeUnit True
	}
	elseif ($complianceCheckTimeUnit -eq "MINUTES") {
		$complianceCheckIntervalValue = GetValue $iniGroup complianceCheckInterval $settings.OpswatEndpointComplianceCheckSettings.complianceCheckInterval 5 1440 $complianceCheckTimeUnit True
		$complianceCheckFastIntervalValue = GetValue $iniGroup complianceCheckFastInterval $settings.OpswatEndpointComplianceCheckSettings.complianceCheckFastInterval 1 1440 $complianceCheckTimeUnit True
		$complianceCheckInitialDelay = GetValue $iniGroup complianceCheckInitialDelay $settings.OpswatEndpointComplianceCheckSettings.complianceCheckInitialDelay 1 60 $complianceCheckTimeUnit True
	}
	else {
		WriteErrorString "Error: Compliance check interval timeunit can be either MINUTES or SECONDS"
		Exit
	}


	# If complianceCheckInterval is not specified (i.e., it is zero) and complianceCheckFastInterval is specified and is a non-zero integer OR if both are specified and
	# complianceCheckInterval is less than complianceCheckFastInterval, then throwing an error message

	if (($complianceCheckIntervalValue.length -eq 0 -and $complianceCheckFastIntervalValue.length -gt 0 -and $complianceCheckFastIntervalValue -ne 0) -or
			($complianceCheckIntervalValue.length -gt 0 -and $complianceCheckFastIntervalValue.length -gt 0 -and ([int]$complianceCheckIntervalValue -lt [int]$complianceCheckFastIntervalValue))) {

		WriteErrorString "Error: complianceCheckInterval (if not specified, the value is 0) cannot be less than complianceCheckFastInterval"
		Exit
	}

	if ($complianceCheckIntervalValue.length -gt 0) {
		$complianceCheckIntervals = ", "
		$complianceCheckIntervals += "\'complianceCheckInterval\':  \'"+$complianceCheckIntervalValue+"\'"
	}

	if ($complianceCheckFastIntervalValue.length -gt 0) {
		$complianceCheckIntervals += ", "
		$complianceCheckIntervals += "\'complianceCheckFastInterval\':  \'"+$complianceCheckFastIntervalValue+"\'"
	}

	if ($complianceCheckInitialDelay.length -gt 0) {
		$complianceCheckIntervals += ", "
		$complianceCheckIntervals += "\'complianceCheckInitialDelay\':  \'"+$complianceCheckInitialDelay+"\'"
	}

	if ($complianceCheckTimeUnit.length -gt 0) {
		$complianceCheckIntervals += ", "
		$complianceCheckIntervals += "\'complianceCheckTimeunit\':  \'"+$complianceCheckTimeUnit+"\'"
	}
	$complianceCheckIntervals
}

function GetDevicePolicyAllowedStatuses {
	Param ($settings, $iniSectionName, $statusTable)

	$devicePolicyAllowedStatuses = ", "
	$devicePolicyAllowedStatuses += "\'allowedStatuses\': ["

	# Loop through all status buckets present in hash table
	foreach ($entry in $statusTable.GetEnumerator()) {
		$statusKey = $($entry.Name)
		$statusValue = $($entry.Value)

		# Get the specified INI field for the current status
		$statusINIFieldName = $settings.$iniSectionName.$statusKey

		# If a value for the current status bucket is specified in INI file (the valid values are true or false, case-insensitive)
		if ($statusINIFieldName.length -gt 0) {

			# If the value of the current status bucket in INI file is true, such as : allowAssessmentPending=true (case-insensitive check) indicating that this status # is allowed to gain access to EUC resources, then adding the corresponding mapped JSON status name to allowedStatuses list
			if ($statusINIFieldName -ieq "true") {
				$allowedStatuses += "\'" + $statusValue.statusNameInJSON + "\'"
				$allowedStatuses += ","
			} Elseif ($statusINIFieldName -ine "false" -And $statusValue.defaultValue -ieq "true") {
				# If the value of the current status bucket in INI file is not false (case-insensitive check) but some invalid text like allowDeviceNotFound=invalid,
				# and the mapped default value of this status is true, then adding the corresponding mapped JSON status name to allowedStatuses list. If the default # value is false, we don't need to do anything
				$allowedStatuses += SpecifyDevicePolicyStatusDefaultValue($statusValue)
			}
		} Elseif ($statusValue.defaultValue -ieq "true") {
			# If the current status bucket is not specified in INI file and the mapped default value of this staus is true, then adding the corresponding mapped JSON # status name to allowedStatuses list. If the default value is false, we don't need to do anything
			$allowedStatuses += SpecifyDevicePolicyStatusDefaultValue($statusValue)
		}
	}

	if ($allowedStatuses -ne $null) {
		$allowedStatuses = $allowedStatuses.Substring(0, $allowedStatuses.Length-1)
	}

	$devicePolicyAllowedStatuses += $allowedStatuses + "] "
	$devicePolicyAllowedStatuses
}

# Prepares a hash table of all possible device policy status buckets with key as the field name, which would be specified in INI file and value as a PS custom object
# containing two members : 1) the name of that status bucket to be specified in JSON, 2) the default value of this status bucket, if not specified in INI file or value
# of this is specified as some invalid text (neither true nor false; case-insensitive).
#
# If we need to add support for a new status bucket in future, all we need to do is just add one more entry in this hash table with INI field name as key and the
# corresponding JSON value and the default value.

function GetOpswatDevicePolicyStatusTable {
	$opswatStatusTable = @{

		"allowInCompliance" = [pscustomobject]@{ statusNameInJSON = "COMPLIANT"; defaultValue = "true" }

		"allowNotInCompliance" = [pscustomobject]@{ statusNameInJSON = "NON_COMPLIANT"; defaultValue = "false" }

		"allowOutOfLicenseUsage" = [pscustomobject]@{ statusNameInJSON = "OUT_OF_LICENSE_USAGE"; defaultValue = "false" }

		"allowAssessmentPending" = [pscustomobject]@{ statusNameInJSON = "ASSESSMENT_PENDING"; defaultValue = "false" }

		"allowEndpointUnknown" = [pscustomobject]@{ statusNameInJSON = "NOT_FOUND"; defaultValue = "false" }

		"allowOthers" = [pscustomobject]@{ statusNameInJSON = "OTHERS"; defaultValue = "false" }
	}

	$opswatStatusTable
}

# Prepares a hash table of all possible device policy status buckets with key as the field name, which would be specified in INI file and value as a PS custom object
# containing two members : 1) the name of that status bucket to be specified in JSON, 2) the default value of this status bucket, if not specified in INI file or value
# of this is specified as some invalid text (neither true nor false; case-insensitive).
#
# If we need to add support for a new status bucket in future, all we need to do is just add one more entry in this hash table with INI field name as key and the
# corresponding JSON value and the default value.

function GetWS1IntelRiskScoreDevicePolicyStatusTable {
	$ws1IntelRiskScoreStatusTable = @{

		"allowLow" = [pscustomobject]@{ statusNameInJSON = "LOW"; defaultValue = "true" }

		"allowMedium" = [pscustomobject]@{ statusNameInJSON = "MEDIUM"; defaultValue = "false" }

		"allowHigh" = [pscustomobject]@{ statusNameInJSON = "HIGH"; defaultValue = "false" }

		"allowOthers" = [pscustomobject]@{ statusNameInJSON = "OTHERS"; defaultValue = "false" }
	}

	$ws1IntelRiskScoreStatusTable
}

# It is used to add a device policy status in JSON (provied the default value is true) when that specific status field is not present in INI or present with an invalid value.

function SpecifyDevicePolicyStatusDefaultValue {
	Param ($statusValue)

	$statusWithDefaultValue = "\'" + $statusValue.statusNameInJSON + "\'"
	$statusWithDefaultValue += ","
	$statusWithDefaultValue
}

function GetSecurityAgentsSettings {
	Param ($settings)

	$icount = 0
	for($i = 1; $i -lt 10; $i++)
	{
		$iniGroup = "SecurityAgentSettings$i"
		$securityAgentName = $settings.$iniGroup.name
		if ($securityAgentName.length -gt 0) {
			if ($icount -eq 0) {
				$securityAgentSettings = "\'securityAgentSettingsList\': { \'securityAgentSettingsList\': [ "
			} else {
				$securityAgentSettings += ","
			}
			$icount++

			if ($securityAgentName -eq "WAZUH_AGENT") {
				$securityAgentSettings += ValidateAndAddWazuhSettings $settings $iniGroup
				$securityAgentSettings += " }"
			} else {
				WriteErrorString "Error: Invalid security agent name '$securityAgentName' specified in group $iniGroup"
				Exit
			}
		}
	}

	if ($icount -gt 0) {
		$securityAgentSettings += " ]}"
	}
	$securityAgentSettings
}

function ValidateAndAddWazuhSettings {
	Param ($settings, $iniGroup)

	$json = "{ \'name\': \'WAZUH_AGENT\', "

	$enableFlag = $settings.$iniGroup.enabled
	if ($enableFlag.length -gt 0) {
		if ($enableFlag -ne "true" -and $enableFlag -ne "false") {
			WriteErrorString "Error: Invalid value for boolean flag 'enabled' in group $iniGroup. Only true or false are supported."
			Exit
		} else {
			$enableFlag = $enableFlag.toLower()
		}
	} else {
		$enableFlag = "true"
	}
	$json += "\'enabled\': $enableFlag,"

	$hostnameAndPort = $settings.$iniGroup.wazuhServerHostAndPort
	if (($hostnameAndPort.length -eq 0) -or -not (ValidateHostPort $hostnameAndPort)) {
		WriteErrorString "Error: Empty or invalid value for wazuhServerHostAndPort in group $iniGroup. Provide hostname or IP address and optional port separated by colon."
		Exit
	} else {
		$json += "\'wazuhServerHostAndPort\': \'$hostnameAndPort\'"
	}

	$wazuhProtocol = $settings.$iniGroup.wazuhProtocol
	if ($wazuhProtocol.length -gt 0) {
		if ($wazuhProtocol -ne "TCP" -and $wazuhProtocol -ne "UDP") {
			WriteErrorString "Error: Invalid value for wazuhProtocol in group $iniGroup. Only TCP and UDP are allowed."
			Exit
		} else {
			$json += ",\'wazuhProtocol\': \'$wazuhProtocol\'"
		}
	}

	$registrationHostAndPort = $settings.$iniGroup.wazuhRegistrationHostAndPort
	if ($registrationHostAndPort.length -gt 0) {
		if (ValidateHostPort $hostnameAndPort) {
			$json += ",\'wazuhRegistrationHostAndPort\': \'$registrationHostAndPort\'"
		} else {
			WriteErrorString "Error: Invalid value for wazuhRegistrationHostAndPort in group $iniGroup. Provide hostname or IP address and optional port separated by colon."
			Exit
		}
	}

	$json += ValidateWazuhSettingNumberFields $settings $iniGroup 'wazuhEnrollmentDelay'
	$json += ValidateWazuhSettingNumberFields $settings $iniGroup 'wazuhKeepAliveInterval'
	$json += ValidateWazuhSettingNumberFields $settings $iniGroup 'wazuhTimeReconnect'

	$wazuhAgentName = $settings.$iniGroup.wazuhAgentName
	if ($wazuhAgentName.length -gt 0) {
		if ((([regex]"^[a-zA-Z0-9\\_\\.\\-]{2,100}$").Matches($wazuhAgentName)).Value -eq $wazuhAgentName) {
			$json += ",\'wazuhAgentName\': \'$wazuhAgentName\'"
		} else {
			WriteErrorString "Error: Invalid value for wazuhAgentName in $iniGroup. Only letters, numbers, dot, hyphen and underscore are allowed."
			Exit
		}
	}

	$wazuhAgentGroups = $settings.$iniGroup.wazuhAgentGroups
	if ($wazuhAgentGroups.length -gt 0) {
		if ((([regex]"^[a-zA-Z0-9\\_\\.\\-\\,\\]{2,100}$").Matches($wazuhAgentGroups)).Value -eq $wazuhAgentGroups) {
			$json += ",\'wazuhAgentGroups\': \'$wazuhAgentGroups\'"
		} else {
			WriteErrorString "Error: Invalid value for wazuhAgentGroups in $iniGroup. Only letters, numbers, dot, hyphen, underscore and comma are allowed."
			Exit
		}
	}

	$wazuhAgentCertPath = $settings.$iniGroup.wazuhAgentCertificate
	$wazuhAgentKeyPath = $settings.$iniGroup.wazuhAgentKey
	if ($wazuhAgentCertPath.length -gt 0 -or $wazuhAgentKeyPath.length -gt 0) {

		if ($wazuhAgentCertPath.length -eq 0) {
			WriteErrorString "Error: [$iniGroup]wazuhAgentCertificate PEM Certificate file not specified along with wazuhAgentKey"
			Exit
		}
		if (!(Test-path $wazuhAgentCertPath)) {
			WriteErrorString "Error:  [$iniGroup]wazuhAgentCertificate PEM Certificate file not found ($wazuhAgentCertPath)"
			Exit
		}

		if ($wazuhAgentKeyPath.length -eq 0) {
			WriteErrorString "Error: [$iniGroup]wazuhAgentKeyPath PEM Certificate file not specified along with wazuhAgentCertificate"
			Exit
		}
		if (!(Test-path $wazuhAgentKeyPath)) {
			WriteErrorString "Error:  [$iniGroup]wazuhAgentKeyPath private key file not found ($wazuhAgentKeyPath)"
			Exit
		}

		# Read the PEM contents and remove any preamble before ----BEGIN
		$wazuhAgentCertificate = (Get-Content $wazuhAgentCertificate | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""
		$wazuhAgentCertificate = $wazuhAgentCertificate.Substring($wazuhAgentCertificate.IndexOf("-----BEGIN"))
		if (!($wazuhAgentCertificate -like "*-----BEGIN*")) {
			WriteErrorString "Error: [$iniGroup] Invalid certs PEM file (wazuhAgentCertificate) specified. It must contain a certificate."
			Exit
		}

		$wazuhAgentKey = (Get-Content $wazuhAgentKeyPath | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""
		$wazuhAgentKey = $wazuhAgentKey.Substring($wazuhAgentKey.IndexOf("-----BEGIN"))
		if ( !($wazuhAgentKey -like "*-----BEGIN RSA PRIVATE KEY-----*")) {
			WriteErrorString "Error: [$iniGroup] Invalid private key PEM file (wazuhAgentKey) specified. It must contain an RSA private key."
			Exit
		}

		$json += ",\'wazuhAgentCertificate\': \'$wazuhAgentCertificate\'"
		$json += ",\'wazuhAgentKey\': \'$wazuhAgentKey\'"
	}

	$wazuhServerCACertPath = $settings.$iniGroup.wazuhServerCACertificate
	if ($wazuhServerCACertPath.length -gt 0) {
		if ( !(Test-path $wazuhServerCACertPath)) {
			WriteErrorString "Error:  [$iniGroup]wazuhServerCACertificate PEM Certificate file not found ($wazuhServerCACertPath)"
			Exit
		}
		$wazuhServerCACertificate = (Get-Content $wazuhServerCACertPath | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n" -replace """", ""
		$wazuhServerCACertificate = $wazuhServerCACertificate.Substring($wazuhServerCACertificate.IndexOf("-----BEGIN"))
		if (!($wazuhServerCACertificate -like "*-----BEGIN*")) {
			WriteErrorString "Error: [$iniGroup] Invalid certs PEM file (wazuhServerCACertificate) specified. It must contain a certificate."
			Exit
		}
		$json += ",\'wazuhServerCACertificate\': \'$wazuhServerCACertificate\'"
	}

	$wazuhRegistrationPassword = ReadSecurityAgentPassword $settings $iniGroup
	if ($wazuhRegistrationPassword.length -gt 0) {
		$json += ",\'wazuhRegistrationPassword\': \'$wazuhRegistrationPassword\'"
	}
	$json
}

function ReadSecurityAgentPassword {
	Param ($settings, $iniGroup)

	if ($isTerraform -eq "true") {
		$secAgentPwd = $json.($iniGroup+"-SecurityAgentPassword")
	} else {
		$match = 0
		while (! $match) {

			$secAgentName = $settings.$iniGroup.name
			$secAgentPwd = Read-Host -assecurestring "Enter password for $secAgentName in $iniGroup section. Hit return to skip this if no password is required."
			$secAgentPwd = ConvertFromSecureToPlain $secAgentPwd
			if ($secAgentPwd.length -eq 0) {
				return
			}

			$secAgentPwd2 = Read-Host -assecurestring "Re-enter the password"
			$secAgentPwd2 = ConvertFromSecureToPlain $secAgentPwd2
			if ($secAgentPwd -ne $secAgentPwd2) {
				WriteErrorString "Error: re-entered password does not match"
			} else {
				$match=1
			}
		}
	}
	$secAgentPwd = $secAgentPwd -replace '"', '\"'
	$secAgentPwd = $secAgentPwd -replace "'", "\047"
	$secAgentPwd

}

function ValidateWazuhSettingNumberFields {
	Param ($settings, $iniGroup, $fieldName)

	$fieldValue = $settings.$iniGroup.$fieldName
	$numericField = ''
	if ($fieldValue.length -gt 0) {
		if ( -not (ValidateNumber $fieldValue) -or (([int]$fieldValue) -lt 1)) {
			WriteErrorString "Invalid value for $fieldName in group $iniGroup. Only positive intergers are accepted."
			Exit
		}
		else {
			$numericField = ",\'$fieldName\': $fieldValue"
		}
	}
	$numericField
}

function GetWorkspaceOneIntelligenceSettings {
	Param ($settings)

	$icount = 0
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "WorkspaceOneIntelligenceSettings$i"

		if (($settings.$iniGroup.name.length -gt 0) -and ($settings.$iniGroup.encodedCredentialsFile.length -gt 0))
		{
			if ($icount -eq 0)
			{
				$workspaceOneIntelligenceSettings = "\'workspaceOneIntelligenceSettingsList\': { \'workspaceOneIntelligenceSettingsList\': [ "
			}
			else
			{
				$workspaceOneIntelligenceSettings += ","
			}

			$icount++

			$fileName = $settings.$iniGroup.encodedCredentialsFile
			if (!(Test-path $filename)) {
				WriteErrorString "Error: Workspace One Intelligence credentials file $fileName in $iniGroup not found"
				Exit
			}

			$name = $settings.$iniGroup.name
			ValidateSettingName "WorkspaceOneIntelligenceSettings$i" $name
			$workspaceOneIntelligenceSettings += "{ \'name\': \'" + $settings.$iniGroup.name + "\'"

			$fileName = Resolve-Path -Path $fileName
			$Content = [System.IO.File]::ReadAllBytes($fileName)
			$credentialsB64 = [System.Convert]::ToBase64String($Content)

			$workspaceOneIntelligenceSettings += ", "
			$workspaceOneIntelligenceSettings += "\'encodedCredentialsFileContent\': \'$credentialsB64\'"

			#Adding thumbprints
			$urlThumbprints=$settings.$iniGroup.urlThumbprints
			if ($urlThumbprints.length -gt 0) {
				# Remove invalid thumbprint characters
				$urlThumbprints = SanitizeThumbprints $urlThumbprints
				$urlThumbprints = validateAndUpdateThumbprints $urlThumbprints $settings.General.minSHAHashSize $iniGroup

				$workspaceOneIntelligenceSettings += ", "
				$workspaceOneIntelligenceSettings += "\'urlThumbprints\': \'$urlThumbprints\'"
			}

			#Adding trusted certificates
			if ($settings.$iniGroup.trustedCert1.length -gt 0) {
				$trustedCertificates = GetTrustedCertificates $iniGroup "trustedCert" "trustedCertificates"
				$workspaceOneIntelligenceSettings += ", "
				$workspaceOneIntelligenceSettings += $trustedCertificates
			}

			if ($icount -gt 0) {
				$workspaceOneIntelligenceSettings += " }"
			}
		}
	}

	if ($icount -gt 0) {
		$workspaceOneIntelligenceSettings += "] }"
	}

	$workspaceOneIntelligenceSettings
}

function GetCustomExecutableSettings{
	param($settings)
	$customExecutableSettings = "\'customExecutableList\': { \'customExecutableList\': [ "
	for($i=1;$i -lt 100;$i++)
	{
		$iniGroup = "CustomExecutableSettings$i"
		$customExecutableName = $settings.$iniGroup.name
		$osType = $settings.$iniGroup.osType
		$url = $settings.$iniGroup.url
		if(($customExecutableName.length -eq 0) -or ($osType.length -eq 0 ) -or ($url.length -eq 0)){
			continue
		}
		ValidateSettingName "CustomExecutableSettings$i" $customExecutableName

		if(-not ($osType -in  @('macOS', 'Windows'))){
			WriteErrorString "OS Type should be either macOS or Windows"
			return
		}

		$customExecutableSettings+= '{'
		$hostedResourcesMap = prepareCustomExecutableHostedResourceMetadata $settings $iniGroup $osType
		$customExecutableSettings += $hostedResourcesMap
		$customExecutableSettings += ","
		$resourceURLMap = PrepareCustomExecutableResourceURLSettings $settings $iniGroup
		$customExecutableSettings += $resourceURLMap
		$customExecutableSettings += "}"
		$customExecutableSettings += ","

	}

	$customExecutableSettings = removeTrailingDelimiter $customExecutableSettings
	$customExecutableSettings += "]}"
	$customExecutableSettings

}

function prepareCustomExecutableHostedResourceMetadata{

	param($settings, $iniGroup)

	$customExecutableName = $settings.$iniGroup.name
	$osType = $settings.$iniGroup.osType

	$platformTable = GetPlatformTable
	$mandatoryFields = $platformTable[$osType].mandatoryFields
	$listOfFieldsToBeIgnored = $platformTable[$osType].listOfFieldsToBeIgnored

	$hostedResourceMetadata += "\'hostedResourceMetadata\': { "

	$hostedResourceMetadata += "\'name\': \'$customExecutableName\'"

	# Add trusted certs in settings json.
	if ($settings.$iniGroup.trustedSigningCert1.length -gt 0) {
		$trustedCertificates = GetTrustedCertificates $iniGroup "trustedSigningCert" "trustedSigningCertificates"
		$hostedResourceMetadata += ","
		$hostedResourceMetadata += $trustedCertificates
	}

	$url = $settings.$iniGroup.url
	if($url.length -gt 0) {
		$hostedResourceMetadata += ","
		$hostedResourceMetadata += "\'isObtainedfromURL\': true"
	}

	$hostedResourceMetadata += ","
	$fileType = $platformTable[$osType].jsonkey
	$hostedResourceMetadata += "\'fileType\': \'$fileType\'"

	$hostedResourceMetadata += ","
	$hostedResourceMetadata += addJsonElement $iniGroup $mandatoryFields $listOfFieldsToBeIgnored executable $settings.$iniGroup.executable

	$hostedResourceMetadata += addJsonElement $iniGroup $mandatoryFields $listOfFieldsToBeIgnored params $settings.$iniGroup.params

	if ($settings.$iniGroup.flags.length -gt 0) {

		if (! ($settings.$iniGroup.flags -match '^\w{1,64}(?:[, \t]+\w{1,64}){0,15}$')) {
			WriteErrorString "Error: Invalid flag value in [CustomExecutable : $customExecutableName] [osType: $osType]."
			Exit
		}

		$flagArray = $settings.$iniGroup.flags -split "[\s,]+"

		if ( $flagArray.Length -gt 0) {
			$flags =  $flagArray -join "\',\'"
			$hostedResourceMetadata += "\'flags\':{\'flag\':[\'$flags\']} ,"
		}
	}

	$hostedResourceMetadata = removeTrailingDelimiter $hostedResourceMetadata

	$hostedResourceMetadata += " } "
	$hostedResourceMetadata
}

function PrepareCustomExecutableResourceURLSettings{
	param($setting, $iniGroup, $osType)

	$resourceURLSettings += "\'resourceURLSettings\': { "

	$url = $settings.$iniGroup.url

	if($url.length -gt 0){

		$resourceURLSettings += "\'url\': \'$url\'"

		# Add trusted certs in settings json.
		if ($settings.$iniGroup.trustedCert1.length -gt 0) {
			$trustedCertificates = GetTrustedCertificates $iniGroup "trustedCert" "trustedCertificates"
			$resourceURLSettings += ","
			$resourceURLSettings += $trustedCertificates
		}

		$urlThumbprints = $settings.$iniGroup.urlThumbprints
		if($urlThumbprints.length -gt 0){
			$resourceURLSettings += ","
			$urlThumbprints= SanitizeThumbprints $urlThumbprints $true
			if ($urlThumbprints -ne "*") {
				$urlThumbprints = validateAndUpdateThumbprints $urlThumbprints $settings.General.minSHAHashSize $iniGroup
			}
			$resourceURLSettings += "\'urlThumbprints\': \'$urlThumbprints\'"
		}

		$urlResponseRefreshInterval = GetValue $iniGroup updateInterval $settings.$iniGroup.urlResponseRefreshInterval 10 86400 secs True
		if($urlResponseRefreshInterval.length -gt 0){
			$resourceURLSettings += ","
			$resourceURLSettings += "\'urlResponseRefreshInterval\': \'$urlResponseRefreshInterval\'"
		}

	}else{
		WriteErrorString "URL should be defined for custom executables"
		return
	}

	$resourceURLSettings +='}'
	$resourceURLSettings

}

function GetWorkspaceOneIntelligenceDataSettings {
	Param ($settings)

	if ($settings.WorkspaceOneIntelligenceDataSettings.name.length -eq 0) {
		Return
	}

	$workspaceOneIntelligenceDataSettings = "\'workspaceOneIntelligenceDataSettings\': {"
	$workspaceOneIntelligenceDataSettings += "\'name\': \'" + $settings.WorkspaceOneIntelligenceDataSettings.name + "\'"

	$enabled = $settings.WorkspaceOneIntelligenceDataSettings.enabled

	if ($enabled -eq "true") {
		$workspaceOneIntelligenceDataSettings += ","
		$workspaceOneIntelligenceDataSettings += "\'enabled\': true"
	}

	#Adding update interval
	$updateIntervalValue = GetValue WorkspaceOneIntelligenceDataSettings updateInterval $settings.WorkspaceOneIntelligenceDataSettings.updateInterval 10 86400 secs True
	if ($updateIntervalValue.length -gt 0) {
		$workspaceOneIntelligenceDataSettings += ", "
		$workspaceOneIntelligenceDataSettings += "\'updateInterval\': \'" + $updateIntervalValue + "\'"
	}

	$workspaceOneIntelligenceDataSettings += "}"

	$workspaceOneIntelligenceDataSettings
}

# Function to compute the admin user settings if provided.
function GetNewAdminUserSettings {
	Param ($settings, [string] $newAdminUserPwd)
	$allAdminPwd = ReadPwdToHash $newAdminUserPwd $settings
	$addedAdmins=@{}

	$adminUsersList = ""
	$userCount = 0
	for ($i=0; $i -lt 100; $i++) {

		if ($i -eq 0) {
			$id=""
		} else {
			$id=$i
		}
		$adminUserSetting = ""

		$adminUserSetting += GetAdminUserSetting $settings $id $allAdminPwd $addedAdmins
		if ($adminUserSetting.length -gt 0) {
			if ($userCount -gt 0) {
				$adminUsersList += ", "
			}
			$adminUsersList += $adminUserSetting
			$userCount++
		}
	}

	if ($adminUsersList.length -le 0) {
		return
	}

	$newAdminUserSettings = "\'adminUsersList\':"
	$newAdminUserSettings += "{ \'adminUsersList\': ["
	$newAdminUserSettings += $adminUsersList
	$newAdminUserSettings += "]}"
	$newAdminUserSettings
}

# Function to compute JSON node for individual admin
function GetAdminUserSetting{
	Param ($settings, $id, $allAdminPwd, $addedAdmins)

	$adminUser = "AdminUser"+$id

	$adminUserName=$settings.$adminUser.name
	$adminUserName=ValidateMonitorUserName $adminUserName
	if ($adminUserName.length -le 0) {
		return
	}
	if ($addedAdmins[$adminUserName].length -gt 0){
		WriteErrorString "User $adminUserName has a duplicate entry. First occurrence is considered."
		return
	}

	$adminPwd = $allAdminPwd[$adminUserName]
	if ($adminPwd.length -le 0) {
		$adminPwd = GetUserPwd $settings.General.name $adminUserName $false $settings
	}

	$adminEnabled = "true"
	$adminEnabledInput = $settings.$adminUser.enabled
	if ($adminEnabledInput -eq "false") {
		$adminEnabled = "false"
	}

	$addedAdmins[$adminUserName]="done"

	$adminUserSetting = "{ \'name\': \'"+$adminUserName+"\'"
	$adminUserSetting += ","
	$adminUserSetting += "\'password\': \'"+$adminPwd+"\'"
	$adminUserSetting += ","
	$adminUserSetting += "\'enabled\': \'"+$adminEnabled+"\'"
	$adminUserSetting += ","
	$adminUserSetting += "\'roles\': [\'ROLE_MONITORING\']"

	$adminMonitoringPasswordPreExpired=$settings.$adminUser.adminMonitoringPasswordPreExpired
	if ($adminMonitoringPasswordPreExpired.length -gt 0) {
		$adminUserSetting += ","
		$adminUserSetting += "\'adminMonitoringPasswordPreExpired\': \'"+$adminMonitoringPasswordPreExpired+"\'"
	}
	$adminUserSetting += "}"
	$adminUserSetting
}

#function to validate Admin users list ensures it has no special characters, white spaces and emojis.
function ValidateMonitorUserName {
	param($monitoringUserName)

	if ($monitoringUserName.length -gt 0 ) {
		if (!((([regex]"^[\p{L}\p{N}\p{M}\\_]*$").Matches($monitoringUserName)).Value -eq $monitoringUserName)){
			WriteErrorString "Error: MonitorUsername $monitoringUserName can have only combination of alphabetical, digits and underscore from any language"
			exit
		}
	}
	if ($monitoringUserName.length -gt 35) {
		WriteErrorString "Error: MonitorUsername $monitoringUserName must be between 1 and 35 characters in length"
		exit
	}

	return $monitoringUserName

}

# Function to read password from input to a hash.
# Password format: myUser1:pass1word;myUser2:pass2word
function ReadPwdToHash {
	param([string] $newAdminUserPwd, $settings)
	$result=@{}
	if ($newAdminUserPwd.length -le 0) {
		Return $result
	}

	$split = $newAdminUserPwd.Split(";")

	for($i=0; $i -lt $split.length; $i++) {
		$upw = $split[$i].Split(":")
		$isStrongPwd = CheckStrongPwd $upw[1] $settings
		if($isStrongPwd.length -le 0) {
			$result[$upw[0]] = $upw[1]
			Continue
		}
		$un=$upw[0]
		WriteErrorString "Discarding password for user $un. It does not meet the strength requirements."
	}
	$result
}

function CheckStrongPwd {
	Param ([string] $userPwd, $settings)


	if ($settings.General.adminPasswordPolicyMinLen) {
		[int]$passwordPolicyMinLen=GetValue General adminPasswordPolicyMinLen $settings.General.adminPasswordPolicyMinLen 8 64 characters False
	}
	else {
		# Default Min length
		[int]$passwordPolicyMinLen=8
	}

	if ( $userPwd.length -lt $passwordPolicyMinLen ) {
		Return "Error: Password must contain at least $passwordPolicyMinLen characters`nPassword must contain at least $passwordPolicyMinLen characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
	}
	if (([regex]"[0-9]").Matches($userPwd).Count -lt 1 ) {
		Return "Error: Password must contain at least 1 numeric digit`nPassword must contain at least $passwordPolicyMinLen characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
	}
	if (([regex]"[A-Z]").Matches($userPwd).Count -lt 1 ) {
		Return "Error: Password must contain at least 1 upper case character (A-Z)`nPassword must contain at least $passwordPolicyMinLen characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
	}
	if (([regex]"[a-z]").Matches($userPwd).Count -lt 1 ) {
		Return "Error: Password must contain at least 1 lower case character (a-z)`nPassword must contain at least $passwordPolicyMinLen characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
	}
	if (([regex]"[!@#$%*()]").Matches($userPwd).Count -lt 1 ) {
		Return "Error: Password must contain at least 1 special character (!@#$%*())`nPassword must contain at least $passwordPolicyMinLen characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
	}

	Return ""
}

function ValidateSyslogSettingName {
	param($sectionName, $settingName)

	if ($settingName.length -gt 0 ) {
		if (!((([regex]"^[a-zA-Z\d_-]{2,50}$").Matches($settingName)).Value -eq $settingName)){
			WriteErrorString "Error: The name $settingName under section $sectionName can not have special characters other than hyphen and underscore."
			Exit
		}
	}
	if ($settingName.length -gt 50) {
		WriteErrorString "Error: The name $settingName under section $sectionName must be between 1 and 50 characters in length"
		Exit
	}
}

# Function to validate names of different settings. It ensures no special characters other than the allowed
# dot, hyphen, underscore etc are used. White space is allowed between other alloed characters.
function ValidateSettingName {
	param($sectionName, $settingName)

	if ($settingName.length -gt 0 ) {
		if (!((([regex]"^[\p{L}\p{N}\p{M}\\_\\.\\-]+( [\p{L}\p{N}\p{M}\\_\\.\\-]+)*$").Matches($settingName)).Value -eq $settingName)){
			WriteErrorString "Error: The name $settingName under section $sectionName can not have special characters other than dot, hyphen, underscore and whitespace."
			Exit
		}
	}
	if ($settingName.length -gt 50) {
		WriteErrorString "Error: The name $settingName under section $sectionName must be between 1 and 50 characters in length"
		Exit
	}
}

function GetPackageUpdatesSettings {
	Param ($settings)

	if ($settings.PackageUpdates.length -gt 0) {

		$packageUpdatesScheme = $settings.PackageUpdates.packageUpdatesScheme
		if ($packageUpdatesScheme.length -eq 0) {
			$packageUpdatesScheme = "OFF"
		} Elseif ($packageUpdatesScheme -ne "OFF" -And $packageUpdatesScheme -ne "ON_NEXT_BOOT" -And $packageUpdatesScheme -ne "ON_EVERY_BOOT") {
			WriteErrorString "Error: Invalid packageUpdatesScheme value specified. It can be one of OFF/ON_NEXT_BOOT/ON_EVERY_BOOT"
			Exit
		}

		$packageUpdatesSettings = "\'packageUpdatesSettings\': {"
		$packageUpdatesSettings += "\'packageUpdatesScheme\':  \'"+$packageUpdatesScheme.ToUpper()+"\'"
		if ($settings.PackageUpdates.packageUpdatesURL.length -gt 0) {
			$packageUpdatesSettings += ", "
			$packageUpdURL = ValidateWebURIAndPromptForCorrection $settings.PackageUpdates.packageUpdatesURL "PackageUpdates > packageUpdatesURL" $false
			$packageUpdatesSettings += "\'packageUpdatesURL\':  \'"+$packageUpdURL+"\'"
		}
		if ($settings.PackageUpdates.packageUpdatesOSURL.length -gt 0) {
			$packageUpdatesSettings += ", "
			$packageUpdOSURL = ValidateWebURIAndPromptForCorrection $settings.PackageUpdates.packageUpdatesOSURL "PackageUpdates > packageUpdatesOSURL" $false
			$packageUpdatesSettings += "\'packageUpdatesOSURL\':  \'"+$packageUpdOSURL+"\'"
		}

		if ($settings.PackageUpdates.trustedCert1.length -gt 0) {
			$trustedCertificates = GetTrustedCertificates "PackageUpdates" "trustedCert" "trustedCertificates"
			$packageUpdatesSettings += ","
			$packageUpdatesSettings += $trustedCertificates
		}

		$packageUpdatesSettings += "}"

	}

	$packageUpdatesSettings
}


function GetAdminSAMLSettings(){

	param($settings)
	$samlSettings = "";
	if ($settings.adminSAMLSettings.length -gt 0) {
		$enable = $settings.adminSAMLSettings.enable;
		$staticSpEntityId = $settings.adminSAMLSettings.spEntityId;
		$signingAuthNRequestWithAdminCert = $settings.adminSAMLSettings.signAuthNRequestWithAdminCert;
		if ($enable.length -gt 0) {
			$enable = $enable.ToLower();
			if ($enable -eq "true") {
				$entityId = $settings.adminSAMLSettings.entityId;
				if ($entityId.length -eq 0) {
					WriteErrorString "entityId needs to be provided if adminSAMLSetting has been enabled."
					Exit
				}
				$samlSettings = "'adminSAMLSettings': { \'enable': true, \'entityId\': \'"+$entityId+"\' "
				if ($signingAuthNRequestWithAdminCert -eq "true") {
					$samlSettings += ","
					$samlSettings += "\'signingAuthNRequestWithAdminCert\': true"
				}
				else
				{
					$samlSettings += ","
					$samlSettings += "\'signingAuthNRequestWithAdminCert\': false"
				}
				if ($staticSpEntityId.length -gt 0)
				{
					$samlSettings += ","
					$samlSettings += "\'spEntityId\': \'" + $staticSpEntityId + "\'"
				}
				$samlSettings += "}"
			} elseif($enable -eq "false") {
				$samlSettings = "\'adminSAMLSettings\': { \'enable\': false }"
			} else {
				WriteErrorString "enable value in [adminSAMLSettings] should either be true or false."
				Exit
			}
		}
		else {
			WriteErrorString "adminSAMLSettings section is available in INI but enable attribute is not available."
			Exit
		}
	}
	return $samlSettings;
}

function GetJSONSettings {
	Param ($settings, [string] $newAdminUserPwd)

	$settingsJSON = "{"

	$certificateWrapper = GetCertificateWrapper ($settings)
	if ($certificateWrapper.length -gt 0) {
		$settingsJSON += $certificateWrapper
		$settingsJSON += ", "
	}

	$certificateWrapperAdmin = GetCertificateWrapper $settings "Admin"
	if ($certificateWrapperAdmin.length -gt 0) {
		$settingsJSON += $certificateWrapperAdmin
		$settingsJSON += ", "
	}

	$systemSettings = GetSystemSettings ($settings)

	$edgeServiceSettings = GetEdgeServiceSettings ($settings)

	$authMethodSettings = GetAuthMethodSettings ($settings)

	$samlServiceProviderMetadata = GetSAMLServiceProviderMetadata ($settings)

	$ssoSamlIdpSetting = GetSsoSamlIdpSetting ($settings)

	$samlIdentityProviderMetadata = GetSAMLIdentityProviderMetadata ($settings)

	$jwtSettings = GetJWTSettings ($settings)
	if ($jwtSettings.length -gt 0) {
		$settingsJSON += $jwtSettings
		$settingsJSON += ", "
	}

	$jwtIssuerSettings = GetJWTIssuerSettings ($settings)
	if ($jwtIssuerSettings.length -gt 0) {
		$settingsJSON += $jwtIssuerSettings
		$settingsJSON += ", "
	}

	$proxySettings = GetProxySettings($settings)
	if($proxySettings.length -gt 0){
		$settingsJSON += $proxySettings
		$settingsJSON += ", "
	}

	$loadBalancerSettings = GetLoadBalancerSettings ($settings)
	if ($loadBalancerSettings.length -gt 0) {
		$settingsJSON += $loadBalancerSettings
		$settingsJSON += ", "
	}

	$keytabSettings = GetKeytabSettings ($settings)
	if ($keytabSettings.length -gt 0) {
		$settingsJSON += $keytabSettings
		$settingsJSON += ", "
	}

	$kerberosRealmSettings = GetkerberosRealmSettings ($settings)
	if ($kerberosRealmSettings.length -gt 0) {
		$settingsJSON += $kerberosRealmSettings
		$settingsJSON += ", "
	}

	$externalMetadataSettings = GetIDPExternalMetadataSettings ($settings)
	if ($externalMetadataSettings.length -gt 0) {
		$settingsJSON += $externalMetadataSettings
		$settingsJSON += ", "
	}

	$devicePolicySettings = GetDevicePolicySettings ($settings)
	if ($devicePolicySettings.length -gt 0) {
		$settingsJSON += $devicePolicySettings
		$settingsJSON += ", "
	}


	$customExecutableSettings = GetCustomExecutableSettings ($settings)
	if ($customExecutableSettings.length -gt 0) {
		$settingsJSON += $customExecutableSettings
		$settingsJSON += ", "
	}

	$workspaceOneIntelligenceSettings = GetWorkspaceOneIntelligenceSettings ($settings)
	if ($workspaceOneIntelligenceSettings.length -gt 0) {
		$settingsJSON += $workspaceOneIntelligenceSettings
		$settingsJSON += ", "
	}

	$workspaceOneIntelligenceDataSettings = GetWorkspaceOneIntelligenceDataSettings ($settings)
	if ($workspaceOneIntelligenceDataSettings.length -gt 0) {
		$settingsJSON += $workspaceOneIntelligenceDataSettings
		$settingsJSON += ", "
	}

	$ocspSigningCertList = GetOCSPSigningCertSettings ($settings)
	if ($ocspSigningCertList.length -gt 0) {
		$settingsJSON += $ocspSigningCertList
		$settingsJSON += ", "
	}

	$newAdminUserSettings = GetNewAdminUserSettings $settings $newAdminUserPwd
	if ($newAdminUserSettings.length -gt 0) {
		$settingsJSON += $newAdminUserSettings
		$settingsJSON += ", "
	}

	$packageUpdatesSettings = GetPackageUpdatesSettings($settings)
	if ($packageUpdatesSettings.length -gt 0) {
		$settingsJSON += $packageUpdatesSettings
		$settingsJSON += ", "
	}

	$syslogUrlSettings = GetSyslogSettings($settings)
	if ($syslogUrlSettings.length -gt 0) {
		$settingsJSON += $syslogUrlSettings
		$settingsJSON += ", "
	}

	$adminSMLSettings = GetAdminSAMLSettings($settings)
	if($adminSMLSettings.length -gt 0) {
		$settingsJSON += $adminSMLSettings
		$settingsJSON += ","
	}

	$securityAgentSettings = GetSecurityAgentsSettings ($settings)
	if ($securityAgentSettings.length -gt 0) {
		$settingsJSON += $securityAgentSettings
		$settingsJSON += ", "
	}

	$authMethodSettingsOidc = GetAuthMethodSettingsOidc ($settings)
	if ($authMethodSettingsOidc.length -gt 0) {
		$settingsJSON += $authMethodSettingsOidc
		$settingsJSON += ", "
	}

	$settingsJSON += $edgeServiceSettings+", "+$systemSettings+", "+$authMethodSettings+", "+$samlServiceProviderMetadata+", "+$ssoSamlIdpSetting+", "+$samlIdentityProviderMetadata+"}"

	$settingsJSON = $settingsJSON -replace "'", '"'
	$settingsJSON = $settingsJSON -replace "\\047", "'"

	#If any value in INI file ends with backslash (which comes up in settingsJson as \\"), that needs to be actually included in settingsJson as four backslashes one after the other; the fifth backslash (from the beginning, in the second argument of the function) is used to escape double quote. So, the complete replacement would be \\\\\". If this is not done, the resulting settingsJson will not be well-formed and hence cannot be parsed by UAG's admin. The last 3 characters, (i.e. ,\"), are used so that this gets matched with only those values which end with backslash (these characters signify the beginning of another json key).

	$settingsJSON = $settingsJSON.replace('\\",\"','\\\\\",\"')

	$settingsJSON

}

function AddKVPUnit {
	param($VMName, $key, $value)

	#
	# Add Key-Value Pairs for the VM
	#

	#if ($key.Contains("Password")) {
	#    Write-Host "Setting $key=******"
	#} else {
	#    Write-Host "Setting $key=$value"
	#}

	$VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
	$Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }  #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter {ElementName='TEST-APP38'}     # has to be same as $VMName

	$kvpDataItem = ([WMIClass][String]::Format("\\{0}\{1}:{2}", $VmMgmt.ClassPath.Server, $VmMgmt.ClassPath.NamespacePath, "Msvm_KvpExchangeDataItem")).CreateInstance()
	$null=$KvpItem.psobject.properties
	$kvpDataItem.Name = $key
	$kvpDataItem.Data = $value
	$kvpDataItem.Source = 0
	$result = $VmMgmt.AddKvpItems($Vm, $kvpDataItem.PSBase.GetText(1))

	$job = [wmi]$result.Job

	if (!$job) {
		WriteErrorString "Error: Failed to set KVP $key on $VMName"
		Return
	}

	if ($job) {
		$job.get()
		#write-host $job.jobstate
		#write-host $job.SystemProperties.Count.ToString()
	}

	while($job.jobstate -lt 7) {
		$job.get()
		Start-Sleep -Seconds 2
	}

	if ($job.ErrorCode -ne 0) {
		WriteErrorString "Error: Failed to set KVP $key on $VMName (error code $($job.ErrorCode))"
		Return
	}

	if ($job.Status -ne "OK") {
		WriteErrorString "Error: Failed to set KVP $key on $VMName (status $job.Status)"
		Return
	}

	$job
}

function GetKVP {
	param($VMName, $key)

	$VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
	$Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }  #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter {ElementName='TEST-APP38'}     # has to be same as $VMName

	$n = $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems
	$n = $vm.GetRelated("Msvm_KvpExchangeComponent").GuestExchangeItems

	$n = $vm.GetRelated("Msvm_KvpExchangeComponent").GetRelated('Msvm_KvpExchangeComponentSettingData').HostExchangeItems

	$n | % {
		$GuestExchangeItemXml = ([XML]$_).SelectSingleNode(`
            "/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='$key']")

		if ($GuestExchangeItemXml -ne $null)
		{
			$val = $GuestExchangeItemXml.SelectSingleNode( `
                "/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value
			$val
			Return
		}
	}
}

function AddKVP {
	param($VMName, $key, $value)
	$max = 1000
	$len=$value.length
	$index=0
	if ($len -le $max) {
		$job=AddKVPUnit $VMName $key $value
	} else {
		for ($i=0; $i -lt $len; $i += $max) {
			$chunkSize = [Math]::Min($max, ($len - $i))
			$valueChunk=$value.Substring($i, $chunkSize)
			$keyChunk=$key+"."+$index.ToString(0)
			$job=AddKVPUnit $VMName $keyChunk $valueChunk
			$index++
		}
	}
	$job
}

function DeleteKVP {
	param($VMName, $key)

	$VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService
	$Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }

	$kvpDataItem = ([WMIClass][String]::Format("\\{0}\{1}:{2}", $VmMgmt.ClassPath.Server, $VmMgmt.ClassPath.NamespacePath, "Msvm_KvpExchangeDataItem")).CreateInstance()
	$null=$KvpItem.psobject.properties
	$kvpDataItem.Name = $key
	$kvpDataItem.Data = [String]::Empty
	$kvpDataItem.Source = 0
	$result = $VmMgmt.RemoveKvpItems($Vm, $kvpDataItem.PSBase.GetText(1))

	$job = [wmi]$result.Job

	if (!$job) {
		WriteErrorString "Error: Failed to set KVP $key on $VMName"
		Return
	}

	if ($job) {
		$job.get()
		#write-host $job.jobstate
		#write-host $job.SystemProperties.Count.ToString()
	}

	while($job.jobstate -lt 7) {
		$job.get()
		Start-Sleep -Seconds 2
	}

	if ($job.ErrorCode -ne 0) {
		WriteErrorString "Error: Failed to set KVP $key on $VMName (error code $($job.ErrorCode))"
		Return
	}

	$job
}

function DeleteKVPAll {
	param($VMName)

	$VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService
	$Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }

	$hostExchangeItems = $vm.GetRelated("Msvm_KvpExchangeComponent").GetRelated('Msvm_KvpExchangeComponentSettingData').HostExchangeItems

	$hostExchangeItems | % {

		$GuestExchangeItemXml = ([XML]$_).SelectSingleNode(`
        "/INSTANCE/PROPERTY[@NAME='Name']/VALUE")
		$key = $GuestExchangeItemXml.InnerText

		if ($key.length -gt 0) {
			$job = DeleteKVP $VMName $key
		}
	}
}

function IsVMDeployed {
	param ($VMName, $ipAddress)
	#
	# WE consider the VM to be deployed if we can obtain an IP address from it and the ip address matches what is configured.
	#

	$out=Get-VM $VMName | ?{$_.ReplicationMode -ne "Replica"} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
	if ($ipAddress.length -gt 0) {
		#static IP address
		if (($out.IPAddresses)[0] -eq $ipAddress) {
			return $true
		}
	} else {
		#DHCP
		if  ((($out.IPAddresses)[0]).length -gt 0) {
			$wait = 0
			#sleep for 4 mins (240 secs) to give time for the appliance to be ready
			while ($wait -le 240) {
				if ($isTerraform -ne "true") {
					Write-Host -NoNewline "."
				}
				$wait += 2
				Start-Sleep -Seconds 2
			}
			return $true
		}
	}

	return $false
}

function IsVMUp {
	param ($VMName, [ref]$ipAddress)

	#
	# WE consider the VM to be up if we can obtain an IP address from it.
	#

	$out=Get-VM $VMName | ?{$_.ReplicationMode -ne "Replica"} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
	if ($out.IPAddresses.Length -gt 0) {
		$ipAddress = ($out.IPAddresses)[0]
		return $true
	}

	return $false
}

function GetMaskLength {
	Param ($settings, $nic)

	$ipLabel = "ip" + $nic
	$ip=$settings.General.$ipLabel

	$netmaskLabel = "netmask" + $nic
	$netmask=$settings.General.$netmaskLabel

	$mask = [ipaddress] $netmask
	$binary = [convert]::ToString($mask.Address, 2)
	$mask_length = ($binary -replace 0,$null).Length

	$mask_length

}

function GetNetOptions {
	Param ($settings, $nic)

	$ipModeLabel = "ipMode" + $nic
	$ipMode = $settings.General.$ipModeLabel

	$ipLabel = "ip" + $nic
	$ip=$settings.General.$ipLabel

	$netmaskLabel = "netmask" + $nic
	$netmask=$settings.General.$netmaskLabel

	$v6ipLabel = "v6ip" + $nic
	$v6ip=$settings.General.$v6ipLabel

	$v6ipprefixLabel = "v6ipprefix" + $nic
	$v6ipprefix=$settings.General.$v6ipprefixLabel

	$customConfigLabel = "eth"+$nic+"CustomConfig"
	$customConfig=$settings.General.$customConfigLabel

	#
	# IPv4 address must have a netmask
	#

	if (($ip.length -gt 0) -and ($netmask.length -eq 0)) {
		WriteErrorString "Error: missing value $netmaskLabel."
		Exit
	}

	#
	# IPv6 address must have a prefix
	#

	if (($v6ip.length -gt 0) -and ($v6ipprefix.length -eq 0)) {
		WriteErrorString "Error: missing value $v6ipprefixLabel."
		Exit
	}

	#
	# If ipMode is not specified, assign a default
	#

	if ($ipMode.length -eq 0) {

		$ipMode = "DHCPV4"

		if (($ip.length -gt 0) -and ($v6ip.length -eq 0)) {
			$ipMode = "STATICV4"
		}

		if (($ip.length -eq 0) -and ($v6ip.length -gt 0)) {
			$ipMode = "STATICV6"
		}

		if (($ip.length -gt 0) -and ($v6ip.length -gt 0)) {
			$ipMode = "STATICV4+STATICV6"
		}
	}

	$options = @()
	if ($customConfig.length -gt 0) {
		$customConfig = ValidateCustomConfigAndPromptForCorrection $customConfig $customConfigLabel
		$customConfig = $customConfig -replace '"', '\"'
		$customConfig = $customConfig -replace "'", "\047"
		$options += "--prop:$customConfigLabel=$customConfig"
	}

	#
	# Assign network properties based on the 11 supported combinations
	#

	switch ($ipMode) {


		{ ($_ -eq "DHCPV4") -or ($_ -eq "DHCPV4+DHCPV6") -or ($_ -eq "DHCPV4+AUTOV6") -or ($_ -eq "DHCPV6") -or ($_ -eq "AUTOV6") } {

			#
			# No addresses required
			#

			$options += "--prop:ipMode$nic=$ipMode"
			$options
			return
		}

		{ ($_ -eq "STATICV6") -or ($_ -eq "DHCPV4+STATICV6") } {

			#
			# IPv6 address and prefix required
			#

			if ($v6ip.length -eq 0) {
				WriteErrorString "Error: missing value $v6ipLabel."
				Exit
			}
			$options += "--prop:ipMode$nic=$ipMode"
			$options += "--prop:v6ip$nic=$v6ip"
			$options += "--prop:forceIpv6Prefix$nic=$v6ipprefix"
			$options
			return
		}

		{ ($_ -eq "STATICV4") -or ($_ -eq "STATICV4+DHCPV6") -or ($_ -eq "STATICV4+AUTOV6") } {

			#
			# IPv4 address and netmask required
			#

			if ($ip.length -eq 0) {
				WriteErrorString "Error: missing value $ipLabel."
				Exit
			}
			$options += "--prop:ipMode$nic=$ipMode"
			$options += "--prop:ip$nic=$ip"
			$options += "--prop:forceNetmask$nic=$netmask"
			$options
			return
		}

		{ "STATICV4+STATICV6" } {

			#
			# IPv4 address, netmask, IPv6 address and prefix required
			#

			if ($ip.length -eq 0) {
				WriteErrorString "Error: missing value $ipLabel."
				Exit
			}
			if ($v6ip.length -eq 0) {
				WriteErrorString "Error: missing value $v6ipLabel."
				Exit
			}
			$options += "--prop:ipMode$nic=$ipMode"
			$options += "--prop:ip$nic=$ip"
			$options += "--prop:forceNetmask$nic=$netmask"
			$options += "--prop:v6ip$nic=$v6ip"
			$options += "--prop:forceIpv6Prefix$nic=$v6ipprefix"
			$options
			return
		}

		#
		# Invalid
		#

		default {
			WriteErrorString "Error: Invalid value ($ipModeLabel=$ipMode)."
			Exit

		}
	}
}

function GetCustomConfigEntry
{
	Param ($settings, $nic)
	$customConfigValue = GetCustomConfigValue $settings $nic
	if($customConfigValue.length -gt 0){
		$customConfigLabel = "eth"+$nic+"CustomConfig"
		return "$customConfigLabel="+$customConfigValue
	}
	return
}

function GetCustomConfigValue
{
	Param ($settings, $nic)
	$customConfigLabel = "eth"+$nic+"CustomConfig"
	$customConfig=$settings.General.$customConfigLabel

	if ($customConfig.length -gt 0) {
		$customConfig = ValidateCustomConfigAndPromptForCorrection $customConfig $customConfigLabel
		$customConfig = $customConfig -replace '"', '\"'
		$customConfig = $customConfig -replace "'", "\047"
		return $customConfig
	}
	return
}

function SetKVPNetOptions {
	Param ($settings, $VMName, $nic)

	$ipModeLabel = "ipMode" + $nic
	$ipMode = $settings.General.$ipModeLabel

	$ipLabel = "ip" + $nic
	$ip=$settings.General.$ipLabel

	$netmaskLabel = "netmask" + $nic
	$netmask=$settings.General.$netmaskLabel

	$v6ipLabel = "v6ip" + $nic
	$v6ip=$settings.General.$v6ipLabel

	$v6ipprefixLabel = "v6ipprefix" + $nic
	$v6ipprefix=$settings.General.$v6ipprefixLabel

	$customConfigValue = GetCustomConfigValue $settings $nic
	if($customConfigValue.length -gt 0)
	{
		$customConfigLabel = "eth"+$nic+"CustomConfig"
		$job=AddKVP $VMName $customConfigLabel $customConfigValue
	}

	#
	# IPv4 address must have a netmask
	#

	if (($ip.length -gt 0) -and ($netmask.length -eq 0)) {
		WriteErrorString "Error: missing value $netmaskLabel."
		Exit
	}

	#
	# IPv6 address must have a prefix
	#

	if (($v6ip.length -gt 0) -and ($v6ipprefix.length -eq 0)) {
		WriteErrorString "Error: missing value $v6ipprefixLabel."
		Exit
	}

	#
	# If ipMode is not specified, assign a default
	#

	if ($ipMode.length -eq 0) {

		$ipMode = "DHCPV4"

		if (($ip.length -gt 0) -and ($v6ip.length -eq 0)) {
			$ipMode = "STATICV4"
		}

		if (($ip.length -eq 0) -and ($v6ip.length -gt 0)) {
			$ipMode = "STATICV6"
		}

		if (($ip.length -gt 0) -and ($v6ip.length -gt 0)) {
			$ipMode = "STATICV4+STATICV6"
		}
	}

	#
	# Assign network properties based on the 11 supported combinations
	#

	switch ($ipMode) {


		{ ($_ -eq "DHCPV4") -or ($_ -eq "DHCPV4+DHCPV6") -or ($_ -eq "DHCPV4+AUTOV6") -or ($_ -eq "DHCPV6") -or ($_ -eq "AUTOV6") } {

			#
			# No addresses required
			#

			$job=AddKVP $VMName "ipMode$nic" $ipMode

			return
		}

		{ ($_ -eq "STATICV6") -or ($_ -eq "DHCPV4+STATICV6") } {

			#
			# IPv6 address and prefix required
			#

			if ($v6ip.length -eq 0) {
				WriteErrorString "Error: missing value $v6ipLabel."
				Exit
			}
			$job=AddKVP $VMName "ipMode$nic" $ipMode
			$job=AddKVP $VMName "v6ip$nic" $v6ip
			$job=AddKVP $VMName "forceIpv6Prefix$nic" $v6ipprefix

			return
		}

		{ ($_ -eq "STATICV4") -or ($_ -eq "STATICV4+DHCPV6") -or ($_ -eq "STATICV4+AUTOV6") } {

			#
			# IPv4 address and netmask required
			#

			if ($ip.length -eq 0) {
				WriteErrorString "Error: missing value $ipLabel."
				Exit
			}
			$job=AddKVP $VMName "ipMode$nic" $ipMode
			$job=AddKVP $VMName "ip$nic" $ip
			$job=AddKVP $VMName "forceNetmask$nic" $netmask

			return
		}

		{ "STATICV4+STATICV6" } {

			#
			# IPv4 address, netmask, IPv6 address and prefix required
			#

			if ($ip.length -eq 0) {
				WriteErrorString "Error: missing value $ipLabel."
				Exit
			}
			if ($v6ip.length -eq 0) {
				WriteErrorString "Error: missing value $v6ipLabel."
				Exit
			}
			$job=AddKVP $VMName "ipMode$nic" $ipMode
			$job=AddKVP $VMName "ip$nic" $ip
			$job=AddKVP $VMName "forceNetmask$nic" $netmask
			$job=AddKVP $VMName "v6ip$nic" $v6ip
			$job=AddKVP $VMName "forceIpv6Prefix$nic" $v6ipprefix

			return
		}

		#
		# Invalid
		#

		default {
			WriteErrorString "Error: Invalid value ($ipModeLabel=$ipMode)."
			Exit

		}
	}
}
function GetSettingsJSONProperty {
	param($value)
	$max = 65535
	$len=$value.length
	$index=0
	$key="settingsJSON"
	$jsonString=""
	$maxLengthAllowed=16 *$max
	if ($len -le $max) {
		$jsonString=AddSettingJsonUnit $jsonString $key $value
	} Elseif ($len -gt $maxLengthAllowed){
		WriteErrorString "Provided settings exceeds max allowed settings that can be deployed."
		Exit 1
	}
	else {
		for ($i=0; $i -lt $len; $i += $max) {
			$chunkSize = [Math]::Min($max, ($len - $i))
			$valueChunk=$value.Substring($i, $chunkSize)
			$keyChunk=$key+"-"+$index.ToString(0)
			$jsonString=AddSettingJsonUnit $jsonString $keyChunk $valueChunk
			$index++
		}
	}
	$jsonString
}

function AddSettingJsonUnit {
	param($existingValue, $key, $value)
	$existingValueLen=$existingValue.length
	$jsonString=$existingValue
	if ($existingValueLen -gt 0) {
		$jsonString += "`r`n"
	}
	$jsonString += "prop:"+$key+"="
	$jsonString += $value

	$jsonString

}

function GetDeploymentSettingOption {
	param ($settings)
	$deploymentOption=$settings.General.deploymentOption

	if (!$deploymentOption) {
		$deploymentOption="onenic"
	} Elseif ($deploymentOption -eq "onenic-L") {
		$deploymentOption="onenic-large"
	} Elseif ($deploymentOption -eq "twonic-L") {
		$deploymentOption="twonic-large"
	} Elseif ($deploymentOption -eq "threenic-L") {
		$deploymentOption="threenic-large"
	}

	$deploymentOption
}

function GetOCSPUrlSource {
	Param($settings)

	# Use OCSPURLSource if specified by user (or due to ini export!!) then use that value. Else try to deduce with other settings
	if ($settings.CertificateAuth.ocspURLSource.length -gt 0) {
		$ocspURLSource = $settings.CertificateAuth.ocspURLSource
	} Else {
		$useOCSPUrlInCert="false"
		if ($settings.CertificateAuth.useOCSPUrlInCert -eq "true") {
			$useOCSPUrlInCert="true"
		}
		$ocspUrl = $settings.CertificateAuth.ocspUrl

		if ($useOCSPUrlInCert -eq "false" -And $ocspUrl.length -eq 0) {
			WriteErrorString "Either use ocsp url in certificate [useOCSPUrlInCert=true] or set an ocsp url[ocspUrl] to use"
			Exit
		} ElseIf ($useOCSPUrlInCert -eq "true" -And $ocspUrl.length -gt 0) {
			$ocspURLSource="cert_and_config"
		} ElseIf ($useOCSPUrlInCert -eq "true") {
			$ocspURLSource="cert_only_required"
		} Else {
			$ocspURLSource="config_only"
		}
	}

	$ocspURLSource
}

function GetOCSPSigningCertSettings {
	Param($settings)
	$ocspCertCount = 0
	$allCerts = "\'ocspSigningCerts\': [ "
	for($i=1;;$i++)
	{
		$cert = "ocspSigningCert$i"
		$cert = $settings.OCSPSigningCertificates.$cert
		if($cert.length -gt 0)
		{
			if (!(Test-path $cert)) {
				WriteErrorString "Error: PEM Certificate file not found ($cert)"
				Exit
			}
			else
			{
				$content = (Get-Content $cert | Out-String) -replace "'", "\\047" -replace [Environment]::NewLine  , "\\n"

				if ($content -like "*-----BEGIN CERTIFICATE-----*") {

				} else {
					WriteErrorString "Error: Invalid certificate file It must contain -----BEGIN CERTIFICATE-----."
					Exit
				}
				$allCerts += "\'"+$content+"\'"+","
			}
			$ocspCertCount++
		} else {
			$allCerts = $allCerts.Substring(0, $allCerts.Length-1)
			break;
		}
	}
	$allCerts += "]"

	if ($ocspCertCount -gt 0) {
		$ocspSigningCertList = "\'ocspSigningCertList\': { " + $allCerts + " }"
	}

	$ocspSigningCertList
}

function ValidateLabelLength {
	Param ($labelName, $label, $labelMaxLength)

	if($label.length -gt $labelMaxLength) {
		WriteErrorString "Error: $labelName cannot have more than $labelMaxLength characters"
		Exit
	}
}

# Checks if a field's value is an integer and is either 0 OR falls within the passed range
function GetValue {
	Param ($iniSection, $fieldName, $fieldValue, $fieldMinValue, $fieldMaxValue, $timeUnit, $isZeroAllowed)

	if ($fieldValue.length -gt 0) {
		try {
			$fieldValue = [int]$fieldValue
		} catch {
			WriteErrorString "Error: $fieldName in the section $iniSection is not an integer"
			Exit
		}
		if ($isZeroAllowed -ieq "True") {
			if (($fieldValue -ne 0) -and (($fieldValue -lt $fieldMinValue) -or ($fieldValue -gt $fieldMaxValue))) {
				WriteErrorString "Error: $fieldName can be either 0 or between $fieldMinValue $timeUnit - $fieldMaxValue $timeUnit (both inclusive) in the section $iniSection"
				Exit
			}
		} Elseif (($fieldValue -lt $fieldMinValue) -or ($fieldValue -gt $fieldMaxValue)) {
			WriteErrorString "Error: $fieldName should be between $fieldMinValue $timeUnit - $fieldMaxValue $timeUnit (both inclusive) in the section $iniSection"
			Exit
		}
	}
	$fieldValue
}

# Adds a JSON key, value pair and returns that string
function addJsonElement {
	Param ($iniSection, $mandatoryFields, $listOfFieldsToBeIgnored, $fieldNameToCheck, $fieldValue)

	$isFieldMandatory = "" + $mandatoryFields.Contains($fieldNameToCheck)
	$isFieldToBeIgnored = "" + $listOfFieldsToBeIgnored.Contains($fieldNameToCheck)

	# If a field's value is not specified and it is marked as mandatory
	if ($fieldValue.length -eq 0 -and $isFieldMandatory -ieq "True") {
		WriteErrorString "Error: $fieldNameToCheck is mandatory to be specified in the section $iniSection"
		Exit
	}

	# If a field's value is specified and it is not marked as ignored
	if ($fieldValue.length -gt 0 -and $isFieldToBeIgnored -ieq "False") {
		$uagSettings = "\'" + $fieldNameToCheck + "\': \'$fieldValue\'"
		$uagSettings += ","
	}

	$uagSettings
}

function removeTrailingDelimiter {
	Param ($uagSettings)

	if ($uagSettings.Substring($uagSettings.Length-1, 1) -eq ",") {
		$uagSettings = $uagSettings.Substring(0, $uagSettings.Length-1)
	}

	$uagSettings
}

# The Windows environments from which PowerShell script is used to deploy UAG on Azure, EC2 or GCE may not have ovftool
# installed as it's not a requirement for installation on these hypervisors. Hence, VMware dir may not be present
# in APPDATA dir, if no other VMWare product is installed in that Windows machine. Since, the configured UAG
# settings are temporarily persisted in a file in VMware dir in that machine, presence of VMware dir is a must.
# This function creates that dir, if it is not present. This is not needed for HyperV.
function SetUp {

	$os = [environment]::OSVersion.Platform
	if ($os -like 'win*') {
		$vmwareDir = "${env:APPDATA}\VMware"
	} else {
		$vmwareDir = "/tmp/VMware"
	}

	if (!(Test-path $vmwareDir)) {
		if ($isTerraform -ne "true") {
			Write-host "Creating the directory $vmwareDir, since it is not present"
		}
		New-Item -ItemType Directory -Force -Path $vmwareDir | out-null

		if(!(Test-path $vmwareDir)) {
			WriteErrorString "Error: The directory $vmwareDir could not be created."
			exit
		}
	}
	return $vmwareDir

}

# Method to validate if the provided string is an url
# Optionally, check If the scheme (protocol) matches the required format.
# Eg for $allowedSchemeRegex: ^https?$
function ValidateStringIsURI {
	Param ($str, $allowedSchemeRegex)

	$uri = $str -as [System.URI]
	if ($allowedSchemeRegex -eq $null)
	{
		return $uri.AbsoluteURI -ne $null
	}
	return $uri.AbsoluteURI -ne $null -and ([regex]$allowedSchemeRegex).Matches($uri.Scheme).Success
}

# Shorthand method to check if provided string is a valid web url
function ValidateStringIsWebURI {
	Param ($str, $isSecure)
	if ($isSecure -eq $true)
	{
		return ValidateStringIsURI $str '^https$'
	}
	return ValidateStringIsURI $str '^https?$'
}

# Method to check if provided string is a valid web url.
# If not, prompt the user to input an approprite web url indefinitely.
function ValidateWebURIAndPromptForCorrection {
	Param ($str, $uriLabel, $isSecure)

	$isWebUri = ValidateStringIsWebURI $str $isSecure
	if (-not $isWebUri)
	{
		WriteErrorString "Field $uriLabel does not follow the required pattern. Input value: $str"
		$str = Read-Host "Please provide a valid URL"
		$str = ValidateWebURIAndPromptForCorrection $str $uriLabel $isSecure
	}
	$uri = $str -as [System.URI]
	# remove trailing slash if exists
	return $uri.AbsoluteURI.trim('/')
}


# Method to validate syslog url input
# If not, prompt the user to input an approprite web url indefinitely.
# Syslog fields accept up to two urls and they can optionally have scheme and port
function ValidateSyslogUrlInputAndPromptForCorrection {
	Param ($str, $uriLabel)

	$urls = $str.split(',')
	if($urls.length -gt 2){
		WriteErrorString "Syslog URLs cannot be more than two for field $uriLabel. Provided input: $str"
		$str = Read-Host "Please provide a valid input."
		return ValidateSyslogUrlInputAndPromptForCorrection $str $uriLabel
	}
	$res = $true
	for($i=0;$i -lt $urls.length;$i++)
	{
		$sl = $urls[$i].trim()
		$res = $res -and ((ValidateStringIsURI $sl '^syslog$') -or (ValidateHostPort $sl))
	}
	if ($res -eq $false){
		WriteErrorString "Syslog URL is not in an acceptable format for field $uriLabel. Syslog can be host name or IP address, optionally with syslog:// scheme and port. Provided input: $str"
		$str = Read-Host "Please provide a valid input."
		return ValidateSyslogUrlInputAndPromptForCorrection $str $uriLabel
	}
	$uri = $str -as [System.URI]
	# remove trailing slash if exists
	return $uri.AbsoluteURI.trim('/')
}


# Method to validate the host and port combination in the given string
# Regex source: https://stackoverflow.com/a/106223
# IPv6 Regex source: https://www.powershelladmin.com/wiki/PowerShell_.NET_regex_to_validate_IPv6_address_(RFC-compliant)
function ValidateHostPort {
	Param ($str)

	if($str.split(':').count -gt 2){
		# IPv6
		$ipv6 = $str
		If ($str.contains(']')) {
			$ipv6,$port = $str.split(']')
			$port = $port.split(":")[1]
			$ipv6 = $ipv6.split("[")[1]
		}
		return (ValidateHostNameOrIP $ipv6) -And (ValidatePort $port)
	} else {
		$hostIp,$port = $str.split(':')
		return (ValidatePort $port) -And (ValidateHostNameOrIP $hostIp)
	}
}

function ValidateHostNameOrIP {
	Param ($str)

	$ip6Regex = [regex]'^:(?::[a-f\d]{1,4}){0,5}(?:(?::[a-f\d]{1,4}){1,2}|:(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})))|[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}:(?:[a-f\d]{1,4}|:)|(?::(?:[a-f\d]{1,4})?|(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))))|:(?:(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|[a-f\d]{1,4}(?::[a-f\d]{1,4})?|))|(?::(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|:[a-f\d]{1,4}(?::(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[a-f\d]{1,4}){0,2})|:))|(?:(?::[a-f\d]{1,4}){0,2}(?::(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[a-f\d]{1,4}){1,2})|:))|(?:(?::[a-f\d]{1,4}){0,3}(?::(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[a-f\d]{1,4}){1,2})|:))|(?:(?::[a-f\d]{1,4}){0,4}(?::(?:(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))|(?::[a-f\d]{1,4}){1,2})|:))$'
	$hostRegex = [regex]'^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'
	$ipRegex = [regex]'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'

	if($str.split(':').count -gt 2){
		# IPv6
		return $ip6Regex.Matches($str).Success
	} else {
		return $hostRegex.Matches($str).Success -Or $ipRegex.Matches($str).Success
	}
}

function ValidateNumber{
	Param($num)

	if($num.length -gt 0){
		if(([regex]'^[\D]').Matches($num).Success){
			return $false;
		}
	}
	return $true
}


function ValidatePort {
	Param ($port)

	if($port.length -gt 0 ){
		if(-Not ([regex]'^[\d]{1,5}$').Matches($port).Success){
			return $false;
		}
		$port=[int]$port
		if($port -gt 65535){
			return $false;
		}
	}
	return $true
}

function ValidateRootSessionIdleTimeoutSeconds
{
	Param($settings)
	$rootSessionTimeout = $settings.General.rootSessionIdleTimeoutSeconds
	if ($rootSessionTimeout.length -gt 0)
	{
		if (!(([regex]'^[+]?([0-9]+)$').Matches($rootSessionTimeout).Success))
		{
			WriteErrorString "Invalid value: $rootSessionTimeout for field rootSessionIdleTimeoutSeconds, only positive numbers are allowed."
			exit
		}
		$rootSessionTimeout = [int]$rootSessionTimeout
		if ([int]$rootSessionTimeout -gt 0 -And ([int]$rootSessionTimeout -lt 30 -Or [int]$rootSessionTimeout -gt 3600))
		{
			WriteErrorString "Invalid value: $rootSessionTimeout for field rootSessionIdleTimeoutSeconds , allowed values 0, 30-3600."
			exit
		}

	}
	return $settings.General.rootSessionIdleTimeoutSeconds
}

function ValidateAdminMaxConcurrentSessions
{
	Param($settings)
	$adminMaxConcurrentSessions=$settings.General.adminMaxConcurrentSessions
	if ($adminMaxConcurrentSessions.length -gt 0)
	{
		if (!(([regex]'^[+]?([0-9]+)$').Matches($adminMaxConcurrentSessions).Success))
		{
			WriteErrorString "Invalid value: $adminMaxConcurrentSessions for field adminMaxConcurrentSessions, values between 1 to 50 (both inclusive) are allowed."
			exit
		}
		$adminConcurrentSessionLimit = $adminMaxConcurrentSessions
		if ([int]$adminConcurrentSessionLimit -lt 1 -or [int]$adminConcurrentSessionLimit -gt 50)
		{
			WriteErrorString "Invalid value: $adminConcurrentSessionLimit for field adminMaxConcurrentSessions, values between 1 to 50 (both inclusive) are allowed."
			exit
		}
	}
	return $adminMaxConcurrentSessions
}

function ValidateHostPortAndPromptForCorrection {
	Param ($str, $label)

	if(ValidateHostPort $str){
		return $str;
	}
	WriteErrorString "Host / Host-Port input: $str is not in an acceptable format for field $label."
	$str = Read-Host "Please provide a valid input."
	return ValidateHostPortAndPromptForCorrection $str $label
}

function ValidateCustomConfigAndPromptForCorrection {
	Param ($str, $label)

	$str2 = $str
	if(-Not ($str2.endswith(";"))){
		$str2 += ";"
	}

	$ccRegex = [regex]'^(([a-zA-Z0-9\-]+)\^[a-zA-Z0-9\-]+=[a-zA-Z0-9:!,~''"%#_@\[\]\.\s\-]*;)+$'

	if($ccRegex.Matches($str2).Success){
		return $str2;
	}

	WriteErrorString "NIC custom config input: $str is not in an acceptable format for field $label."
	$str = Read-Host "Please provide a valid input."
	return ValidateCustomConfigAndPromptForCorrection $str $label
}

function ValidateWebURIOrHostPortAndPromptForCorrection {
	Param ($str, $label, $isSecure)

	if(ValidateHostPort $str)
	{
		return $str;
	}

	if (ValidateStringIsWebURI $str $isSecure)
	{
		return $str;
	}


	WriteErrorString "Provided input: $str is not in an acceptable format for field $label."
	$str = Read-Host "Please provide a valid input in URL / Host / IP address format. Port number can be provided if applicable"
	return ValidateWebURIOrHostPortAndPromptForCorrection $str $label $isSecure
}

function ValidateStringIsBooleanAndPromptForCorrection {
	Param ($str, $label, $allowEmpty)
	if(ValidateStringIsBoolean $str $allowEmpty)
	{
		return $str;
	}
	WriteErrorString "Provided input: $str is not in an acceptable format for field $label."
	$str = Read-Host "Please provide a valid input in boolean format (true/false)."
	return ValidateStringIsBooleanAndPromptForCorrection $str $label $allowEmpty
}

function ReadLoginBannerText {
	Param($settings)
	$sshBannerText=$settings.General.sshLoginBannerText
	$bannerTextRegex = [regex]"^[\x00-\x7F]{0,4096}$"
	if (!($bannerTextRegex.Matches($sshBannerText).Success)) {
		WriteErrorString "Invalid value for field [General]sshLoginBannerText. Only ASCII characters and maximum length of 4kb are supported"
		CleanExit
	}
	return stringToBase64($sshBannerText)
}

function stringToBase64 {
	Param ($str)
	if ($str.length -eq 0) {
		return $str
	}
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
	return [System.Convert]::ToBase64String($bytes)
}

function ReadOsLoginUsername {
	Param($settings)
	$sudoUsername=$settings.General.osLoginUsername
	$sudoUserRegex = [regex]"^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$"
	if ([string]::IsNullOrEmpty($sudoUsername) -or $sudoUserRegex.Matches($sudoUsername).Success) {
		return $sudoUsername;
	}
	WriteErrorString "Invalid value for the field [General]osLoginUsername. Only a-z, 0-9, underscrore (_) and hyphen(-) are allowed. Maximum length is 32."
	CleanExit
}

function ReadOsMaxLoginLimit {
	Param($settings)
	$osMaxLoginLimit=$settings.General.osMaxLoginLimit
	$osLoginLimitRegex = [regex]"^[0-9]+$"
	if ([string]::IsNullOrEmpty($osMaxLoginLimit) -or ($osLoginLimitRegex.Matches($osMaxLoginLimit).Success -and [int]$osMaxLoginLimit -gt 0)) {
		return $osMaxLoginLimit
	}
	WriteErrorString "Invalid value for the field [General]osMaxLoginLimit. Only positive integer values are supported."
	CleanExit
}

function ReadSecureRandomSource {
	Param($settings)
	$secureRandomSource=$settings.General.secureRandomSource
	if ((-not ([string]::IsNullOrEmpty($secureRandomSource))) -and ($secureRandomSource -ne '/dev/random') -and ($secureRandomSource -ne "/dev/urandom") -and ($secureRandomSource -ne "Default")) {
		WriteErrorString "Invalid value for field [General]secureRandomSource. Supported values are /dev/random,/dev/urandom and Default"
		CleanExit
	}
	return $secureRandomSource
}

function ValidateStringIsBoolean {
	Param ($str, $allowEmpty)
	if ($allowEmpty -eq $true -And $str.length -eq 0)
	{
		return $true
	}
	$booleanRegex = [regex]'^true|false$'
	return $booleanRegex.Matches($str).Success
}


function ValidateBlastReverseExternalUrl {
	Param ($str, $label)
	$split = $str.Split(",")
	$errorMsg = ""
	$blockedPortRegex = [regex]'^(8?443)$'
	for($i=0; $i -lt $split.length; $i++) {
		$url = $split[$i].Trim()
		# Host, port and https scheme patterns are validated here.
		if (-Not ((ValidateHostPort $url) -Or (ValidateStringIsWebURI $url $true))) {
			$errorMsg = "Provided input: $str contains an unacceptable entry: $url in the field $label"
			break
		}

		$curPort = "8444"
		if ($url.Split("]").length -eq 2) {
			# ipv6 case
			$curPort = $url.Split("]")[1].Split(":")[1]
		} elseif ($url.Split(":").length -eq 3) {
			# URL case
			$curPort = $url.Split(":")[2]
		} elseif ($url.Split(":").length -eq 2) {
			$curPort = $url.Split(":")[1]
		} elseif ($url.Split(":").length -gt 3) {
			# IPv6 without port
			$str = $str -replace $url,"[$url]:8444"
		}

		# Validate blocked ports here
		if ($blockedPortRegex.Matches($curPort).Success) {
			$errorMsg = "Provided input: $str contains an unacceptable port (443/8443) in the field $label."
			break
		}

		if ($global:blastReverseExternalUrlPort -eq "0") {
			$global:blastReverseExternalUrlPort = $curPort
		}

		if (-Not ($global:blastReverseExternalUrlPort -eq $curPort)) {
			$errorMsg = "Provided input: $str for $label contains a non-matching port in $url. Ensure to keep it unique in all occurrences of 'blastReverseExternalUrl'. https urls should explicitly mention the port."
			break
		}
	}

	if ($errorMsg.Length -gt 0) {
		WriteErrorString $errorMsg
		$str = Read-Host "Please provide a valid input"
		ValidateBlastReverseExternalUrl $str $label
	} else {
		return $str
	}
}

function ValidateBlastAllowedHostHeaderValuesAndPromptForCorrection {
	Param ($str)
	$split = $str.Split(",")
	$result = $true
	for($i=0; $i -lt $split.length; $i++) {
		$entry = $split[$i].Trim()
		if (($entry -eq "__empty__") -Or (ValidateHostPort $entry)) {
			Continue
		}
		$result = $false
		break
	}
	if ($result) {
		return $str
	} else {
		WriteErrorString "$str is not in an acceptable format for field 'Horizon > blastAllowedHostHeaderValues'."
		$str = Read-Host "Please provide a valid input"
		return ValidateBlastAllowedHostHeaderValuesAndPromptForCorrection $str
	}
}

function CleanExit {
	if ($ovfFile) {
		if (Test-path $ovfFile) {
			[IO.File]::Delete($ovfFile)
		}
		Remove-Variable "ovfFile" -Scope global
	}
	Exit
}

function ValidateMinSHAHashSize {
	Param($minSHAHashSize)
	if($minSHAHashSize -in "SHA-1", "SHA-256", "SHA-384", "SHA-512" )
	{
		return $minSHAHashSize;
	}
	WriteErrorString "Error: Invalid minSHAHashSize specified, Please provide a valid input for 'minSHAHashSize' (Allowed values : SHA-1/SHA-256/SHA-384/SHA-512)."
	CleanExit
}

function validateAndUpdateThumbprints {

	param($thumbprintString, $minSHASize, $config_name)

	$allowed_thumbprints = @{
		"SHA-1" = @("sha1", "sha256", "sha384", "sha512")
		"SHA-256" = @("sha256", "sha384", "sha512")
		"SHA-384" = @("sha384", "sha512")
		"SHA-512" = @("sha512")
	}

	$allowed_thumbprints_tag = @{
		"SHA-1" = @("SHA-1", "SHA-256", "SHA-384", "SHA-512")
		"SHA-256" = @("SHA-256", "SHA-384", "SHA-512")
		"SHA-384" = @("SHA-384", "SHA-512")
		"SHA-512" = @("SHA-512")
	}

	$thumbprints = $thumbprintString.split(",")
	$updated_thumbprints = [System.Collections.ArrayList]@()
	foreach ($thumbprint in $thumbprints) {
		$thumbprint = $thumbprint -replace ":", ""
		$thumbprint = $thumbprint -replace " ", ""
		$thumbprint = $thumbprint -replace "[^a-zA-Z0-9,= ]", ""
		$thumbprint_with_sha = getThumbprintWithSHASize $thumbprint $config_name
		$sha_size = $thumbprint_with_sha[0]

		# check the thumbprint received and if this is allowed SHA value.
		if (! ($allowed_thumbprints[$minSHASize].contains($sha_size))) {
			$shaOptions = $allowed_thumbprints_tag[$minSHASize]
			$minSHAHashSizeSection = "General"
			if ($config_name -eq "Horizon") {
				$minSHAHashSizeSection = "Horizon"
			}
			WriteErrorString "Invalid thumbprint size for [$config_name], minSHAHashSize is set to $minSHASize. Therefore Allowed SHA options are: $shaOptions. To allow usage of SHA-256 thumbprints, define minSHAHashSize=SHA-256 in ini [$minSHAHashSizeSection] section."
			CleanExit
		}

		$thumbprintValue = $thumbprint_with_sha -join "="
		$updated_thumbprints.add($thumbprintValue) | Out-Null
	}
	$updateThumbprintConcatenated = $updated_thumbprints -join ","
	return $updateThumbprintConcatenated
}

function getThumbprintWithSHASize {
	Param($thumbprint, $config_name)

	$thumbprintParts = $thumbprint.split("=")
	if ($thumbprintParts.length -eq 2) {
		$calculatedShaSize = calculateThumbprintSHAUsingLength $thumbprintParts[1]
		if ($calculatedShaSize -ne $thumbprintParts[0]) {
			WriteErrorString "Provided Thumbrint SHA and calculated thumbprint size mismatch for $config_name, thumbprint : $thumbprint, calculated SHA size = $calculatedShaSize"
			CleanExit
		}
		return $thumbprintParts;
	} elseif ($thumbprintParts.length -eq 1) {
		$Sha_size = calculateThumbprintSHAUsingLength $thumbprint
		if ($sha_size -eq "") {
			WriteErrorString "Invalid thumbprint value for $config_name : $thumbprint. Please provide a valid thumbprint for $config_name"
			CleanExit
		}
		return @($sha_size,$thumbprintParts[0])
	}
	return $thumbprintParts
}

function calculateThumbprintSHAUsingLength {
	param($thumbprint)
	$len = $thumbprint.length
	$size_dict = @{40 = "sha1"; 64 = "sha256"; 96 = "sha384"; 128 = "sha512"}
	if ($size_dict.contains($len))
	{
		return $size_dict.$len
	} else {
		return ""
	}
}

function ValidateRedirectHostPortMappingListAndPromptForCorrection {
	Param ($str, $label)
	$mappingList = $str.Split(",")
	$result = $true
	for($i=0; $i -lt $mappingList.length; $i++) {
		$mapping = $mappingList[$i].Trim()
		$hostport = $mapping.Split("_")
		if (($hostport.Length -eq 2) -And (ValidateHostPort $hostport[0]) -And (ValidateHostPort $hostport[1])) {
			Continue
		}
		$result = $false
		break
	}
	if ($result) {
		return $str
	} else {
		WriteErrorString "$str is not in an acceptable format for field '$label'."
		$str = Read-Host "Please provide a valid input"
		return ValidateRedirectHostPortMappingListAndPromptForCorrection $str
	}
}

function ValidateCustomBootTimeCommands {
	Param ($settings, $commandKey)

	$commands = $settings.General.$commandKey
	# Run validation here
	if ($commands.length -gt 8192) {
		WriteErrorString "Invalid value for '[General]$commandKey'. Length of commands cannot exceed 8192 characters"
		CleanExit
	}
	return stringToBase64($commands)
}

function validateSSHInterface {
	Param($settings)

	$availableInterface = @("eth0", "eth1", "eth2")
	$sshInterface = $settings.General.sshInterface

	if (($sshInterface.length -gt 0)) {
		if ($availableInterface.Contains($sshInterface)) {
			return $sshInterface
		}
		else {
			WriteErrorString "Invalid ssh interface : $availableInterface"
			CleanExit
		}
	}
}

function getGatewaySpec {
	Param($settings)
	$availableGatewaySpec = @("Horizon_Gateway", "HCS_NextGen_Gateway")
	$gatewaySpec = $settings.General.gatewaySpec
	if (($gatewaySpec.length -gt 0)) {
		if (($availableGatewaySpec.Contains($gatewaySpec))) {
			return $gatewaySpec
		} else {
			WriteErrorString "Error: gateway spec : $gatewaySpec provided in [General] section is invalid. Allowed values : $availableGatewaySpec"
			CleanExit
		}
	}
}


function updatePasswordPolicyForDsComplianceOS {
	Param($settings)

	if (($settings.General.passwordPolicyMinLen.length -eq 0) -or ([int]$settings.General.passwordPolicyMinLen -ne 15)) {
		WriteErrorString "The field [General]passwordPolicyMinLen needs to be set to 15 when the flag [General]dsComplianceOS is set to true"
		Exit
	}

	if (($settings.General.passwordPolicyMinClass.length -eq 0) -or ([int]$settings.General.passwordPolicyMinClass -ne 4)) {
		WriteErrorString "The field [General]passwordPolicyMinClass needs to be set to 4 when the flag [General]dsComplianceOS is set to true"
		Exit
	}
}

function SanitizeThumbprints {
	Param($thumbprints, [Parameter(Mandatory=$false)] $allowWildCard=$false)

	$sanitizedThumbprints = $thumbprints -replace "=", ":"
	if ($allowWildCard) {
		$sanitizedThumbprints = $sanitizedThumbprints -replace "[^a-zA-Z0-9,:* ]", ""
	} else {
		$sanitizedThumbprints = $sanitizedThumbprints -replace "[^a-zA-Z0-9,: ]", ""
	}
	$sanitizedThumbprints = $sanitizedThumbprints -replace "(sha1:)", "sha1=" -replace "(sha256:)", "sha256=" -replace "(sha384:)", "sha384=" -replace "(sha512:)", "sha512="

	return $sanitizedThumbprints
}
