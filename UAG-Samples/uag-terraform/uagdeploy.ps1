
# Read stdin as string
$jsonpayload = [Console]::In.ReadLine()

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

# Convert to JSON
$json = ConvertFrom-Json $jsonpayload
$inifile=$json.inifile
$settings = ImportIni $inifile
$numIterationsRest=$settings.SecurIDAuth.numIterationsRest
$hostname=$json.hostname
$serverHostnameRest=$json.serverHostnameRest
$accessKeyRest=$json.accessKeyRest



function GetAuthMethodSettingsSecurID {
    Param ($numIterationsRest, $hostname, $serverHostnameRest, $accessKeyRest)

	#New Authbroker settings v21.11

        $authMethodSettingsSecurID += "{ \'name\': \'securid-auth\'"
        $authMethodSettingsSecurID += ","
       	$authMethodSettingsSecurID += "\'enabled\': true"

        $authMethodSettingsSecurID += ","
        if ($numIterationsRest.length -gt 0 )  {
            $authMethodSettingsSecurID += "\'numIterationsRest\':  \'"+$numIterationsRest+"\'"
        } else {
            $authMethodSettingsSecurID += "\'numIterationsRest\': \'5\'"
        }

        $authMethodSettingsSecurID += ","
        if ($hostname.length -gt 0) {
            $authMethodSettingsSecurID += "\'hostname\':  \'"+$hostname+"\'"
        }

        $authMethodSettingsSecurID += ","
        if ($serverHostnameRest.length -gt 0) {
            $authMethodSettingsSecurID += "\'serverHostnameRest\':  \'"+$serverHostnameRest+"\'"
        }

        $authMethodSettingsSecurID += ","
        $authMethodSettingsSecurID += "\'serverPortRest\': \'5555\'"

        $authMethodSettingsSecurID += ","
        if ($accessKeyRest.length -gt 0) {
            $authMethodSettingsSecurID += "\'accessKeyRest\':  \'"+$accessKeyRest+"\'"
        }

        $authMethodSettingsSecurID += "}"
    $authMethodSettingsSecurID
}
$securID = GetAuthMethodSettingsSecurID $numIterationsRest $hostname $serverHostnameRest $accessKeyRest
@{
    securID     = $securID;
} | ConvertTo-Json

