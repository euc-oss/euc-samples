<#
.SYNOPSIS
    Updates a domain to set its authentication type to Managed in Azure AD/Entra.

.DESCRIPTION
    Connects to Microsoft Graph and updates the specified domain with authentication
    type set to Managed.

.PARAMETER TenantId
    The Azure AD tenant ID.

.PARAMETER Domain
    The domain to update (e.g., contoso.com).

.PARAMETER AuthenticationType
    The authentication type to set. Default is 'Managed'.

.PARAMETER WhatIf
    Simulate the update without making changes.

.EXAMPLE
    .\Update-MgDomain.ps1 -TenantId "..." -Domain "contoso.com"

.EXAMPLE
    .\Update-MgDomain.ps1 -TenantId "..." -Domain "contoso.com" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD tenant ID")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage = "TenantId must be a valid GUID")]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "Domain to update (e.g., contoso.com)")]
    [Alias('DomainId')]
    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$', ErrorMessage = "Domain must be a valid domain name")]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "Authentication type: Managed or Federated")]
    [ValidateSet('Managed', 'Federated')]
    [string]$AuthenticationType = 'Managed',

    [switch]$WhatIf
)

$graphConnectedByScript = $false

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
    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    $hasRequiredScope = $false
    if ($ctx -and $ctx.Scopes) {
        $hasRequiredScope = @($ctx.Scopes) -contains 'Domain.ReadWrite.All'
    }

    if ($ctx -and $ctx.TenantId -eq $TenantId -and $hasRequiredScope) {
        Write-Verbose "Reusing existing Microsoft Graph context for tenant $TenantId"
    }
    else {
        if ($ctx) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -ContextScope Process -ErrorAction Stop
        $graphConnectedByScript = $true
    }
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
        $effectiveAuthenticationType = $AuthenticationType
        if ($result -and $result.AuthenticationType) {
            $effectiveAuthenticationType = $result.AuthenticationType
        }
        else {
            try {
                $domainState = Get-MgDomain -DomainId $Domain -ErrorAction Stop
                if ($domainState -and $domainState.AuthenticationType) {
                    $effectiveAuthenticationType = $domainState.AuthenticationType
                }
            }
            catch {
                Write-Verbose "Could not read back domain state after update: $($_.Exception.Message)"
            }
        }

        Write-Host "✓ Domain updated successfully: $Domain" -ForegroundColor Green
        Write-Host "AuthenticationType: $effectiveAuthenticationType"
    }

    return $result
}
catch {
    Write-Error "Domain update failed: $_"
    exit 1
}
finally {
    if ($graphConnectedByScript) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    Remove-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue
    Remove-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
}
