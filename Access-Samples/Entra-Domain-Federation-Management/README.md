# Entra Federation Management Scripts

Version:        1.0  
Author:         Sascha_Warno - swarno@omnissa.com  
Creation Date:  2026-06-26

## Overview

<!-- Summary Start -->
PowerShell samples for managing Microsoft Entra domain authentication and federation settings using Microsoft Graph.
<!-- Summary End -->

This submission includes scripts to set a domain authentication type, create new federation configuration from Omnissa Access metadata, and update an existing federation configuration with optional backup support.

## Usage

Run with PowerShell 7+:

```powershell
pwsh -File .\Update-MgDomain.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -DomainId "customer.com" -AuthenticationType "Managed"
```

```powershell
pwsh -File .\New-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"
```

```powershell
pwsh -File .\Update-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -BackupPath ".\backups\federation_backup.csv"
```

Use `-WhatIf` and `-Verbose` when validating changes.

## Known Limitations and Dependencies

- Requires PowerShell 7.0 or later.
- Requires Microsoft Graph PowerShell modules used by the scripts, including `Microsoft.Graph.Identity.DirectoryManagement`.
- Requires Microsoft Entra permissions such as `Domain.ReadWrite.All` and `Domain-InternalFederation.ReadWrite.All`.
- Metadata parsing assumes Omnissa Access metadata endpoints in the form `https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml`.
- `Update-MgDomainFederation.ps1` includes backup behavior and writes CSV output when `-BackupPath` is provided.
