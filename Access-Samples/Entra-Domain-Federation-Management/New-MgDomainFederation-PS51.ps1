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

.PARAMETER AuthenticationMethod
    Authentication method for Connect-MgGraph.
    - Interactive (default): browser-based sign-in
    - DeviceCode: device code sign-in

.EXAMPLE
    .\New-MgDomainFederation-PS51.ps1 -TenantId "12345678-1234-1234-1234-123456789012" `
        -Domain "customer.com" `
        -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"

.EXAMPLE
    .\New-MgDomainFederation-PS51.ps1 -TenantId "12345678-1234-1234-1234-123456789012" `
        -Domain "customer.com" `
        -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" `
        -DisplayName "Customer Corporation" `
        -FederatedIdpMfaBehavior "enforceMfaByFederatedIdp" `
#>
#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD tenant ID")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "Domain to configure for federation (e.g., customer.com)")]
    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$')]
    [string]$Domain,

    [Parameter(Mandatory = $true, HelpMessage = "Metadata URI (e.g., https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml)")]
    [ValidateScript({ $_ -match '^https?://' })]
    [string]$MetadataUri,

    [Parameter(Mandatory = $false, HelpMessage = "Display name for the federation (defaults to domain name)")]
    [string]$DisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "MFA behavior: acceptIfMfaDoneByFederatedIdp, rejectMfaByFederatedIdp, enforceMfaByFederatedIdp")]
    [ValidateSet('acceptIfMfaDoneByFederatedIdp', 'rejectMfaByFederatedIdp', 'enforceMfaByFederatedIdp')]
    [string]$FederatedIdpMfaBehavior = 'acceptIfMfaDoneByFederatedIdp',

    [Parameter(Mandatory = $false, HelpMessage = "Authentication method: Interactive (browser) or DeviceCode")]
    [ValidateSet('Interactive', 'DeviceCode')]
    [string]$AuthenticationMethod = 'Interactive'
)

$script:graphConnectedByScript = $false

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
            BaseUrl                   = $baseUrl
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
                            break
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
            Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop -Verbose:$false
        }

        # Fallback: install umbrella package if the submodule still is not discoverable.
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Host "$moduleName still not found. Installing Microsoft.Graph as fallback..." -ForegroundColor Yellow
            Install-Module -Name Microsoft.Graph -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop -Verbose:$false
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
                    Import-Module -Name $authManifestPath -ErrorAction Stop -Verbose:$false
                }
            }
        }

        if (-not (Get-Module -Name $authModuleName)) {
            Import-Module -Name $authModuleName -ErrorAction Stop -Verbose:$false
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
            Import-Module -Name $modulePath -ErrorAction Stop -Verbose:$false
        }
        else {
            Import-Module -Name $moduleName -ErrorAction Stop -Verbose:$false
        }
        Write-Verbose "Microsoft.Graph.Identity.DirectoryManagement module is available"
    }
    catch {
        Write-Error ('Failed to install or import Microsoft.Graph: {0}' -f $_)
        throw
    }
}

# ============================================================================
# Function: Connect to Graph and create federation
# ============================================================================
function Invoke-NewMgDomainFederationConfiguration {
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
        [string]$FederatedIdpMfaBehavior,

        [Parameter(Mandatory = $true)]
        [string]$AuthenticationMethod
    )



    try {
        # Ensure module present and connected
        test-prereqs

        Write-Verbose "Connecting to Microsoft Graph..."
        $scopes = @('Domain-InternalFederation.ReadWrite.All','Domain.ReadWrite.All')
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

            if ($AuthenticationMethod -eq 'DeviceCode') {
                Write-Verbose "Authenticating to Graph using device code flow"
                Connect-MgGraph -TenantId $TenantId -Scopes $scopes -UseDeviceCode -NoWelcome -ContextScope Process -ErrorAction Stop
            }
            else {
                Write-Verbose "Authenticating to Graph using interactive browser flow"
                Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome -ContextScope Process -ErrorAction Stop
            }

            $script:graphConnectedByScript = $true
        }

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

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Verbose "Creating domain federation with body payload:"
            $bodyParameter.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }
        }

        # Create the federation configuration using documented parameter set:
        # New-MgDomainFederationConfiguration -DomainId <string> -BodyParameter <hashtable>
        try {
            $result = New-MgDomainFederationConfiguration -DomainId $Domain -BodyParameter $bodyParameter -ErrorAction Stop
        }
        catch {
            $createMsg = $_.Exception.Message
            $createInner = if ($_.Exception -and $_.Exception.InnerException) { $_.Exception.InnerException.Message } else { '' }
            if (($createMsg -match 'writing to a listener') -or ($createInner -match 'operation was canceled')) {
                Write-Error "Graph listener/authentication state failed during federation create. Start a fresh PowerShell console and rerun the script to perform a new device-code sign-in."
            }
            throw
        }
        
        $DisplayNameOutput = if ($result.DisplayName) { $result.DisplayName } else { $DisplayName }
        $IssuerURIOutput = if ($result.IssuerUri) { $result.IssuerUri } else { $Metadata.IssuerUri }

        Write-Host "Domain federation created successfully for $Domain" -ForegroundColor Green
        Write-Host "Display Name: $DisplayNameOutput"
        Write-Host "Issuer URI: $IssuerURIOutput"
        Write-Host "Active SignIn URI: $($result.ActiveSignInUri)"
        Write-Host "Passive SignIn URI: $($result.PassiveSignInUri)"
        
        return $result
    }
    catch {
        $inner = if ($_.Exception -and $_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        if ($inner) {
            Write-Error ('Failed to create domain federation: {0} | Inner: {1}' -f $_.Exception.Message, $inner)
        }
        else {
            Write-Error ('Failed to create domain federation: {0}' -f $_.Exception.Message)
        }
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

    Write-Host "Metadata retrieved successfully" -ForegroundColor Green
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Verbose "Extracted metadata:"
        $metadata.GetEnumerator() | ForEach-Object { Write-Verbose "  $($_.Key): $($_.Value)" }
    }

    # Step 2: Create domain federation
    Write-Host "`nStep 2: Creating domain federation configuration..." -ForegroundColor Yellow
    $federation = Invoke-NewMgDomainFederationConfiguration `
        -TenantId $TenantId `
        -Domain $Domain `
        -Metadata $metadata `
        -DisplayName $DisplayName `
        -FederatedIdpMfaBehavior $FederatedIdpMfaBehavior `
        -AuthenticationMethod $AuthenticationMethod

    Write-Host "`nProcess completed successfully!" -ForegroundColor Green
    Write-Host "Domain $Domain is now configured for federation." -ForegroundColor Green

    # Return the created configuration object
    return $federation
}
catch {
    $inner = if ($_.Exception -and $_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
    if ($inner) {
        Write-Error ('Domain federation creation failed: {0} | Inner: {1}' -f $_.Exception.Message, $inner)
    }
    else {
        Write-Error ('Domain federation creation failed: {0}' -f $_.Exception.Message)
    }
    exit 1
}
finally {
    if ($script:graphConnectedByScript) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    Remove-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue
    Remove-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
}
