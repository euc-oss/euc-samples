# New-MgDomainFederation.ps1

Creates a new domain federation configuration in Microsoft Entra ID using Microsoft Graph.

## What this script does

1. Validates required inputs (tenant ID, domain, metadata URI).
2. Fetches and parses IdP metadata XML.
3. Builds a WS-Fed BodyParameter payload for Microsoft Graph.
4. Rewrites IssuerUri using the target domain and metadata base host.
5. Creates the federation configuration using the documented parameter set:
  -DomainId <domain> -BodyParameter <payload>

## Requirements

- PowerShell 7.0+
- Microsoft.Graph.Identity.DirectoryManagement module (installed automatically if missing)
- Entra permissions:
  - Domain-InternalFederation.ReadWrite.All
  - Domain.ReadWrite.All

## Parameters

- TenantId (required): Entra tenant GUID
- Domain (required): Domain to federate (for example, customer.com)
- MetadataUri (required): IdP metadata URL (for example, https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml)
- DisplayName (optional): Display name for the federation (defaults to Domain)
- FederatedIdpMfaBehavior (optional):
  - acceptIfMfaDoneByFederatedIdp (default)
  - rejectMfaByFederatedIdp
  - enforceMfaByFederatedIdp

## Usage examples

```powershell
pwsh -File .\New-MgDomainFederation.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -Domain "customer.com" `
  -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"
```

```powershell
pwsh -File .\New-MgDomainFederation.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -Domain "customer.com" `
  -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" `
  -DisplayName "Customer Corporation" `
  -FederatedIdpMfaBehavior "enforceMfaByFederatedIdp" `
  -Verbose
```

## Payload behavior

The script builds these key BodyParameter fields for New-MgDomainFederationConfiguration:

- DomainId
- DisplayName
- ActiveSignInUri
- PassiveSignInUri
- SignOutUri
- IssuerUri
- MetadataExchangeUri
- SigningCertificate
- NextSigningCertificate (only when present in metadata)
- FederatedIdpMfaBehavior
- PreferredAuthenticationProtocol (wsFed)

## Notes

- This create script does not include backup logic.
- IssuerUri is rewritten using the supplied Domain and the metadata base URL host path.
- SigningCertificate is required and extracted from metadata KeyDescriptor/X509Certificate nodes.
