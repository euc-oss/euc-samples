<#
.SYNOPSIS
    Creates a new domain federation configuration in Azure AD/Entra using Microsoft Graph.

.DESCRIPTION
    This script fetches SAML/WS-Fed metadata from an identity provider and creates
    a domain federation configuration in Azure AD/Entra ID using the Microsoft.Graph module.

.PARAMETER TenantId
    The Azure AD tenant ID where the domain federation will be created.

.PARAMETER Domain
    The domain to configure for federation (e.g., customer.com).

.PARAMETER MetadataUri
    The URI pointing to the IdP metadata XML file.
    Format: https://baseurl/SAAS/API/1.0/GET/metadata/idp.xml

.PARAMETER DisplayName
    Display name for the federation configuration. If not provided, uses the domain name.

.PARAMETER FederatedIdpMfaBehavior
    MFA behavior for federated IdP. Options:
    - acceptIfMfaDoneByFederatedIdp (default)
    - rejectMfaByFederatedIdp
    - enforceMfaByFederatedIdp

.EXAMPLE
    .\New-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" `
        -Domain "customer.com" `
        -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"

.EXAMPLE
    .\New-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" `
        -Domain "customer.com" `
        -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" `
        -DisplayName "Customer Corporation" `
        -FederatedIdpMfaBehavior "enforceMfaByFederatedIdp" `
#>
#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD tenant ID")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', ErrorMessage = "TenantId must be a valid GUID")]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "Domain to configure for federation (e.g., customer.com)")]
    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$', ErrorMessage = "Domain must be a valid domain name")]
    [string]$Domain,

    [Parameter(Mandatory = $true, HelpMessage = "Metadata URI (e.g., https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml)")]
    [ValidateScript({ $_ -match '^https?://' }, ErrorMessage = "MetadataUri must be a valid HTTP/HTTPS URL")]
    [string]$MetadataUri,

    [Parameter(Mandatory = $false, HelpMessage = "Display name for the federation (defaults to domain name)")]
    [string]$DisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "MFA behavior: acceptIfMfaDoneByFederatedIdp, rejectMfaByFederatedIdp, enforceMfaByFederatedIdp")]
    [ValidateSet('acceptIfMfaDoneByFederatedIdp', 'rejectMfaByFederatedIdp', 'enforceMfaByFederatedIdp')]
    [string]$FederatedIdpMfaBehavior = 'acceptIfMfaDoneByFederatedIdp'
)

# Always use WS-Fed protocol
$Protocol = 'wsFed'

# Set default DisplayName if not provided
if (-not $DisplayName) {
    $DisplayName = $Domain
}

Write-Verbose "Initializing domain federation setup for $Domain"
Write-Verbose "Tenant ID: $TenantId"
Write-Verbose "Metadata URI: $MetadataUri"
Write-Verbose "Protocol: $Protocol"

# ============================================================================
# Function: Extract base URL from metadata URI
# ============================================================================
function Get-BaseUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MetadataUri
    )

    # Extract base URL up to /SAAS/
    if ($MetadataUri -match '^(https?://[^/]+)') {
        return $matches[1]
    }

    throw "Could not extract base URL from metadata URI: $MetadataUri"
}

# ============================================================================
# Function: Fetch and parse metadata
# ============================================================================
function Get-IdpMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MetadataUri
    )

    try {
        Write-Verbose "Fetching metadata from: $MetadataUri"
        $metadata = Invoke-WebRequest -Uri $MetadataUri -UseBasicParsing -ErrorAction Stop
        $xmlContent = [xml]$metadata.Content

        Write-Verbose "Parsing metadata XML"

        # Extract base URL from metadata URI
        $baseUrl = Get-BaseUrl -MetadataUri $MetadataUri

        $Metadata = @{
            ActiveSignInUri           = "$baseUrl/SAAS/auth/wsfed/active/logon"
            PassiveSignInUri          = "$baseUrl/SAAS/API/1.0/POST/sso"
            SignOutUri                = "$baseUrl/SAAS/auth/wsfed/active/logon"
            IssuerUri                 = $baseUrl
            MetadataExchangeUri       = "$baseUrl/SAAS/auth/wsfed/services/mex"
            SigningCertificate        = $null
            NextSigningCertificate    = $null
            Protocol                  = $Protocol
        }

        Write-Verbose "Constructed standard URLs from base URL: $baseUrl"

        # Extract signing certificates from metadata
        $keyDescriptors = $xmlContent.SelectNodes('//*[local-name()="KeyDescriptor"]')
        
        if ($keyDescriptors.Count -gt 0) {
            Write-Verbose "Found $($keyDescriptors.Count) key descriptor(s) in metadata"
            $certIndex = 0
            
            foreach ($keyDesc in $keyDescriptors) {
                # Try different XPath patterns to find certificates
                $cert = $keyDesc.SelectSingleNode('.//*[local-name()="X509Certificate"]')
                
                if ($cert) {
                    $certValue = if ($cert.'#text') { $cert.'#text' } else { $cert.InnerText }
                    
                    if ($certValue) {
                        $certIndex++
                        if ($certIndex -eq 1) {
                            $Metadata.SigningCertificate = $certValue
                            Write-Verbose "Extracted primary signing certificate"
                        }
                        elseif ($certIndex -eq 2) {
                            $Metadata.NextSigningCertificate = $certValue
                            Write-Verbose "Extracted next signing certificate"
                        }
                    }
                }
            }
        }

        # Validate that we got the signing certificate
        if (-not $Metadata.SigningCertificate) {
            throw "Could not extract signing certificate from metadata. Ensure metadata file contains valid X509 certificates."
        }

        # Rewrite IssuerUri using Domain and metadata base URL host path.
        # Example: metadata https://tenant.us1.wss.workspaceone.com -> issuer https://contoso.com.tenant.us1.wss.workspaceone.com
        $issuerPath = $baseUrl -replace '^https?://', ''
        $Metadata.IssuerUri = "https://$Domain.$issuerPath"

        Write-Verbose "Metadata parsing completed successfully"
        Write-Verbose "Base URL: $baseUrl"
        Write-Verbose "Issuer URI: $($Metadata.IssuerUri)"
        return $Metadata
    }
    catch {
        Write-Error "Failed to fetch or parse metadata: $_"
        throw
    }
}

