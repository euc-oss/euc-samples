<#
.SYNOPSIS
    Updates an existing domain federation configuration in Azure AD/Entra using Microsoft Graph.

.DESCRIPTION
    Fetches IdP metadata, extracts required values, and updates an existing domain
    federation configuration using Update-MgDomainFederationConfiguration.
    Optionally creates a backup of the current configuration before making changes.

.PARAMETER TenantId
    The Azure AD tenant ID where the domain federation exists.

.PARAMETER Domain
    The domain to configure for federation (e.g., customer.com).

.PARAMETER InternalDomainFederationId
    The internal ID of the domain federation configuration to update. If not provided, it will be automatically retrieved.

.PARAMETER MetadataUri
    The URI pointing to the IdP metadata XML file used to extract new values.

.PARAMETER DisplayName
    Optional display name to update.

.PARAMETER FederatedIdpMfaBehavior
    Optional MFA behavior. Defaults to acceptIfMfaDoneByFederatedIdp.

.PARAMETER BackupPath
    Optional path for the backup CSV file. Defaults to ./O365_Federation_Backup_<timestamp>.csv

.EXAMPLE
    .\Update-MgDomainFederation.ps1 -TenantId "..." -Domain "customer.com" -InternalDomainFederationId "abc123" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"

.EXAMPLE
    .\Update-MgDomainFederation.ps1 -TenantId "..." -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -BackupPath ".\backups\federation_backup.csv"

.EXAMPLE
    .\Update-MgDomainFederation.ps1 -TenantId "..." -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -WhatIf

.EXAMPLE
    on Windows PowerShell run using pwsh.exe as it requires Powershell 7.x and default for running PS1 files is using powershell.exe in version 5.1
    pwsh.exe -File .\Update-MgDomainFederation.ps1 -TenantId "..." -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -FederatedIdpMfaBehavior "enforceMfaByFederatedIdp"    
#>
#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage = "TenantId must be a valid GUID")]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$', ErrorMessage = "Domain must be a valid domain name")]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = 'InternalDomainFederationId from existing federation. If not provided, it will be automatically retrieved.')]
    [string]$InternalDomainFederationId,

    [Parameter(Mandatory = $true, HelpMessage = 'Metadata URI (e.g., https://baseurl/SAAS/API/1.0/GET/metadata/idp.xml)')]
    [ValidateScript({ $_ -match '^https?://' }, ErrorMessage = "MetadataUri must be a valid HTTP/HTTPS URL")]
    [string]$MetadataUri,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('acceptIfMfaDoneByFederatedIdp','rejectMfaByFederatedIdp','enforceMfaByFederatedIdp')]
    [string]$FederatedIdpMfaBehavior = 'acceptIfMfaDoneByFederatedIdp',

    [Parameter(Mandatory = $false)]
    [string]$BackupPath = "O365_Federation_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",

    [switch]$WhatIf
)

$graphConnectedByScript = $false

# Always use WS-Fed protocol
$Protocol = 'wsFed'

# Standalone implementation - no dependency on New-MgDomainFederation.ps1
function Get-BaseUrl {
    param([string]$MetadataUri)
    if ($MetadataUri -match '^(https?://[^/]+)') { return $matches[1] }
    throw "Could not extract base URL from metadata URI: $MetadataUri"
}

function Get-IdpMetadata {
    param([string]$MetadataUri)
    try {
        $meta = Invoke-WebRequest -Uri $MetadataUri -UseBasicParsing -ErrorAction Stop
        $xml = [xml]$meta.Content
        $baseUrl = Get-BaseUrl -MetadataUri $MetadataUri

        $Metadata = @{
            ActiveSignInUri = "$baseUrl/SAAS/auth/wsfed/active/logon"
            PassiveSignInUri = "$baseUrl/SAAS/API/1.0/POST/sso"
            SignOutUri = "$baseUrl/SAAS/auth/wsfed/active/logon"
            IssuerUri = $baseUrl
            MetadataExchangeUri = "$baseUrl/SAAS/auth/wsfed/services/mex"
            SigningCertificate = $null
            NextSigningCertificate = $null
            BaseUrl = $baseUrl
            Protocol = $Protocol
        }

        $keyDescriptors = $xml.SelectNodes('//*[local-name()="KeyDescriptor"]')
        if ($keyDescriptors -and $keyDescriptors.Count -gt 0) {
            $idx = 0
            foreach ($kd in $keyDescriptors) {
                $cert = $kd.SelectSingleNode('.//*[local-name()="X509Certificate"]')
                if ($cert) {
                    $val = if ($cert.'#text') { $cert.'#text' } else { $cert.InnerText }
                    if ($val) {
                        $idx++
                        if ($idx -eq 1) { $Metadata.SigningCertificate = $val }
                        elseif ($idx -eq 2) {
                            $Metadata.NextSigningCertificate = $val
                            break
                        }
                    }
                }
            }
        }

        if (-not $Metadata.SigningCertificate) { throw "Could not extract signing certificate from metadata." }
        return $Metadata
    }
    catch {
        Write-Error "Failed to fetch/parse metadata: $_"
        throw
    }
}

