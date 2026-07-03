<#
.SYNOPSIS
    Updates a domain to set its authentication type to Managed in Azure AD/Entra.

.DESCRIPTION
    Connects to Microsoft Graph and updates the specified domain with authentication
    type set to Managed.

.PARAMETER TenantId
    The Azure AD tenant ID.

.PARAMETER DomainId
    The domain to update (e.g., contoso.com).

.PARAMETER AuthenticationType
    The authentication type to set. Default is 'Managed'.

.PARAMETER WhatIf
    Simulate the update without making changes.

.EXAMPLE
    .\Update-MgDomain-PS51.ps1 -TenantId "..." -Domain "contoso.com"

.EXAMPLE
    .\Update-MgDomain-PS51.ps1 -TenantId "..." -Domain "contoso.com" -WhatIf
#>
#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD tenant ID")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "Domain to update (e.g., contoso.com)")]
    [Alias('DomainId')]
    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$')]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "Authentication type: Managed or Federated")]
    [ValidateSet('Managed', 'Federated')]
    [string]$AuthenticationType = 'Managed',

    [switch]$WhatIf
)

# ============================================================================
# Function: Ensure Microsoft.Graph module installed and loaded
# ============================================================================
function test-prereqs {
    try {
        if (-not (Get-Module -Name Microsoft.Graph.Identity.DirectoryManagement) -and -not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.DirectoryManagement)) {
            Write-Host "Microsoft.Graph.Identity.DirectoryManagement module not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }

        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
        Write-Verbose "Microsoft.Graph.Identity.DirectoryManagement module is available"
    }
    catch {
        Write-Error "Failed to install or import Microsoft.Graph: $_"
        throw
    }
}

try {
    Write-Host "Starting domain update process..." -ForegroundColor Cyan
    Write-Verbose "Domain: $Domain"
    Write-Verbose "AuthenticationType: $AuthenticationType"

    # Ensure module and connect
    test-prereqs

    Write-Verbose "Connecting to Microsoft Graph..."
    $scopes = @('Domain.ReadWrite.All')
    Connect-MgGraph -TenantId $TenantId -Scopes $scopes -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph"

    # Build parameters
    $params = @{
        DomainId           = $Domain
        AuthenticationType = $AuthenticationType
    }

    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Verbose "Updating domain with parameters:"
        $params.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }
    }

    if ($WhatIf) {
        Update-MgDomain @params -WhatIf
        Write-Host "WhatIf: domain update simulated." -ForegroundColor Yellow
    }
    else {
        $result = Update-MgDomain @params -ErrorAction Stop
        Write-Host "✓ Domain updated successfully: $Domain" -ForegroundColor Green
        Write-Host "AuthenticationType: $($result.AuthenticationType)"
    }

    return $result
}
catch {
    Write-Error "Domain update failed: $_"
    exit 1
}
