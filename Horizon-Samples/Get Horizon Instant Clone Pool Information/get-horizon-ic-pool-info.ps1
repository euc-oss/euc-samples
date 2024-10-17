<#
.NOTES
    Author: Mark McGill, Omnissa
    Last Edit: 11/4/2020
    Version 1.0
.SYNOPSIS
    Gets information on Instant Clone Pool VMs
.DESCRIPTION
    Returns information on Horizon Instant Clone pool VMs, including space consumed, and hierarchy of Parent, Replica, Template, Snapshot, and Master
    Identifies VMs that are potentially orphaned/abandoned by Horizon
<<<<<<< Updated upstream
    REQUIREMENTS: PowerCLI, Omnissa.Horizon.Helper ,and Powershell 5.
=======
    REQUIREMENTS: PowerCLI, VMware.Hv.Helper ,and Powershell 5. VMware.Hv.Helper module is not yet supported in Powershell Core
    For instructions on installing VMware.Hv.Helper, see https://blogs.omnissa.com/euc/2020/01/vmware-horizon-7-powercli.html
>>>>>>> Stashed changes
.PARAMETER connnectionServer
    Required: Yes
    You must specify a Horizon Connection Server to connect to
.PARAMETER credential
    Required: No
    You can provide a credential object for connection to the Connection Server and vCenter Server.  If you are not already connected to them, you will be prompted for credentials
    Provided credentials should have access to both Horizon Connection Server and vCenter Server
.EXAMPLE
    #load function in order to call function
    . .\Get-ICPoolInfo.ps1
 .EXAMPLE
    #Gets all Instant Clone pools in the pod.  If not currently connected to the Connection Server and vCenter Server, you will be prompted for credentials 
    Get-ICPoolInfo -connectionServer "horizon-01.corp.local"
.EXAMPLE
    #Create credential object that can be used for Horizon and vCenter authentication
    $credentials = Get-Credential
    Get-ICPoolInfo -connectionServer "horizon-01.corp.local" -credential $credentials
.EXAMPLE
    #Write the returned array of objects to a CSV file
    Get-ICPoolInfo -connectionServer "horizon-01.corp.local" | Export-Csv "c:\temp\icInfo.csv" -NoTypeInformation
.OUTPUTS
    Array of VM objects containing data on their associated IC VMs and a status
#>