function test-prereqs {
    try {
        if (-not (Get-Module -Name Microsoft.Graph.Identity.DirectoryManagement) -and -not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.DirectoryManagement)) {
            Write-Host "Microsoft.Graph.Identity.DirectoryManagement module not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to install/import Microsoft.Graph: $_"
        throw
    }
}

try {
    Write-Host "Starting update of domain federation configuration..." -ForegroundColor Cyan
    Write-Host "Loading the Graph module and connecting authorization in browser..." -ForegroundColor Cyan
    # Ensure module and connect
    test-prereqs
    $scopes = @('Domain-InternalFederation.ReadWrite.All','Domain.ReadWrite.All')
    Write-Verbose "Connecting to Microsoft Graph with scopes: $($scopes -join ',')"
    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    $requiredScopes = @('Domain-InternalFederation.ReadWrite.All','Domain.ReadWrite.All')
    $hasRequiredScopes = $false
    if ($ctx -and $ctx.Scopes) {
        $missingScopes = $requiredScopes | Where-Object { $_ -notin @($ctx.Scopes) }
        $hasRequiredScopes = ($missingScopes.Count -eq 0)
    }

    if ($ctx -and $ctx.TenantId -eq $TenantId -and $hasRequiredScopes) {
        Write-Verbose "Reusing existing Microsoft Graph context for tenant $TenantId"
    }
    else {
        if ($ctx) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -ContextScope Process -ErrorAction Stop
        $graphConnectedByScript = $true
    }

    $federationConfig = $null

    # Get InternalDomainFederationId if not provided
    if (-not $InternalDomainFederationId) {
        Write-Host "Retrieving InternalDomainFederationId for domain $Domain..." -ForegroundColor Yellow
            Write-Host "Potentially authorization in browser again..." -ForegroundColor Cyan
        try {
            $federationConfig = Get-MgDomainFederationConfiguration -DomainId $Domain -ErrorAction Stop
            $InternalDomainFederationId = $federationConfig.Id
            Write-Host "Found InternalDomainFederationId: $InternalDomainFederationId" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to retrieve InternalDomainFederationId for domain ${Domain}: $_"
            throw
        }
    }

    # Create backup if BackupPath is specified
    if ($BackupPath) {
        Write-Host "Creating backup of current federation configuration..." -ForegroundColor Yellow
        try {
            if (-not $federationConfig) {
                $federationConfig = Get-MgDomainFederationConfiguration -DomainId $Domain -ErrorAction Stop
            }

            $backupData = $federationConfig | Select-Object DomainId, Id, IssuerUri, ActiveSignInUri, PassiveSignInUri, MetadataExchangeUri, SigningCertificate, DisplayName
            $backupData | Export-Csv -Path $BackupPath -NoTypeInformation
            Write-Host "Backup created successfully at: $BackupPath" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to create backup: $_"
        }
    }

    # Fetch and parse metadata
    Write-Host "Fetching metadata from $MetadataUri" -ForegroundColor Yellow
    $metadata = Get-IdpMetadata -MetadataUri $MetadataUri
    Write-Host "Metadata parsed successfully" -ForegroundColor Green
    
    # Rewrite IssuerUri using the Domain parameter and base URL path
    $baseUrl = $metadata.BaseUrl
    $issuerPath = $baseUrl -replace '^https?://', ''
    $metadata.IssuerUri = "https://$Domain.$issuerPath"

    # Build parameters
    $params = @{
        DomainId = $Domain
        InternalDomainFederationId = $InternalDomainFederationId
        ActiveSignInUri = $metadata.ActiveSignInUri
        PassiveSignInUri = $metadata.PassiveSignInUri
        SignOutUri = $metadata.SignOutUri
        IssuerUri = $metadata.IssuerUri
        MetadataExchangeUri = $metadata.MetadataExchangeUri
        SigningCertificate = $metadata.SigningCertificate
        FederatedIdpMfaBehavior = $FederatedIdpMfaBehavior
        PreferredAuthenticationProtocol = $Protocol
    }

    if ($metadata.NextSigningCertificate) {
        $params['NextSigningCertificate'] = $metadata.NextSigningCertificate
    }

    if ($DisplayName) { $params['DisplayName'] = $DisplayName }

    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Verbose "Updating domain federation with parameters:"
        $params.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }
    }

    if ($WhatIf) {
        Update-MgDomainFederationConfiguration @params -WhatIf
        Write-Host "WhatIf: update simulated." -ForegroundColor Yellow
    }
    else {
        $result = Update-MgDomainFederationConfiguration @params -ErrorAction Stop
        $DisplayNameOutput = if ($result.DisplayName) { $result.DisplayName } else { $Domain }
        $IssuerURIOutput = if ($result.IssuerUri) { $result.IssuerUri } else { $metadata.IssuerUri }
        Write-Host "✓ Domain federation updated successfully for $Domain" -ForegroundColor Green
        Write-Host "Display Name: $DisplayNameOutput"
        Write-Host "Issuer URI: $IssuerURIOutput"
    }

    return $result
}
catch {
    Write-Error "Update failed: $_"
    exit 1
}
finally {
    if ($graphConnectedByScript) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    Remove-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue
    Remove-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
}
