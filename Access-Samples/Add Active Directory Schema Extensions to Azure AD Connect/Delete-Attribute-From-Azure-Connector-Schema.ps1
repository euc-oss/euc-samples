<#
  .SYNOPSIS
  Deletes given attribute from connector schema.

  .DESCRIPTION
  Deletes given attribute from connector schema.

  .PARAMETER AttributeName
  Name of attribute which should be deleted from connector schema.

  .INPUTS
  None.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\Delete-Attribute-From-Azure-Connector-Schema.ps1 -AttributeName extension_bd5927172c6b450d8b2ebae57c54791e_property1
#>

param ([Parameter(Mandatory = $true)][string]$AttributeName)

$ErrorActionPreference = "Stop"

Write-Host "Obtaining Windows Azure Active Directory connectors"
$Connectors = Get-ADSyncConnector | Where-Object {$_.subtype -eq "Windows Azure Active Directory (Microsoft)"}

if ($Connectors.length -gt 0) {
    Do {
        for ($index = 0 ; $index -lt $Connectors.length ; $index++){
            Write-Host "$($index): $($Connectors[$index].Name)"
        }
        $ConnectorIndex = Read-Host -Prompt "Select Windows Azure Active Directory connector"
    } While($ConnectorIndex -lt 0 -or $ConnectorIndex -ge $Connectors.length)
} else {
    throw "Unable to find Windows Azure Active Directory connectors"
}

$AzureConnector = $Connectors[$ConnectorIndex]

ForEach ($ObjectType in $AzureConnector.Schema.ObjectTypes) {
    if ($ObjectType.SchemaBindings.Contains($AttributeName)) {
        Write-Host "Deleting $AttributeName from $ObjectType bindings"
        $ObjectType.SchemaBindings.Remove($AttributeName) | out-null
    }
}

Write-Host "Deleting $AttributeName attribute from connector schema"
$AzureConnector.Schema.AttributeTypes.Remove($AttributeName) | out-null

Write-Host "Saving connector configuration"
Add-ADSyncConnector $AzureConnector | out-null

Write-Host "Attribute sucessfully deleted from connector schema"
return