Function Get-ICPoolInfo {
#Requires -Version 5.0
#Requires -Modules Omnissa.Horizon.Helper,Omnissa.VimAutomation.HorizonView
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True)]$connectionServer,
        [Parameter(Mandatory=$False)][String]$poolName,
        [Parameter(Mandatory=$False)]$credentials
    )

    Function Get-Desktop-Info($poolDesktops,$allDesktops,$resourceType,$resourceName)
    {
        $arrVMs = @()
        #take 1 desktop from the IC resource to get the master and template
        $desktop = $allDesktops | Where {$_.Name -eq ($poolDesktops[0]).Name}
        $icRoleVMs = Get-IC_Role_VMs $desktop
        
        $masterVM = Get-View -ViewType VirtualMachine -Filter @{"Name"=$($icRoleVMs.Master)} -Property Name,Config.ExtraConfig,Config.UUID,Runtime.Host,Datastore,Storage.PerDatastoreUsage | Select @{n="VMName";e={$_.Name}},@{n="VMType";e={"master"}},@{n="ResourceType";
            e={$resourceType}},@{n="ResourceName";e={$resourceName}},@{n="VMHost";e={Get-View -Id "$($_.Runtime.Host.Type)-$($_.Runtime.Host.Value)" -Property Name | Select -expand Name}},@{n="Datastores";
            e={$dsList = "";foreach($ds in $_.Datastore){$dsName = Get-View -Id "$($ds.Type)-$($ds.Value)" -Property Name | Select -expand Name; $dsList = $dsList + "$dsName;"}$dsList.Trim(";")}},@{n="UsedSpaceGB";
            e={Get-UsedSpace $_}},@{n="PodId";e={$icRoleVms.PodId}},Master,@{n="Snapshot";e={$icRoleVMs.Snapshot}},Template,Replica,Parent,Status
        $arrVMs += $masterVM
        
        $templateVM = $allDesktops | Where {$_.Name -eq $icRoleVMs.Template} | Select @{n="VMName";e={$_.Name}},@{n="VMType";e={"template"}},@{n="ResourceType";
            e={$resourceType}},@{n="ResourceName";e={$resourceName}},@{n="VMHost";e={Get-View -Id "$($_.Runtime.Host.Type)-$($_.Runtime.Host.Value)" -Property Name | Select -expand Name}},@{n="Datastores";
            e={$dsList = "";foreach($ds in $_.Datastore){$dsName = Get-View -Id "$($ds.Type)-$($ds.Value)" -Property Name | Select -expand Name; $dsList = $dsList + "$dsName;"}$dsList.Trim(";")}},@{n="UsedSpaceGB";
            e={Get-UsedSpace $_}},@{n="PodId";e={$icRoleVms.PodId}},@{n="Master";e={$icRoleVMs.Master}},@{n="Snapshot";e={$icRoleVMs.Snapshot}},Template,Replica,Parent,Status
        $arrVMs += $templateVM

        #get all VMs that match the master and template IDs for the IC resourceStatus
        $viewVMs = $allDesktops | Where{(($_.Config.ExtraConfig | Where{$_.Key -eq "cloneprep.master.metadata"} | `
            Select -expand Value) -match $icRoleVMs.MasterId -and ($_.Config.ExtraConfig | Where{$_.Key -eq "cloneprep.internal.template.uuid"} | Select -expand Value) -eq $($icRoleVMs.TemplateId))} | Select Config,Runtime,@{n="VMName";
            e={$_.Name}},@{n="VMType";e={If($poolDesktops.Name -contains $_.Name){"VDI Desktop"}
                else {($_.Name).Split("-")[1]}}},@{n="ResourceType";e={$resourceType}},@{n="ResourceName";e={$resourceName}},@{n="VMHost";
            e={Get-View -Id "$($_.Runtime.Host.Type)-$($_.Runtime.Host.Value)" -Property Name | Select -expand Name}},@{n="Datastores"; 
            e={$dsList = "";foreach($ds in $_.Datastore){$dsName = Get-View -Id "$($ds.Type)-$($ds.Value)" -Property Name | Select -expand Name; $dsList = $dsList + "$dsName;"}$dsList.Trim(";")}},@{n="UsedSpaceGB";
            e={Get-UsedSpace $_}},PodId,Master,Snapshot,Template,Replica,Parent | foreach{$icVMs = Get-IC_Role_VMs $_;
                $obj = $_
                $obj.PodId = $icVMs.PodId
                $obj.Master = $icVMs.Master
                $obj.Snapshot = $icVMs.Snapshot
                $obj.Template = $icVMs.Template
                $obj.Replica = $icVMs.Replica
                $obj.Parent = $icVMs.Parent
                $obj
                } | Select VMName,VMType,ResourceType,ResourceName,VMHost,Datastores,UsedSpaceGB,PodId,Master,Snapshot,Template,Replica,Parent,Status

        $arrVMs += $viewVMs
        #check for potentially orphaned VMs
        foreach ($objVM in $arrVMs)
        {
            If($poolDesktops.Name -contains $objVM.VMName)
            {
                $objVM.Status = ($poolDesktops | Where {$_.Name -eq $objVM.VMName} | Select -expand Status) + ";"
            }

            If($objVM.Snapshot -ne $icRoleVMs.Snapshot)
            {
                $objVM.Status = $objVM.Status + "Potentially abandoned. Snapshot does not match pool: $($objVM.Snapshot);"
            }

            If($objVM.Status -ne $null)
            {
                $objVM.Status = ($objVM.Status).Trim(";")
            }
            Else
            {
                $objVM.Status = "Normal"
            }
        }

        Return $arrVMs
    }

    Function Get-IC_Role_VMs($vms)
    {
        $arrVMRoles = @()
        foreach ($vm in $vms)
        {
            $vmRoles = "" | Select Master,MasterId,Snapshot,SnapshotId,Template,TemplateId,Replica,ReplicaId,Parent,PodId

            $masterInfo = ($vm.Config.ExtraConfig | where {$_.Key -eq "cloneprep.master.metadata"} | select -expand Value)
            If ($masterInfo -ne $null)
            {
                $vmRoles.MasterId = $masterInfo.Split("%")[9].Replace("3D","")
                $vmRoles.SnapshotId = $masterInfo.Split("%")[11].Replace("3D","")
                $vmRoles.Master = Get-View -ViewType VirtualMachine -Filter @{"Config.InstanceUuid"=$($vmRoles.MasterId)} -Property Name | Select -expand Name
                $vmRoles.Snapshot = Get-Snapshot -VM $($vmRoles.Master) | Where {$_.ExtensionData.Id -eq $($vmRoles.SnapshotId)} | Select -expand Name
                If ($vmRoles.Snapshot -eq $null)
                {
                    $vmRoles.Snapshot = "CAN'T FIND SNAPSHOT ID: $($vmRoles.SnapshotId)"
                }
            }

            $vmRoles.TemplateId = $vm.Config.ExtraConfig | where {$_.Key -eq "cloneprep.internal.template.uuid"} | select -expand Value
            If ($vmRoles.TemplateId -ne $null)
            {
                $vmRoles.Template = Get-View -ViewType VirtualMachine -Filter @{"Name"="cp-template";"Config.InstanceUuid"=$($vmRoles.TemplateId)} -Property Name | Select -expand Name
            }
            Else
            {
                $vmRoles.Template = $null
            }

            $vmRoles.ReplicaId = $vm.Config.ExtraConfig | where {$_.Key -eq "cloneprep.replica.uuid"} | select -expand Value
                If ($vmRoles.ReplicaId -ne $null)
            {
                $vmRoles.Replica = Get-View -ViewType VirtualMachine -Filter @{"name"="cp-replica";"Config.InstanceUUID"=$($vmRoles.ReplicaId)} -Property Name | Select -expand Name
                If($vm.VMName -notmatch "parent")
                {
                $vmRoles.Parent = Get-View -ViewType VirtualMachine -Filter @{"name"="cp-parent"} -Property Name,Runtime,Config.ExtraConfig | Where {(($_.Config.ExtraConfig | Where{
                    $_.Key -eq "cloneprep.replica.uuid"} | Select -expand Value) -eq $($vmRoles.ReplicaId)) -and ($vm.VMHost -eq (Get-View -Id "$($_.Runtime.Host.Type)-$($_.Runtime.Host.Value)" -Property Name | Select -expand Name))} | Select -expand Name
                }
                Else
                {
                    $vmRoles.Parent = $null
                }
            }
            Else
            {
                $vmRoles.Replica = $null
            }

            $vmRoles.PodId = $vm.Config.ExtraConfig | where {$_.Key -eq "cloneprep.client.uuid"} | select -expand Value
            $arrVMRoles += $vmRoles
        }

        Return $arrVMRoles
    }

    Function Get-UsedSpace ($view)
    {
        $perDatastoreUsage = $view.Storage.PerDatastoreUsage

        $totalCommitted = 0
        $totalUncommitted = 0
        foreach ($dataStore in $perDatastoreUsage)
        {
            $committed = $([math]::Round(($dataStore.Committed / 1073741824),2))
            $totalCommitted = $committed + $totalCommitted
        }
        Return $totalCommitted
    }

    #connects to Horizon Connection Server and associated vCenter if they aren't already connected
    If ($global:DefaultHVServers.Name -notcontains $connectionServer -or ($global:DefaultHVServers | Where{$_.Name -eq $connectionServer}).IsConnected -eq $false)
    {
        Try 
        {
            If ($credentials -eq $null)
            {
            $credentials = Get-Credential -Message "Enter credentials to connect to Horizon"
            }
            $hvServer = Connect-HVServer $connectionServer -Credential $credentials
        }
        Catch 
        {
            Clear-Variable credentials
            Throw "Error connecting to $connectionServer : $_.Exception.Message"
        }
    }
    Else
    {
        $hvServer = $global:DefaultHVServers | Where{$_.Name -eq $connectionServer} 
    }

    $services = $hvServer.ExtensionData

    $vCenter = (Get-HVvCenterServer).ServerSpec.ServerName

    If ($global:DefaultVIServer.Name -ne $vCenter -or $global:DefaultVIServer.IsConnected -eq $false)
    {
        Try
        {
            If ($credentials -eq $null)
            {
                Connect-VIServer $vCenter
            }
            else 
            {
                Connect-VIServer $vCenter -Credential $credentials
            }
        }
        Catch
        {
            Clear-Variable credentials
            Throw "Error connecting to $vCenter : $_.Exception.Message"
        }
    }

    $hvPools = Get-HVPool -HvServer $hvServer | Where {$_.Source -eq "INSTANT_CLONE_ENGINE" -and $_.Type -eq "AUTOMATED"}
    $hvFarms = Get-HVFarm -HvServer $hvServer | Where {$_.Source -eq "INSTANT_CLONE_ENGINE" -and $_.Type -eq "AUTOMATED"}
    $allViewVMs = Get-View -Server $vCenter -ViewType VirtualMachine -Property Name,Config.ExtraConfig,Config.UUID,Runtime.Host,Datastore,Storage.PerDatastoreUsage | Where{$_.Config.ExtraConfig | `
        Where{$_.Key -eq "cloneprep.master.metadata"}}

    $allPools = @()
    $arrResults = @()
    If ($hvPools.Count -ne 0)
    {
        $poolNames = $hvPools.base.name
        $allPools = $allPools += $poolNames
        foreach ($hvPool in $hvPools)
        {
            $hvPoolName = $hvPool.base.name
            Write-Host "Getting information on Pool: $hvPoolName" -foregroundcolor Green
            #removed connected and available as filters for VDI desktops
            $hvPoolDesktops = Get-HVMachine -PoolName $hvPoolName | Select @{n='Name';e={$_.Base.Name}},@{n="Status";e={$_.Base.BasicState}}
            $type = "Pool"
            $arrResults += (Get-Desktop-Info $hvPoolDesktops $allViewVMs $type $hvPoolName)
        }
    }
    else 
    {
        Write-Host "Get-HVPool: No Pool found with the given search parameters"
    }

    If ($hvfarms.Count -ne 0)
    {
        $farmNames = $hvFarms.data.Name
        $allPools = $allPools += $farmNames
        foreach ($hvFarm in $hvFarms)
        {
            $hvFarmName = $hvFarm.data.name
            Write-Host "Getting information on Farm: $hvFarmName" -foregroundcolor Green
            $farmhealth = New-Object Omnissa.Horizon.FarmHealthService
            $hvRdshDesktops = $farmhealth.FarmHealth_Get($services,$hvFarm.Id) | Select -expand RdsServerHealth | Select Name,Status
            $type = "Farm"
            $arrResults += (Get-Desktop-Info $hvRdshDesktops $allViewVMs $type $hvFarmName)
        }
    }

    If ($allPools.Count -eq 0)
    {
        Write-Warning "No Horizon Pools were found."
        break
    }

    $notMatchVMs = $allViewVMs | Where {$_.Name -eq (Compare-object -ReferenceObject $_.Name -DifferenceObject $arrResults.VMName | Where{$_.SideIndicator -eq "<="} | Select -expand InputObject)} | Select Config,Runtime,@{n="VMName";
            e={$_.Name}},@{n="VMType";e={($_.Name).Split("-")[1]}},@{n="ResourceType";e={"UNKNOWN"}},@{n="ResourceName";e={"UNKNOWN"}},@{n="VMHost";
            e={Get-View -Id "$($_.Runtime.Host.Type)-$($_.Runtime.Host.Value)" -Property Name | Select -expand Name}},@{n="Datastores"; 
            e={$dsList = "";foreach($ds in $_.Datastore){$dsName = Get-View -Id "$($ds.Type)-$($ds.Value)" -Property Name | Select -expand Name; $dsList = $dsList + "$dsName;"}$dsList.Trim(";")}},@{n="UsedSpaceGB";
            e={Get-UsedSpace $_}},PodId,Master,Snapshot,Template,Replica,Parent | foreach{$icVMs = Get-IC_Role_VMs $_;
                $obj = $_
                $obj.PodId = $icVMs.PodId
                $obj.Master = $icVMs.Master
                $obj.Snapshot = $icVMs.Snapshot
                $obj.Template = $icVMs.Template
                $obj.Replica = $icVMs.Replica
                $obj.Parent = $icVMs.Parent
                $obj
                } | Select VMName,VMType,ResourceType,ResourceName,VMHost,Datastores,UsedSpaceGB,PodId,Master,Snapshot,Template,Replica,Parent,@{n="Status";e={"Potentially Abandoned: IC information does not match any pools"}}

    $arrResults += $notMatchVMs

    Return $arrResults

}#end function