#!/usr/bin/env python3
"""
Matt Zaske (mzaske@omnissa.com) | 2026-03-19

ws1_update_supportedModels.py
----------------------------------
Add a supported model (e.g. "MacBook Neo") to macOS internal apps in Workspace ONE UEM.

Modes:
  dry-run  – list which apps would be changed, no writes
  update   – perform the PUT updates

Usage example:
  python3 ws1_update_supportedModels.py \
      --base-url https://as1784.awmdm.com \
      --client-id <id> --client-secret <secret> \
      --token-url https://na.uemauth.workspaceone.com/connect/token \
      --mode update \
      --app-name-filter zoom \
      --log-file ~/Downloads/update_models.log

"""

import argparse
import json
import logging
import os
import re
import sys
from copy import deepcopy
from logging.handlers import RotatingFileHandler
from typing import Any, Dict, List, Optional

import requests
from requests.auth import HTTPBasicAuth

# ─────────────────────────────── constants ──────────────────────────────────

MACOS_PLATFORM_INT    = 10       # DeviceType.AppleOsX
_TOKEN_URL_DEFAULT    = "https://na.uemauth.vmwservices.com/connect/token"

# Known ModelId values for models being added.
# GET /api/mam/apps/internal/{id} returns items with a lowercase "id" field for
# existing models; new models that don't yet exist in WS1 need their ID here.
MODEL_ID_MAP: Dict[str, int] = {
    "MacBook Neo": 121,
}

LIST_ENDPOINT   = "/API/mam/apps/search"
DETAIL_ENDPOINT = "/API/mam/apps/internal/{id}"

# Fields that must be removed before PUT.
ALWAYS_STRIP = {
    "Assignments",
    "ExcludedSmartGroupIds",
    "ExcludedSmartGroupGuids",
}

# ────────────────────────────── logging ─────────────────────────────────────

logger = logging.getLogger("ws1-updater")


def setup_logging(log_file: Optional[str], level: str = "INFO",
                  max_bytes: int = 5 * 1024 * 1024, backup_count: int = 5) -> None:
    lvl = getattr(logging, level.upper(), logging.INFO)
    logger.setLevel(lvl)
    fmt = logging.Formatter("%(asctime)s %(levelname)s: %(message)s")

    ch = logging.StreamHandler()
    ch.setLevel(lvl)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    if log_file:
        log_file = os.path.expanduser(log_file)
        fh = RotatingFileHandler(log_file, maxBytes=max_bytes, backupCount=backup_count)
        fh.setLevel(lvl)
        fh.setFormatter(fmt)
        logger.addHandler(fh)


# ────────────────────────── token helpers ───────────────────────────────────

def fetch_oauth_token(token_url: str, client_id: str, client_secret: str,
                      scope: Optional[str] = None) -> Optional[str]:
    logger.info("Requesting OAuth2 token from %s", token_url)
    data: Dict[str, str] = {"grant_type": "client_credentials"}
    if scope:
        data["scope"] = scope
    try:
        r = requests.post(token_url, data=data,
                          auth=HTTPBasicAuth(client_id, client_secret),
                          headers={"Accept": "application/json"}, timeout=30)
    except Exception as exc:
        logger.error("Token request network error: %s", exc)
        return None
    if r.status_code not in (200, 201):
        logger.error("Token endpoint returned %s: %s", r.status_code, r.text[:400])
        return None
    try:
        tok = r.json().get("access_token") or r.json().get("token")
    except Exception:
        logger.error("Token response is not JSON")
        return None
    if not tok:
        logger.error("No access_token found in token response")
    return tok


# ─────────────────────────── app-list helpers ───────────────────────────────

def find_list_in_response(data: Any) -> List[Dict[str, Any]]:
    """Unwrap common WS1 list-response wrappers into a plain list."""
    if isinstance(data, list):
        return data
    if not isinstance(data, dict):
        return []
    for key in ("Application", "Results", "result", "Applications",
                "ApplicationList", "response", "items", "Items", "Apps"):
        if key in data and isinstance(data[key], list):
            return data[key]
    for v in data.values():
        if isinstance(v, list):
            return v
    return []


