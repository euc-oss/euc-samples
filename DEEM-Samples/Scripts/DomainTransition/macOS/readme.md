# DEEM macOS Domain Update Script

- Version: 1.0
- Authors: Josh Stechnij - jstechnij@omnissa.com, Ameen Shah - sameen@omnissa.com
- Creation Date:  2025-04-22

## Overview

<!-- Summary Start -->
This shell script performs the necessary configuration changes to update DEEM's intelligence domain. Supports various DEEM versions installed on macOS and optionally purges queued events.
<!-- Summary End -->
It targets the configuration file located at: `/Library/Application Support/WorkspaceONE/Deem/deem/LegacyDeem.app/Contents/MacOS/appsettings.json`. The script will change the configuration to make the DEEM Agent use the new Omnissa branded WorkspaceOne Intelligence backend service. After updating the specified setting, the script will gracefully relaunch the DEEM Agent to apply the change.

`--purge-events`: An optional command-line flag to purge queue telemetry events.

- After June 2025, DEEM Agent will no longer be able to stream telemetry events to legacy VMware WorkspaceOne Intelligence backend service.
- If the DEEM Agent has continued running past this date without applying the updated configuration, telemetry events may have accumulated locally on endpoint devices.
- Applying this script (without the purge option) will re-enable DEEM Agent to connect to the new Omnissa WorkspaceOne backend. However, any previously accumulated events will begin streaming at once, potentially overwhelming customer's business network.
- To avoid this, use the `--purge-events` option. It will delete the backlog of locally stored telemetry events from the database located at: `/Library/Application Support/WorkspaceONE/Deem/deem-data/sqlite/logs.db`
- After purging, DEEM Agent will begin streaming only new telemetry events to the Omnissa backend.

## Usage

1. Run **deem_macos_update_domain.sh** as administrator without arguments to update the configuration and restart the DEEM Agent:
   ```bashshell
   sudo ./deem_macos_update_domain.sh
   ```
2. Use the `--purge-events` argument to prevent a backlog of telemetry events from flooding the network after switching to Omnissa services:
   ```bashshell
   sudo ./deem_macos_update_domain.sh --purge-events
   ```

## Known Limitations and Dependencies

 - This script must be run with root privileges (sudo) to access and modify system files and services.
