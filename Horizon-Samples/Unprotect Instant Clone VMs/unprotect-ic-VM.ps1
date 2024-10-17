<#
.NOTES
Author: Mark McGill, VMware
Last Edit: 11-23-2020
Version 1.1
.SYNOPSIS
Unprotect Instant Clone VMs in order to delete those that are abandoned by Horizon
.DESCRIPTION
Uses vCenter API to enable methods needed to unprotect Instant Clone VMs
Enabled methods match those enabled by the Horizon icCleanup tool to unprotect Instant Clones
.EXAMPLE
#load function in order to call
. .\Unprotect-InstantClone.ps1
.EXAMPLE
#Required parameters are vm and vCenter
Unprotect-InstantClone -vm <vmName> -vCenter <vcenterFQDN>
.EXAMPLE
#Accepts pipeline input in the form of an array of VM Names, or VM Objects from Get-VM
$vms = Get-VM ic-Template*
$vms | Unprotect-InstantClone -vCenter <vcenterFQDN> -user administrator@vsphere.local
.EXAMPLE
#Username and password can be passed as parameters as well as a Credential object.  You will be prompted if none are provided
$credentials = Get-Credential
Unprotect-InstantClone -vm <vmName> -vCenter vCenter.corp.local -Credentials $credentials
.EXAMPLE
#You will be prompted to confirm unprotecting VMs unless you pass the '-Confirm $false' parameter
Unprotect-InstantClone -vm <vmName> -vCenter <vcenterFQDN> -user administrator@vsphere.local -Confirm $false
.EXAMPLE
#Use the '-Verbose' option to show additional output during processing
Unprotect-InstantClone -VM <vmName> -vCenter <vcenterFQDN>  -Verbose
#>