def extract_app_id(raw: Any) -> Optional[int]:
    """Return a numeric app-id from whatever shape WS1 returns it."""
    if raw is None:
        return None
    if isinstance(raw, int):
        return raw
    if isinstance(raw, str):
        m = re.search(r"(\d+)", raw.strip())
        return int(m.group(1)) if m else None
    if isinstance(raw, dict):
        for k in ("Value", "value", "Id", "id", "ApplicationId", "ID"):
            if k in raw:
                v = extract_app_id(raw[k])
                if v is not None:
                    return v
    return None


def app_name(app: Dict[str, Any]) -> str:
    return (app.get("ApplicationName") or app.get("Name") or
            app.get("DisplayName") or app.get("appName") or "")


# ───────────────────── SupportedModels: GET → PUT conversion ────────────────

def _extract_model_name(item: Any) -> Optional[str]:
    """Return a non-empty model name from a GET-era or PUT-era item.

    GET (InternalAppModel)  items have: {"Name": "MacBook Pro"}
    PUT (ApplicationEntity) items have: {"ModelId": 1, "ModelName": "MacBook Pro"}
    Both forms are handled so the function works on any cached/round-tripped data.
    """
    if isinstance(item, str):
        return item.strip() or None
    if isinstance(item, dict):
        name = item.get("ModelName") or item.get("Name") or ""
        return name.strip() or None
    return None


def _collect_models(val: Any, result: Dict[str, int]) -> None:
    """Recursively populate {ModelName: ModelId} from any input shape."""
    if val is None:
        return
    if isinstance(val, list):
        for item in val:
            _collect_models(item, result)
    elif isinstance(val, dict):
        inner = val.get("Model") or val.get("Models")
        if isinstance(inner, list):
            _collect_models(inner, result)
        else:
            name = _extract_model_name(val)
            # GET items use lowercase "id"; PUT items use "ModelId"
            mid  = val.get("ModelId") or val.get("id") or 0
            if name:  # skip empty/null names
                result[name] = mid
    elif isinstance(val, str):
        try:
            _collect_models(json.loads(val), result)
        except Exception:
            name = val.strip()
            if name:
                result[name] = 0


def current_model_names(raw_sm: Any) -> set:
    """Return the set of non-empty model names already stored in SupportedModels."""
    existing: Dict[str, int] = {}
    _collect_models(raw_sm, existing)
    return set(existing.keys())


def build_supported_models_object(raw_sm: Any,
                                   models_to_add: List[str],
                                   app_id: int) -> Dict[str, Any]:
    """Convert GET SupportedModels to the ApplicationSupportedModels object PUT expects.

    GET shape:  [{"Name":"MacBook Pro"}, {"Name":"MacBook Air"}]   ← InternalAppModel
    PUT shape:  {"Model":[{"ModelId":0,"ModelName":"MacBook Pro","ApplicationId":6906},
                           {"ModelId":0,"ModelName":"MacBook Air","ApplicationId":6906},
                           {"ModelId":0,"ModelName":"MacBook Neo","ApplicationId":6906}]}

    Rules:
      - Empty / null names are discarded.
      - Existing entries are preserved; duplicates are not added.
      - models_to_add entries are appended if not already present.
    """
    existing: Dict[str, int] = {}   # ModelName → ModelId
    _collect_models(raw_sm, existing)

    for nm in models_to_add:
        if nm and nm not in existing:
            existing[nm] = MODEL_ID_MAP.get(nm, 0)

    return {
        "Model": [
            {"ModelId": mid, "ModelName": nm, "ApplicationId": app_id}
            for nm, mid in existing.items()
        ]
    }


def build_category_list_object(raw_cl: Any) -> Optional[Dict[str, Any]]:
    """Convert GET CategoryList to the ApplicationCategories object PUT expects.

    GET shape:  [{"Name": "Productivity", "id": 5}, ...]  ← ApplicationCategoriesModel
    PUT shape:  {"Category": [{"CategoryId": 5, "Name": "Productivity"}, ...]}

    Returns None if there are no categories (leaves the field absent rather than
    sending an empty object, which could clear server-side categories).
    """
    if not raw_cl:
        return None
    categories = []
    items = raw_cl
    if isinstance(raw_cl, dict):
        # already PUT-shaped: {"Category": [...]}
        items = raw_cl.get("Category") or []
    if isinstance(items, list):
        for item in items:
            if isinstance(item, dict):
                name = item.get("Name") or ""
                cid  = item.get("CategoryId") or item.get("id") or 0
                if name:
                    categories.append({"CategoryId": cid, "Name": name})
    return {"Category": categories} if categories else None


