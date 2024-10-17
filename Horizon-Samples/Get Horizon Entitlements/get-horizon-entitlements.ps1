#This script connects to a Horizon Connection Server and returns all desktop and app pool entitlement groups & users in the Pod
#You will be prompted for credentials to connect to the Connection Server - user should be at least a Horizon Read-Only Admin
#Requirements:
    #Powershell v5.x (HV.Helper module is not supported in Powershell Core yet)
    #PowerCLI 6.5 or higher
    #HV.Helper module - follow instructions to install at https://blogs./euc/2020/01/vmware-horizon-7-powercli.html
#Change the below Connection Server FQDN and output path for the results

#CHANGE ME!
$connServer = "connectionServer.corp.local"
$logPath = "c:\temp\Horizon_Entitlements.csv"
#CHANGE ME!

Connect-HVServer $connServer

$pools = Get-HVPool
$apps = Get-HVApplication

$entitlements = @()
If ($pools -ne $null)
{
    foreach ($pool in $pools)
    {
        
        $poolEntitlements = get-hvqueryResult -EntityType EntitledUserOrGroupLocalSummaryView | Where {$_.LocalData.Desktops.Id -contains $pool.Id.Id}
        If ($poolEntitlements -ne $null)
        {
            $list = ""
            foreach ($entitlement in $poolEntitlements)
            {
                $list = $list + ";" + $($entitlement.Base.DisplayName)
            }
            $list = $list.Trim(";")
            $poolInfo = "" | Select @{n="ResourceName";e={$pool.Base.Name}},@{n="ResourceType";e={"Desktop Pool"}},@{n="EntitlementType";e={"Local"}},@{n="Entitlements";e={$list}}
        
            $entitlements += $poolInfo
        }
        If($pool.GlobalEntitlementData.GlobalEntitlement -ne $null)
        {
            $list = ""
            $globalEntitlements = Get-HVQueryResult -EntityType EntitledUserOrGroupGlobalSummaryView | Where {$_.GlobalData.GlobalEntitlements.Id -contains $pool.GlobalEntitlementData.GlobalEntitlement.Id}
            foreach ($entitlement in $globalEntitlements)
            {
                $list = $list + ";" + $($entitlement.Base.DisplayName)
            }
            $list = $list.Trim(";")
            $poolInfo = "" | Select @{n="ResourceName";e={$pool.Base.Name}},@{n="ResourceType";e={"Desktop Pool"}},@{n="EntitlementType";e={"Global"}},@{n="Entitlements";e={$list}}
            $entitlements += $poolInfo
        }
    }
}

If ($apps -ne $null)
{
    foreach ($app in $apps)
    {
        $list = ""
        $appEntitlements = get-hvqueryResult -EntityType EntitledUserOrGroupLocalSummaryView | Where {$_.LocalData.Applications.Id -contains $app.Id.Id}
        If ($appEntitlements -ne $null)
        {
            foreach ($entitlement in $appEntitlements)
            {
                $list = $list + ";" + $($entitlement.Base.DisplayName)
            } 
            $list = $list.Trim(";")
            $appInfo = "" | Select @{n="ResourceName";e={$app.Data.Name}},@{n="ResourceType";e={"Application"}},@{n="EntitlementType";e={"Local"}},@{n="Entitlements";e={$list}}
            $entitlements += $appInfo
        }
        If ($app.Data.GlobalApplicationEntitlement.Id -ne $null)
        {
            $list = ""
            $globalEntitlements = Get-HVQueryResult -EntityType EntitledUserOrGroupGlobalSummaryView  | Where {$_.GlobalData.GlobalApplicationEntitlements.Id -contains $app.Data.GlobalApplicationEntitlement.Id}
            foreach ($entitlement in $globalEntitlements)
            {
                $list = $list + ";" + $($entitlement.Base.DisplayName)
            }
            $list = $list.Trim(";")
            $appInfo = "" | Select @{n="ResourceName";e={$app.Data.Name}},@{n="ResourceType";e={"Application"}},@{n="EntitlementType";e={"Global"}},@{n="Entitlements";e={$list}}
            $entitlements += $appInfo
        }
    }

}

$entitlements | Export-Csv -Path $logPath -NoTypeInformation