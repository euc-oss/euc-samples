# Update-MgDomainFederation.ps1

Updates an existing domain federation configuration in Microsoft Entra ID using Microsoft Graph.

## What this script does

1. Validates required inputs (tenant ID, domain, metadata URI).
2. Ensures Microsoft Graph module prerequisites are available.
3. Connects to Microsoft Graph with federation/domain write scopes.
4. Resolves InternalDomainFederationId automatically when not supplied.
5. Optionally exports a CSV backup of current federation settings.
6. Fetches and parses Omnissa Access IdP metadata.
7. Rebuilds and applies federation settings using Update-MgDomainFederationConfiguration.

## Requirements

- PowerShell 7.0+
- Microsoft.Graph PowerShell module (installed automatically if missing)
- Entra permissions:
  - Domain-InternalFederation.ReadWrite.All
  - Domain.ReadWrite.All

## Parameters

- TenantId (required): Entra tenant GUID
- Domain (required): Domain to update (for example, customer.com)
- InternalDomainFederationId (optional): Existing internal federation ID. If omitted, it is looked up automatically.
- MetadataUri (required): IdP metadata URL (for example, https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml)
- DisplayName (optional): Display name to set on the federation object
- FederatedIdpMfaBehavior (optional):
  - acceptIfMfaDoneByFederatedIdp (default)
  - rejectMfaByFederatedIdp
  - enforceMfaByFederatedIdp
- BackupPath (optional): CSV backup output path (default timestamped file in current directory)
- WhatIf (optional): Simulates the update

## Usage examples

```powershell
pwsh -File .\Update-MgDomainFederation.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -Domain "customer.com" `
  -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"
```

```powershell
pwsh -File .\Update-MgDomainFederation.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -Domain "customer.com" `
  -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" `
  -BackupPath ".\backups\federation_backup.csv" `
  -WhatIf `
  -Verbose
```

## Payload behavior

The script builds these key fields for Update-MgDomainFederationConfiguration:

- DomainId
- InternalDomainFederationId
- ActiveSignInUri
- PassiveSignInUri
- SignOutUri
- IssuerUri
- MetadataExchangeUri
- SigningCertificate
- NextSigningCertificate (only when present in metadata)
- FederatedIdpMfaBehavior
- PreferredAuthenticationProtocol (wsFed)
- DisplayName (only when provided)

## Notes

- IssuerUri is rewritten using the supplied Domain and metadata base URL host path.
- Backup is attempted before update when BackupPath is present.
- SigningCertificate must be discoverable in metadata KeyDescriptor/X509Certificate nodes.
