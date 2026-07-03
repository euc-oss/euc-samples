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

$graphConnectedByScript = $false

# ============================================================================
# Function: Ensure Microsoft.Graph module installed and loaded
# ============================================================================
function test-prereqs {
    try {
        $moduleName = 'Microsoft.Graph.Identity.DirectoryManagement'
        $authModuleName = 'Microsoft.Graph.Authentication'
        $modulePath = $null

        # Ensure user module location is in PSModulePath for this session.
        $userModuleRoot = Join-Path -Path $HOME -ChildPath 'Documents\\WindowsPowerShell\\Modules'
        if ((Test-Path -LiteralPath $userModuleRoot) -and (($env:PSModulePath -split ';') -notcontains $userModuleRoot)) {
            $env:PSModulePath = "$userModuleRoot;$env:PSModulePath"
        }

        # PowerShell 5.1 often needs explicit TLS 1.2 and NuGet provider bootstrapping.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        }

        # Ensure PSGallery can be used non-interactively.
        $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Host "$moduleName module not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }

        # Fallback: install umbrella package if the submodule still is not discoverable.
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Host "$moduleName still not found. Installing Microsoft.Graph as fallback..." -ForegroundColor Yellow
            Install-Module -Name Microsoft.Graph -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }

        # Pre-load auth dependency explicitly because submodules require it.
        if (-not (Get-Module -ListAvailable -Name $authModuleName)) {
            $authInstalled = Get-InstalledModule -Name $authModuleName -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            if ($authInstalled -and $authInstalled.InstalledLocation) {
                $authRoot = Split-Path -Path $authInstalled.InstalledLocation -Parent
                if (($env:PSModulePath -split ';') -notcontains $authRoot) {
                    $env:PSModulePath = "$authRoot;$env:PSModulePath"
                }

                $authManifestPath = Join-Path -Path $authInstalled.InstalledLocation -ChildPath ($authModuleName + '.psd1')
                if (Test-Path -LiteralPath $authManifestPath) {
                    Import-Module -Name $authManifestPath -ErrorAction Stop
                }
            }
        }

        if (-not (Get-Module -Name $authModuleName)) {
            Import-Module -Name $authModuleName -ErrorAction Stop
        }

        # Some Windows PowerShell 5.1 environments have PSModulePath issues even after install.
        # Resolve from installed location and import by explicit path if needed.
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            $installed = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            if ($installed -and $installed.InstalledLocation) {
                $moduleRoot = Split-Path -Path $installed.InstalledLocation -Parent
                if (($env:PSModulePath -split ';') -notcontains $moduleRoot) {
                    $env:PSModulePath = "$moduleRoot;$env:PSModulePath"
                }

                $manifestPath = Join-Path -Path $installed.InstalledLocation -ChildPath ($moduleName + '.psd1')
                if (Test-Path -LiteralPath $manifestPath) {
                    $modulePath = $manifestPath
                }
            }
        }

        if ($modulePath) {
            Import-Module -Name $modulePath -ErrorAction Stop
        }
        else {
            Import-Module -Name $moduleName -ErrorAction Stop
        }
        Write-Verbose "Microsoft.Graph.Identity.DirectoryManagement module is available"
    }
    catch {
        Write-Error ('Failed to install or import Microsoft.Graph: {0}' -f $_)
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
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -UseDeviceCode -NoWelcome -ContextScope Process -ErrorAction Stop
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

        Write-Host "Domain updated successfully: $Domain" -ForegroundColor Green
        Write-Host "AuthenticationType: $effectiveAuthenticationType"
    }

    return $result
}
catch {
    Write-Error ('Domain update failed: {0}' -f $_)
    exit 1
}
finally {
    if ($graphConnectedByScript) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    Remove-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue
    Remove-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
}
