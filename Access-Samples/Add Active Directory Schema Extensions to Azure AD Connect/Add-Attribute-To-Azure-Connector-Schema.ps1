<#
  .SYNOPSIS
  Adds given Azure AD extension property to connector schema.

  .DESCRIPTION
  Script adds given Azure AD extension property to connector schema. Attribute can be later used to Synchronization Rules Editor.

  .PARAMETER AttributeName
  Full name of extension property in Azure AD which should be added to connector schema.

  .PARAMETER AttributeType
  Type of extension property in Azure AD which should be added to connector schema.
  Supported types: String, Integer, Boolean, Binary, Reference, Number.

  .PARAMETER ObjectTypes
  Object types which are allowed to use the attribute.
  Supported types: contact, device, group, publicFolder, user.

  .INPUTS
  None.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\Add-Attribute-To-Azure-Connector-Schema.ps1 -AttributeName extension_bd5927172c6b450d8b2ebae57c54791e_property1 -AttributeType String -ObjectTypes user, group
#>

param ([Parameter(Mandatory = $true)][string]$AttributeName,
    [Parameter(Mandatory = $false)][string]$AttributeType = "String",
    [Parameter(Mandatory = $false)][String[]]$ObjectTypes = @("user", "group"))

$ErrorActionPreference = "Stop"

$SupportedAttributeTypes = [Microsoft.IdentityManagement.PowerShell.ObjectModel.SchemaAttributeType].GetEnumValues().ForEach({ $_.ToString() })
if(!$SupportedAttributeTypes.Contains($AttributeType)) {
    throw "Invalid attribute type: $AttributeType, supported types: $($SupportedAttributeTypes -join ', ')"
}

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

Write-Host "Adding $AttributeName attribute with type $AttributeType to connector schema"
$NewAttribute = New-Object -TypeName Microsoft.IdentityManagement.PowerShell.ObjectModel.SchemaAttribute -Property @{
    Identifier = "$AttributeName"
    Name = "$AttributeName"
    AllowsMultipleValues = False
    Type = "$AttributeType"
    Indexable = False
    Indexed = False
    Encrypted = False
    SupportedAttributeOperationType = "ReadWrite"
}

$AzureConnector.Schema.AttributeTypes.Add($NewAttribute)

ForEach ($ObjectType in $ObjectTypes) {
    Write-Host "Adding $AttributeName to $ObjectType bindings"
    if (!$AzureConnector.Schema.ObjectTypes[$ObjectType]) {
        throw "Invalid object type: $ObjectType"
    }
    $newUserBinding = New-Object -TypeName Microsoft.IdentityManagement.PowerShell.ObjectModel.SchemaBinding -Property @{
        AttributeIdentifier = "$AttributeName"
        Required = False;
        IsAnchor = False;
    }
    $AzureConnector.Schema.ObjectTypes[$ObjectType].SchemaBindings.Add($newUserBinding)
}

Write-Host "Saving connector configuration"
Add-ADSyncConnector $AzureConnector | out-null

Write-Host "Attribute sucessfully added to connector schema"
return