def sanitize_put_payload(full_get_obj: Dict[str, Any],
                         app_id: int,
                         models_to_add: List[str]) -> Dict[str, Any]:
    """Return a PUT-ready body built from the full GET response.

    1. Platform       → integer 10 (AppleOsX)
    2. SupportedModels → {"Model":[{"ModelId","ModelName","ApplicationId"}]}
                         GET [{"Name":"…"}] array → PUT object; empty names filtered
    3. CategoryList   → converted GET [{Name, id}] → PUT {Category:[{CategoryId, Name}]}
    4. ALWAYS_STRIP   → Assignments, ExcludedSmartGroup* removed
    5. root "id"      → removed (plain int; ApplicationEntity.id is EntityId)
    """
    result = deepcopy(full_get_obj)

    # 1. Platform
    result["Platform"] = MACOS_PLATFORM_INT

    # 2. SupportedModels → correct object shape
    result["SupportedModels"] = build_supported_models_object(
        result.get("SupportedModels"), models_to_add, app_id
    )

    # 3. CategoryList → convert GET array to PUT object shape, preserving categories
    raw_cl = result.get("CategoryList")
    converted_cl = build_category_list_object(raw_cl)
    if converted_cl is not None:
        result["CategoryList"] = converted_cl
        logger.debug("CategoryList preserved: %s categories", len(converted_cl["Category"]))
    elif "CategoryList" in result:
        del result["CategoryList"]

    # 4. Remove fields that cannot be round-tripped safely
    ALWAYS_STRIP_WITH_ID = ALWAYS_STRIP | {"id"}
    for field in ALWAYS_STRIP_WITH_ID:
        if field in result:
            logger.debug("Removing field '%s' from PUT payload", field)
            del result[field]

    return result


# ───────────────────────────── main logic ───────────────────────────────────