Function Unprotect-InstantClone {
#Requires -Version 5.0
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True,ValueFromPipeline=$true)]$vm,
        [Parameter(Mandatory=$True)][String]$vCenter,
        [Parameter(Mandatory=$False)][String]$user,
        [Parameter(Mandatory=$False)][String]$password,
        [Parameter(Mandatory=$False)]$credentials,
        [Parameter(Mandatory=$False)][ValidateSet($true,$false)][bool]$Confirm = $false
    )

    Begin
    {
        #Variables
        #methods that are re-enabled using the Horizon iccleanup tool to unprotect a VM
        $parentMethods = "CreateSnapshot_Task","MigrateVM_Task","PowerOffVM_Task","PromoteDisks_Task","ReconfigVM_Task","Reload","reloadVirtualMachineFromPath_Task","RelocateVM_Task","RemoveAllSnapshots_Task","Rename_Task","ResetVM_Task","RevertToCurrentSnapshot_Task","SuspendVM_Task","TerminateVM"
        $replica_templateMethods = "CreateSnapshot_Task","CustomizeVM_Task","Destroy_Task","MarkAsTemplate","PowerOnVM_Task","ReconfigVM_Task","Reload","reloadVirtualMachineFromPath_Task","RelocateVM_Task","RemoveAllSnapshots_Task","Rename_Task","RevertToCurrentSnapshot_Task","UnregisterVM"
        #encodes methods to use in the API call
        $pMethodsEnc = @()
        foreach ($method in $parentMethods)
        {
            $pMethodsEnc += "%3Cmethod%3E$method%3C%2Fmethod%3E"
        }
        $rtMethodsEnc = @()
        foreach ($method in $replica_templateMethods)
        {
            $rtMethodsEnc += "%3Cmethod%3E$method%3C%2Fmethod%3E"
        }

        # vSphere MOB URL to private enableMethods
        $mobUrl = "https://$vCenter/mob/?moid=AuthorizationManager&method=enableMethods"
        $mobLogoutUrl = "https://$vCenter/mob/logout"
        $continue = $true

        Try
        {
            #validates and builds credentials
            If ($credentials -eq $null -and $user -eq "")
            {
                $credentials = Get-Credential -Message "Enter username and password with rights to query vCenter API" -ErrorAction Stop
            }
            ElseIf ($user -ne "" -and $password -eq "")
            {
                $credentials = Get-Credential -UserName $user -Message "Enter the password for $user" -ErrorAction Stop
            }
            ElseIf ($user -ne "" -and $password -ne "")
            {
                [securestring]$securePassword = ConvertTo-SecureString $password -AsPlainText -Force -ErrorAction Stop
                [pscredential]$credentials = New-Object System.Management.Automation.PSCredential ($User, $securePassword) -ErrorAction Stop
            }
            ElseIf ($credentials -ne $null)
            {
                Write-Verbose "Using provided credential object"
            }
        }
        Catch
        {
            Throw "Error building credentials: $($_.Exception.Message)"
        }

        #Thanks to William Lam for API call syntax from his "Enable-vSphereMethod" function:
            #(https://github.com/lamw/vghetto-scripts/blob/master/powershell/enable-disable-vsphere-api-method.ps1)
        #Initial login to vSphere MOB using GET and store session using $vmware variable
        If ($PSVersionTable.PSVersion.Major -eq 5)
        {
            Try
            {
                Write-Verbose "Connecting to vCenter API using Powershell 5"
                $results = Invoke-WebRequest -Uri $mobUrl -SessionVariable vmware -Credential $credential -Method GET -ErrorAction Stop
            }
            Catch
            {
                #Allow untrusted certificates for the session, as -SkipCertificateCheck isn't available for Invoke-WebRequest
                Try
                {
                    Write-Verbose "Allowing insecure connections for the session"
                    If ($_.Exception.Message -match "The underlying connection was closed: An unexpected error occurred on a send")
                    {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    }
                    ElseIf ($_.Exception.Message -match "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel")
                    {
                        add-type @"
                        using System.Net;
                        using System.Security.Cryptography.X509Certificates;
                        public class TrustAllCertsPolicy : ICertificatePolicy {
                            public bool CheckValidationResult(
                                ServicePoint srvPoint, X509Certificate certificate,
                                WebRequest request, int certificateProblem) {
                                return true;
                            }
                        }
"@ 
                        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                    }
                    Write-Verbose "Connecting to vCenter API allowing untrusted certificates"
                    $results = Invoke-WebRequest -Uri $mobUrl -SessionVariable vmware -Credential $credentials -Method GET -ErrorAction Stop
                }#end try
                Catch
                {
                    Throw "Unable to connect to API with untrusted certificates: $($_.Exception.Message)"
                }
            }#end catch
        }#end if
        Elseif ($PSVersionTable.PSVersion.Major -ge 6)
        {
            Write-Verbose "Connecting to vCenter API using Powershell $($PSVersionTable.PSVersion.Major)"
            Try
            {
                $results = Invoke-WebRequest -Uri $mobUrl -SessionVariable vmware -Credential $credentials -Method GET -SkipCertificateCheck -ErrorAction Stop
            }
            Catch
            {
                Throw "Error connecting to vCenter API: $_.Exception.Message"
            }
        }#end elseif
            
        # Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
        # Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
        If ($results.StatusCode -eq 200) 
        {
            $null = $results -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
            $sessionnonce = $matches[1]
            Write-Verbose "Session nonce: $sessionnonce"
        } 
        Else
        {
            Throw "Failed to login to vSphere MOB on $vCenter"
        }

        #load function for use in posting enable methods from process block
        Function Enable-Method($icName,$icMoRef,$nonce)
        {
            If ($icName -match "cp-parent-")
            {
                $methods = $pMethodsEnc
            }
            ElseIf ($icName -match "cp-template-" -or $icName -match "cp-replica-")
            {
                $methods = $rtMethodsEnc
            }
            Else
            {
                Throw "Virtual Machine is not an instant clone!"
            }
            
            Write-Verbose "Unprotecting $icName"
            Try
            {
                #the POST data payload must include the vmware-session-nonce variable + URL-encoded
                $encodedBody = @"
vmware-session-nonce=$nonce&entity=%3Centity+type%3D%22ManagedEntity%22+xsi%3Atype%3D%22ManagedObjectReference%22%3E$icMoRef%3C%2Fentity%3E%0D%0A&method=$methods
"@
                # Second request using a POST and specifying our session from initial login + body request
                Write-Verbose "Enabling Methods on $icName"
                If ($PSVersionTable.PSVersion.Major -eq 5)
                {
                    $postResults = Invoke-WebRequest -Uri $mobUrl -WebSession $vmware -Method POST -Body $encodedBody -ErrorAction Stop
                }
                Elseif ($PSVersionTable.PSVersion.Major -ge 6)
                {
                    $postResults = Invoke-WebRequest -Uri $mobUrl -WebSession $vmware -Method POST -Body $encodedBody -SkipCertificateCheck -ErrorAction Stop
                }

            }#end try
            Catch
            {
                Throw "Error calling MOB API on $vCenter : $($_.Exception.Message)"
            }
            If ($postResults.StatusCode -ne 200)
            {
                Write-Warning "Error enabling methods for $icName"
            }
            Write-Debug "Post results: $postResults"
            Write-Output "Unprotected $icName"
        }#end function Enable-Method
    }#end begin

    Process
    {
        foreach ($vmObj in $vm)
        {
            #gets VM MoRef value
            If ($vmObj.MoRef.Value -eq $null)
            {
                If (($global:DefaultVIServer).Name -ne $vCenter -or $global:DefaultVIServer.IsConnected -ne $true)
                {
                    Write-Verbose "Not currently connected to $vCenter.  Attempting to connect"
                    Try
                    {
                        Connect-VIServer $vCenter -Credential $credentials -ErrorAction Stop
                    }
                    Catch
                    {
                        Throw "Error connecting to $vCenter : $($_.Exception.Message)"
                    }
                }#end if
                
                $vmObj = Get-View -ViewType VirtualMachine -Filter @{"Name"="^$($vm)$"} -Property Name -Server $vCenter
                $vmName = $vmObj.Name
                $vmMoRef = $vmObj.MoRef.Value
            }#end if
            Else
            {
                $vmName = $vmObj.Name
                $vmMoRef = $vmObj.ExtensionData.MoRef
            }

            If ($Confirm)
            {
                Enable-Method $vmName $vmMoRef $sessionnonce
            }
            Else
            {
                Write-Host "WARNING: Performing Unprotect on $vmName. Please Confirm" -ForegroundColor Yellow
                Write-Host "    [Y]Yes [A]Yes to All [N]No [C]Cancel:" -NoNewline -ForegroundColor Yellow
                $choice = Read-Host
                Switch ($choice)
                {
                    "Y" {Enable-Method $vmName $vmMoRef $sessionnonce; $Confirm = $False}
                    "A" {Enable-Method $vmName $vmMoRef $sessionnonce; $Confirm = $True}
                    "N" {Write-Output "Skipping $icName";$Confirm = $False; break}
                    "C" {Write-Warning "Cancelling Unprotect!"; Throw "Cancelled"}
                    Default {Write-Warning "Not a valid option. Exiting"; Throw "Cancelled"}
                }
            }#end if
        }#end vmLoop foreach
    }#end process

    End
    {
        #logout of API
        Write-Verbose "Logging out of vCenter API"
        If ($PSVersionTable.PSVersion.Major -eq 5)
        {
            $logOut = Invoke-WebRequest -Uri $mobLogoutUrl -WebSession $vmware -Method GET -ErrorAction Stop
        }
        Elseif ($PSVersionTable.PSVersion.Major -ge 6)
        {
            $logOut = Invoke-WebRequest -Uri $mobLogoutUrl -WebSession $vmware -Method GET -SkipCertificateCheck -ErrorAction Stop
        }
        Clear-Variable Credentials
    }

}#end function