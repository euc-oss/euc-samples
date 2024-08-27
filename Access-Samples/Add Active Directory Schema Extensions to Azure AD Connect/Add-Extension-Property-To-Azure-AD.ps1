<#
  .SYNOPSIS
  Creates Azure AD extension property.

  .DESCRIPTION
  Script uses Azure Graph API to create extension property for specified application. If application doesn't exist,
  it is created togheter with service principal.

  .PARAMETER ApplicationName
  Name of application for which extension property should be created.

  .PARAMETER PropertyName
  Name of extension property to create.

  .PARAMETER PropertyType
  See: https://learn.microsoft.com/en-us/graph/api/application-post-extensionproperty.

  .PARAMETER TargetObjects
  See: https://learn.microsoft.com/en-us/graph/api/application-post-extensionproperty.

  .INPUTS
  None.

  .OUTPUTS
  None.

  .EXAMPLE
  PS> .\Add-Extension-Property-To-Azure-AD.ps1 -ApplicationName "My application" -PropertyName property1 -PropertyType String -TargetObjects Group, User
#>

param ([Parameter(Mandatory = $false)][string]$ApplicationName = "My Properties Bag",
    [Parameter(Mandatory = $true)][string]$PropertyName,
    [Parameter(Mandatory = $false)][string]$PropertyType = "String",
    [Parameter(Mandatory = $false)][string[]]$TargetObjects = @("Group", "User"))

$ErrorActionPreference = "Stop"

Write-Host "Connecting to Azure Graph API"
Connect-MgGraph -Scopes "Application.ReadWrite.All" -ErrorAction Stop

Write-Host "Obtaining application with name: $ApplicationName"
$Application = Get-MgApplication -Filter "DisplayName eq '$ApplicationName'"

if (!$Application) {
    Write-Host "Application with name: $ApplicationName doesn't exist, creating new"
    $Application = New-MgApplication -BodyParameter @{
        DisplayName = "$ApplicationName"
    }
    Write-Host "Creating service principal for application"
    New-MgServicePrincipal -AppId $Application.AppId | out-null
}

Write-Host "Creating extension property with name ${PropertyName} and type ${PropertyType}"
$Property = New-MgApplicationExtensionProperty -ApplicationId $Application.Id  -BodyParameter @{
    Name = "${PropertyName}"
    DataType = "${PropertyType}"
    TargetObjects = $TargetObjects
} -ErrorAction Stop
Write-Host "Property sucessfully created, name: $($Property.Name)"
