# DEEM Windows Domain Update Script

- Version: 1.0
- Authors: Aman Dubey - adubey@omnissa.com, Rizul Singh - singhri@omnissa.com
- Creation Date:  2025-04-22

## Overview

<!-- Summary Start -->
This PowerShell script performs the necessary configuration changes to update DEEM's intelligence domain. Supports various DEEM versions installed on Windows, logs changes, and optionally purges queued events.
<!-- Summary End -->

## Usage

1. Run **deem_windows_domain_update.ps1** as administrator:
   ```powershell
   .\deem_windows_domain_update.ps1
   ```
2. To purge queued events use the `--purge-events` argument:
   ```powershell
   .\deem_windows_domain_update.ps1 --purge-events
   ```

## Logging

- Logs are written to the `DEEM_Script_Log\deem_script.log` file in the system’s temp directory.
- Check this file for details about registry and service operations.

## Known Limitations and Dependencies

- PowerShell 5.1 or later
- Administrator privileges
- A supported DEEM version installed on Windows: `23.6`, `23.10`, `24.7`, `24.12`
