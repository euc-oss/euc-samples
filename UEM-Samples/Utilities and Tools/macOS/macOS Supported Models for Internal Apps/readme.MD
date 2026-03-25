# Update macOS Supported Models

Developed by: Matt Zaske (mzaske@omnissa.com) | 2026-03-19

Purpose
-------
<!-- Summary Start -->
Small helper script to add one or more supported macOS device models (default: `MacBook Neo`) to Workspace ONE UEM internal macOS applications.
<!-- Summary End -->

Requirements
------------
- Python 3
- `requests` package (`pip install requests`)

Usage examples
--------------
Dry-run (preview only):

```bash
python3 /path/to/ws1_update_supported_models.py \
  --base-url 'https://your-tenant.awmdm.com' \
  --client-id '<id>' --client-secret '<secret>' \
  --mode dry-run --app-name-filter zoom --log-file ~/Documents/ws1models_dryrun.log
```

Update (apply changes):

```bash
python3 /path/to/ws1_update_supported_models.py \
  --base-url 'https://your-tenant.awmdm.com' \
  --token '<bearer-token>' --mode update
```

Parameters / Flags
------------------
| Flag Name | Required | Default | Type | Notes |
|---|---:|---|---|---|
| `--base-url` | Y  | None | string (URL) | WS1 API base URL, e.g. `https://as1234.awmdm.com` |
| `--token` | N (either this OR `--client-id`+`--client-secret`) | None | string | Bearer token; if provided, OAuth flow is skipped |
| `--client-id` | Y (if `--token` provided then N) | None | string | Generated in WS1 OAuth  |
| `--client-secret` | Y (if `--token` provided then N) | None | string | Used with `--client-id` for client_credentials flow |
| `--token-url` | N | https://na.uemauth.vmwservices.com/connect/token | string (URL) | Override token endpoint if needed; otherwise default is used |
| `--models` | N | `MacBook Neo` | string (comma-separated) | One or more model names to add; e.g. `"MacBook Neo,MacBook Pro"` |
| `--app-name-filter` | N | None | string | Case-insensitive substring to filter app list by name |
| `--status-filter` | N | None | string | Filter by app status (e.g. `Active`) |
| `--mode` | N | `dry-run` | enum `{dry-run, update}` | `dry-run` previews changes; `update` performs changes |
| `--log-file` | N | None | string (path) | Path to write rotating log file; default logs to stdout only |
| `--log-level` | N | `INFO` | enum `{DEBUG, INFO, WARNING, ERROR, CRITICAL}` | Controls verbosity |
| `--page-size` | N | `500` | integer | Page size for the search/list API call |

Environment variables
---------------------
The script also accepts these env vars as alternatives to CLI args:
- `WS1_BASE_URL`
- `WS1_BEARER_TOKEN`
- `WS1_CLIENT_ID`
- `WS1_CLIENT_SECRET`
- `WS1_TOKEN_URL`

Logging
---------------
- By default the script logs to the console. Use `--log-file /path/to/log` to enable rotating file logging.

Notes & safety
---------------
- The script defaults to adding `MacBook Neo` if `--models` is omitted.
- Always run with `--dry-run` first against your tenant to confirm results.
- If you provide both `--token` and client credentials, the explicit `--token` is used.
