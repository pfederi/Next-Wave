#!/usr/bin/env python3
"""
One-time seed: fetch today's water level for every lake the app uses and
write it into the `lake_water_levels` table, so the history chart has a
first data point without waiting for someone to open the app.

Uses the same source, matching, and parsing the app itself uses:
- Next Wave/API/MeteoNewsAPI.swift  (https://vesseldata-api.vercel.app/api/water-temperature)
- Next Wave/Models/Lake.swift       (Lake.parseLevelMeters: split on " ", take first, Double())
- Next Wave/Data/stations.json      (the app's lake list)

Usage: python3 scripts/seed_water_levels.py
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import date, timezone, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
STATIONS_JSON = REPO_ROOT / "Next Wave" / "Data" / "stations.json"

PROXY_URL = "https://vesseldata-api.vercel.app/api/water-temperature"
SUPABASE_URL = "https://nextwaveapp.db.lakeshorestudios.ch"
SUPABASE_ANON_KEY = (
    "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3MzIyMjMwMCwiZXhwIjo0OTI4ODk1OTAwLCJyb2xlIjoiYW5vbiJ9."
    "grHX8Y9WcO08HrvamEgUpfcDvYJmjo6thF3rL9-wD3Y"
)


def http_json(url: str, method: str = "GET", headers: dict | None = None, body: bytes | None = None):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def parse_level_meters(text: str) -> float | None:
    """Mirrors Lake.parseLevelMeters(from:) in Next Wave/Models/Lake.swift."""
    if not text:
        return None
    first = text.split(" ")[0]
    try:
        return float(first)
    except ValueError:
        return None


def app_lake_names() -> list[str]:
    data = json.loads(STATIONS_JSON.read_text(encoding="utf-8"))
    return [lake["name"] for lake in data["lakes"]]


def fetch_current_levels() -> dict[str, str]:
    """Returns {lake_name_lowercase: waterLevel_string}."""
    data = http_json(PROXY_URL)
    return {
        entry["name"].strip().lower(): entry.get("waterLevel") or ""
        for entry in data.get("lakes", [])
    }


def sign_in_anonymously() -> str:
    body = json.dumps({}).encode("utf-8")
    headers = {"apikey": SUPABASE_ANON_KEY, "Content-Type": "application/json"}
    result = http_json(f"{SUPABASE_URL}/auth/v1/signup", method="POST", headers=headers, body=body)
    return result["access_token"]


def upsert_levels(access_token: str, rows: list[dict]) -> None:
    if not rows:
        return
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    body = json.dumps(rows).encode("utf-8")
    url = f"{SUPABASE_URL}/rest/v1/lake_water_levels?on_conflict=lake_name,date"
    req = urllib.request.Request(url, data=body, method="POST", headers=headers)
    with urllib.request.urlopen(req, timeout=20) as resp:
        resp.read()


def main() -> int:
    today = date.today().isoformat()

    print(f"Fetching current levels from {PROXY_URL} ...")
    try:
        proxy_levels = fetch_current_levels()
    except urllib.error.URLError as e:
        print(f"Failed to fetch water levels: {e}", file=sys.stderr)
        return 1

    lakes = app_lake_names()
    print(f"App uses {len(lakes)} lakes.\n")

    rows = []
    skipped = []
    for lake_name in lakes:
        raw = proxy_levels.get(lake_name.strip().lower())
        if raw is None:
            skipped.append((lake_name, "not in proxy response"))
            continue
        level_m = parse_level_meters(raw)
        if level_m is None:
            skipped.append((lake_name, "no numeric level (empty/unparseable)"))
            continue
        rows.append({"lake_name": lake_name, "date": today, "level_m": level_m})
        print(f"  {lake_name:<22} {level_m:>10.3f} m")

    if skipped:
        print("\nSkipped (no usable value today):")
        for name, reason in skipped:
            print(f"  {name:<22} {reason}")

    if not rows:
        print("\nNothing to write.")
        return 0

    print(f"\nSigning in anonymously to {SUPABASE_URL} ...")
    try:
        token = sign_in_anonymously()
        print(f"Writing {len(rows)} row(s) for {today} ...")
        upsert_levels(token, rows)
    except urllib.error.HTTPError as e:
        print(f"Write failed: {e.code} {e.read().decode('utf-8', errors='replace')}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"Write failed: {e}", file=sys.stderr)
        return 1

    print(f"Done. {len(rows)} lake(s) seeded for {today}, {len(skipped)} skipped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
