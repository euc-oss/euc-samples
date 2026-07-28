# Entra Federation Management Scripts

Version:        1.0  
Author:         Sascha_Warno - swarno@omnissa.com  
Creation Date:  2026-06-26

## Overview

<!-- Summary Start -->
PowerShell samples for managing Microsoft Entra domain authentication and federation settings using Microsoft Graph.
<!-- Summary End -->

This submission includes scripts to set a domain authentication type to switch between managed and federated mode, create new federation configuration from Omnissa Access metadata, and update an existing federation configuration with updated metadata from Omnissa Access with optional backup support.

Two script tracks are provided:

- PowerShell 7+ variants: `New-MgDomainFederation.ps1`, `Update-MgDomain.ps1`, `Update-MgDomainFederation.ps1`
- Windows PowerShell 5.1 variants: `New-MgDomainFederation-PS51.ps1`, `Update-MgDomain-PS51.ps1`, `Update-MgDomainFederation-PS51.ps1`

## Usage

Run with PowerShell 7+:

```powershell
pwsh -File .\Update-MgDomain.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -AuthenticationType "Managed"
```

```powershell
pwsh -File .\New-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"
```

```powershell
pwsh -File .\Update-MgDomainFederation.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -BackupPath ".\backups\federation_backup.csv"
```

Use `-WhatIf` and `-Verbose` when validating changes.

Run with Windows PowerShell 5.1:

```powershell
powershell.exe -File .\Update-MgDomain-PS51.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -AuthenticationType "Managed"
```

```powershell
powershell.exe -File .\New-MgDomainFederation-PS51.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml"
```

```powershell
powershell.exe -File .\Update-MgDomainFederation-PS51.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -Domain "customer.com" -MetadataUri "https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml" -BackupPath ".\backups\federation_backup.csv"
```

## Known Limitations and Dependencies

- Requires either PowerShell 7.0+ (main scripts) or Windows PowerShell 5.1+ (`-PS51` scripts).
- Requires Microsoft Graph PowerShell modules used by the scripts, including `Microsoft.Graph.Identity.DirectoryManagement`.
- Scripts load only the minimum required Graph module set to reduce startup time.
- Requires Microsoft Entra permissions such as `Domain.ReadWrite.All` and `Domain-InternalFederation.ReadWrite.All`.
- Metadata parsing assumes Omnissa Access metadata endpoints in the form `https://tenant.us1.wss.workspaceone.com/SAAS/API/1.0/GET/metadata/idp.xml`.
- `Update-MgDomainFederation.ps1` includes backup behavior and writes CSV output when `-BackupPath` is provided.
- `-PS51` variants were prepared for Windows PowerShell 5.1 compatibility but cannot be runtime-tested in this macOS environment.
