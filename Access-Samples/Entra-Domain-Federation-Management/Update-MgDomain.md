# Update-MgDomain.ps1

Updates a Microsoft Entra domain authentication type using Microsoft Graph.

## What this script does

1. Validates required inputs (tenant ID, domain ID, authentication type).
2. Ensures the Microsoft Graph module is available.
3. Connects to Microsoft Graph with domain write scope.
4. Builds the update payload for Update-MgDomain.
5. Applies the authentication type change (Managed or Federated), or simulates with WhatIf.

## Requirements

- PowerShell 7.0+
- Microsoft.Graph PowerShell module (installed automatically if missing)
- Entra permissions:
  - Domain.ReadWrite.All

## Parameters

- TenantId (required): Entra tenant GUID
- DomainId (required): Domain to update (for example, customer.com)
- AuthenticationType (optional): Managed or Federated (default: Managed)
- WhatIf (optional): Simulates the update without making changes

## Usage examples

```powershell
pwsh -File .\Update-MgDomain.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -DomainId "customer.com"
```

```powershell
pwsh -File .\Update-MgDomain.ps1 `
  -TenantId "12345678-1234-1234-1234-123456789012" `
  -DomainId "customer.com" `
  -AuthenticationType "Federated" `
  -WhatIf `
  -Verbose
```

## Payload behavior

The script builds these key fields for Update-MgDomain:

- DomainId
- AuthenticationType

## Notes

- Use WhatIf before production changes to validate behavior.
- The target domain must exist in the tenant and support the requested authentication state.