# ============================================================================
# Function: Ensure Microsoft.Graph module installed and loaded
# ============================================================================
function test-prereqs {
    try {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.DirectoryManagement)) {
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

# ============================================================================
# Function: Connect to Graph and create federation
# ============================================================================
function New-MgDomainFederationConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [hashtable]$Metadata,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$FederatedIdpMfaBehavior
    )



    try {
        # Ensure module present and connected
        test-prereqs

        Write-Verbose "Connecting to Microsoft Graph..."
        $scopes = @('Domain-InternalFederation.ReadWrite.All','Domain.ReadWrite.All')
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -ErrorAction Stop
        Write-Verbose "Successfully connected to Microsoft Graph"

        # Build BodyParameter payload for documented Create parameter set
        $bodyParameter = @{
            DisplayName                     = $DisplayName
            ActiveSignInUri                 = $Metadata.ActiveSignInUri
            PassiveSignInUri                = $Metadata.PassiveSignInUri
            SignOutUri                      = $Metadata.SignOutUri
            IssuerUri                       = $Metadata.IssuerUri
            MetadataExchangeUri             = $Metadata.MetadataExchangeUri
            SigningCertificate              = $Metadata.SigningCertificate
            FederatedIdpMfaBehavior         = $FederatedIdpMfaBehavior
            PreferredAuthenticationProtocol = $Protocol
        }

        if ($Metadata.NextSigningCertificate) {
            $bodyParameter['NextSigningCertificate'] = $Metadata.NextSigningCertificate
            Write-Verbose "NextSigningCertificate will be configured"
        }

        Write-Verbose "Creating domain federation with body payload:"
        $bodyParameter.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }

        # Create the federation configuration using documented parameter set:
        # New-MgDomainFederationConfiguration -DomainId <string> -BodyParameter <hashtable>
        $result = New-MgDomainFederationConfiguration -DomainId $Domain -BodyParameter $bodyParameter -ErrorAction Stop
        
        $DisplayNameOutput = if ($result.DisplayName) { $result.DisplayName } else { $DisplayName }
        $IssuerURIOutput = if ($result.IssuerUri) { $result.IssuerUri } else { $Metadata.IssuerUri }

        Write-Host "✓ Domain federation created successfully for $Domain" -ForegroundColor Green
        Write-Host "Display Name: $DisplayNameOutput"
        Write-Host "Issuer URI: $IssuerURIOutput"
        Write-Host "Active SignIn URI: $($result.ActiveSignInUri)"
        Write-Host "Passive SignIn URI: $($result.PassiveSignInUri)"
        
        return $result
    }
    catch {
        Write-Error "Failed to create domain federation: $_"
        throw
    }
}

# ============================================================================
# Main execution
# ============================================================================
try {
    Write-Host "Starting domain federation creation process..." -ForegroundColor Cyan

    # Step 1: Fetch and parse metadata
    Write-Host "`nStep 1: Fetching identity provider metadata..." -ForegroundColor Yellow
    $metadata = Get-IdpMetadata -MetadataUri $MetadataUri

    Write-Host "✓ Metadata retrieved successfully" -ForegroundColor Green
    Write-Verbose "Extracted metadata:"
    $metadata.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }

    # Step 2: Create domain federation
    Write-Host "`nStep 2: Creating domain federation configuration..." -ForegroundColor Yellow
    $federation = New-MgDomainFederationConfiguration `
        -TenantId $TenantId `
        -Domain $Domain `
        -Metadata $metadata `
        -DisplayName $DisplayName `
        -FederatedIdpMfaBehavior $FederatedIdpMfaBehavior

    Write-Host "`n✓ Process completed successfully!" -ForegroundColor Green
    Write-Host "Domain $Domain is now configured for federation." -ForegroundColor Green

    # Return the created configuration object
    return $federation
}
catch {
    Write-Error "Domain federation creation failed. See errors above for details."
    exit 1
}
