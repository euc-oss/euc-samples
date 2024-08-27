<#
  .SYNOPSIS
  Deletes Azure AD extension property.

  .DESCRIPTION
  Script uses Azure Graph API to delete extension property.

  .PARAMETER ApplicationName
  Name of application for which extension property should be deleted.

  .PARAMETER PropertyName
  Name of extension property to delete.

  .INPUTS
  None.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\Delete-Extension-Property-From-Azure-AD.ps1 -ApplicationName "My application" -PropertyName property1
#>

param ([Parameter(Mandatory = $false)][string]$ApplicationName = "My Properties Bag",
    [Parameter(Mandatory = $true)][string]$PropertyName)

$ErrorActionPreference = "Stop"

Write-Host "Connecting to Azure Graph API"
Connect-MgGraph -Scopes "Application.ReadWrite.All" -ErrorAction Stop

Write-Host "Obtaining application with name: $ApplicationName"
$Application = Get-MgApplication -Filter "DisplayName eq '$ApplicationName'"

if(!$Application) {
    throw "Unable to obtain application with name: $ApplicationName"
}

$Property = Get-MgApplicationExtensionProperty -ApplicationId $Application.Id | Where-Object {$_.Name -eq $PropertyName}

if(!$Property) {
    throw "Unable to obtain extension property with name: $PropertyName"
}

Write-Host "Deleting extension property with name ${PropertyName}"
Remove-MgApplicationExtensionProperty -ApplicationId $Application.Id -ExtensionPropertyId $Property.Id
Write-Host "Extension property sucessfully deleted"