def build_headers(token: str) -> Dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept":        "application/json",
        "Content-Type":  "application/json",
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Update SupportedModels for macOS internal apps in Workspace ONE UEM v2"
    )
    # Connection
    parser.add_argument("--base-url",      default=os.getenv("WS1_BASE_URL"))
    parser.add_argument("--token",         default=os.getenv("WS1_BEARER_TOKEN"),
                        help="Bearer token (skips OAuth2 flow)")
    parser.add_argument("--client-id",     default=os.getenv("WS1_CLIENT_ID"))
    parser.add_argument("--client-secret", default=os.getenv("WS1_CLIENT_SECRET"))
    parser.add_argument("--token-url",     default=os.getenv("WS1_TOKEN_URL"),
                        help="OAuth2 token URL. Auto-derived if omitted.")
    # What to add
    parser.add_argument("--models",  default="MacBook Neo",
                        help="Comma-separated model names to add (default: 'MacBook Neo')")

    # Filters
    parser.add_argument("--app-name-filter", default=None,
                        help="Case-insensitive substring filter on app name")
    parser.add_argument("--status-filter", default=None,
                        help="Filter by app Status value (e.g. Active)")

    # Mode
    parser.add_argument("--mode", choices=["dry-run", "update"], default="dry-run",
                        help="dry-run: show changes only | update: apply changes (default: dry-run)")

    # Logging
    parser.add_argument("--log-file",   default=None)
    parser.add_argument("--log-level",  default="INFO",
                        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"])

    # Advanced
    parser.add_argument("--page-size",  type=int, default=500)

    args = parser.parse_args()

    setup_logging(args.log_file, args.log_level)

    # ── Validate required args ────────────────────────────────────────────
    if not args.base_url:
        logger.error("--base-url is required (or set WS1_BASE_URL)")
        sys.exit(1)

    # ── Resolve bearer token ──────────────────────────────────────────────
    token = args.token
    if not token:
        if not (args.client_id and args.client_secret):
            logger.error("Provide --token or both --client-id and --client-secret")
            sys.exit(1)
        token_url = args.token_url or _TOKEN_URL_DEFAULT
        token = fetch_oauth_token(token_url, args.client_id, args.client_secret)
        if not token:
            logger.error("Could not obtain bearer token — aborting")
            sys.exit(1)

    headers  = build_headers(token)
    base     = args.base_url.rstrip("/")
    is_update = (args.mode == "update")
    models_to_add = [m.strip() for m in args.models.split(",") if m.strip()]

    logger.info("Mode: %s | Models to add: %s", args.mode, models_to_add)

    # ── Fetch app list ────────────────────────────────────────────────────
    list_url = f"{base}{LIST_ENDPOINT}"
    params   = {
        "applicationtype": "Internal",
        "Platform":        "AppleOsX",
        "pageSize":        args.page_size,
    }
    if args.app_name_filter:
        params["applicationname"] = args.app_name_filter
    if args.status_filter:
        params["status"] = args.status_filter

    logger.info("Fetching app list from %s (params=%s)", list_url, params)
    try:
        resp = requests.get(list_url, headers=headers, params=params, timeout=60)
    except Exception as exc:
        logger.error("App-list request failed: %s", exc)
        sys.exit(1)

    if resp.status_code != 200:
        logger.error("App-list request returned %s: %s", resp.status_code, resp.text[:600])
        sys.exit(1)

    try:
        list_data = resp.json()
    except Exception:
        logger.error("App-list response is not valid JSON")
        sys.exit(1)

    apps = find_list_in_response(list_data)
    total = list_data.get("TotalCount") or list_data.get("Total") or len(apps)
    logger.info("App list: %d returned (TotalCount in API=%s)", len(apps), total)

    if not apps:
        logger.warning("No apps found — check filters / list endpoint")
        sys.exit(0)

    # ── Process each app ──────────────────────────────────────────────────
    updated_count = 0
    skipped_count = 0
    error_count   = 0

    for app in apps:
        name   = app_name(app)
        raw_id = (app.get("Id") or app.get("ApplicationId") or
                  app.get("id") or app.get("ID"))
        app_id = extract_app_id(raw_id)

        if not app_id:
            logger.warning("Skipping app with no resolvable id: %r", name)
            skipped_count += 1
            continue

        # ── GET full detail object ────────────────────────────────────────
        detail_url = f"{base}{DETAIL_ENDPOINT.format(id=app_id)}"
        try:
            r_get = requests.get(detail_url, headers=headers, timeout=30)
        except Exception as exc:
            logger.error("GET %s failed: %s", detail_url, exc)
            error_count += 1
            continue

        if r_get.status_code != 200:
            logger.error("GET detail for id=%s returned %s: %s",
                         app_id, r_get.status_code, r_get.text[:400])
            error_count += 1
            continue

        try:
            full_obj = r_get.json()
        except Exception:
            logger.error("Detail response for id=%s is not JSON", app_id)
            error_count += 1
            continue

        logger.debug("GET id=%s SupportedModels (raw): %s",
                     app_id, json.dumps(full_obj.get("SupportedModels")))

        # ── Check what is already present ─────────────────────────────────
        current = current_model_names(full_obj.get("SupportedModels"))
        missing = [m for m in models_to_add if m not in current]

        if not missing:
            logger.info("SKIP  id=%-6s %-50s  — all models already present", app_id, f"'{name}'")
            skipped_count += 1
            continue

        logger.info("%-7s id=%-6s %-50s  — adding: %s",
                    "WOULD" if not is_update else "UPDATE",
                    app_id, f"'{name}'", missing)

        # ── Build sanitized PUT payload ───────────────────────────────────
        put_body = sanitize_put_payload(
            full_get_obj=full_obj,
            app_id=app_id,
            models_to_add=models_to_add,
        )

        logger.debug("PUT id=%s SupportedModels (to send):\n%s",
                     app_id, json.dumps(put_body.get("SupportedModels"), indent=2))

        if not is_update:
            logger.info("(dry-run) PUT would be sent to %s", detail_url)
            continue

        # ── PUT ───────────────────────────────────────────────────────────
        try:
            r_put = requests.put(detail_url, headers=headers,
                                 json=put_body, timeout=60)
        except Exception as exc:
            logger.error("PUT %s failed: %s", detail_url, exc)
            error_count += 1
            continue

        if 200 <= r_put.status_code < 300:
            logger.info("OK    id=%-6s '%s'", app_id, name)
            updated_count += 1
        else:
            logger.error("FAIL  id=%-6s '%s'  %s: %s",
                         app_id, name, r_put.status_code, r_put.text[:600])
            error_count += 1

    # ── Summary ───────────────────────────────────────────────────────────
    logger.info("─" * 60)
    logger.info("Done.  mode=%s | updated=%d | skipped=%d | errors=%d",
                args.mode, updated_count, skipped_count, error_count)


if __name__ == "__main__":
    main()
