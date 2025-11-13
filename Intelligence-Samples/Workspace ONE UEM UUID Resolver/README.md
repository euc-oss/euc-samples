# Workspace ONE UEM UUID Resolver — User Guide

Author: Xuyang Zhang, Omnissa
Last Edit: August 29, 2025
Version 1.0

## Overview
<!-- Summary Start -->
This Chrome extension resolves selected UUIDs on Omnissa Intelligence pages into readable entity details. Use the context menu to resolve, and view results via toasts and notifications.
<!-- Summary End -->

## Install
1) Open chrome://extensions/
2) Enable Developer mode
3) Click "Load unpacked" and select the extension folder

## Configure
1) Click the extension icon to open Settings (or right-click any page → Open UUID Resolver Settings)
2) Enter:
   - UEM API Base URL (e.g., https://*.awmdm.com/API)
   - Organization Group ID
   - Authentication:
     - Basic: username, password, API Key (tenant code) — Required. The API key will be sent in the aw-tenant-code header for all API calls.
     - OAuth: client ID, client secret, token URL
3) Click Test Connection to validate

## Use
- On Intelligence page, for example in a Freestyle Workflow canvas, select text containing a UUID → right-click → Resolve UUID
- A colored toast and a system notification will show the resolved entity details
- The popup shows the last resolved entity

## Entity Types
- Tags — Device tags
- Applications — Internal/Public/Purchased apps
- Profiles — Configuration profiles
- Scripts — Desktop scripts/workflows
- Products — Product provisioning
- Organization Groups — UEM groups

## Privacy and Credentials
- Your credentials and settings are stored locally using Chrome storage (sync/local). They are not included when you zip or share this folder by default.

## FAQ
- Context menu missing: ensure you selected text; reload extension in chrome://extensions
- No toast/notification: check Chrome notification permissions
- OAuth token issues: confirm token URL and client credentials; host permissions may need identity domain if used

## Support
- Open an issue in the repository or contact the maintainer.
