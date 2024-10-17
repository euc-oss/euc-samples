 #Created by Dima Garf, Omnissa
#Last Edit: 07/06/2022
#Reboots Horizon desktops that have active session
#Example: .\HorizonReboot.ps1 -HZNServer "HorizonCS-FQDN" -HZUser "Administrator" -HZNPassword "Password" -HZDomain "Domain.local"



[CmdletBinding()]
Param
  (
        [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][String]$HZNServer,
        [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][String]$HZUser,
        [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][String]$HZPassword,
        [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][String]$HZDomain
        
    )



Function HZN-Reboot {




    try {
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | out-null
        $HVServer = Connect-HVServer -Server $HZNServer -User $HZUser -Password $HZPassword -Domain $HZDomain
        $HVMachines = Get-HVMachineSummary
        $FHVMachines = $HVMachines | Select @{N='Desktop';E={$_.Base.Name}},@{N='Status';E={$_.Base.BasicState}} | Where-Object {$_.Status -eq "Connected"} | Select -ExpandProperty Desktop

        
        foreach ($Desktop in $FHVMachines)
            {

            Write-Host Rebooting $Desktop
            Reset-HVMachine $Desktop -Confirm:$false
            }

        }

    catch {
        $ErrorMessage = $_.Exception.Message
	    $FailedItem = $_.Exception.ItemName
		Write-Host $ErrorMessage
        }


    if ($ErrorMessage -ne $null) {
		Write-Host "Failed" -BackgroundColor Red
   	 	$date = get-date
    	Add-Content C:\ProgramData\VMware\HorizonRestart.log "`n$date : $ErrorMessage"
		}
		
		
	else {
		Write-Host "Success" -BackgroundColor Green
		$date = get-date
		Add-Content C:\ProgramData\VMware\HorizonRestart.log "`n$date : Success: $FHVMachines" 
		
		
		}

}



HZN-Reboot





 
