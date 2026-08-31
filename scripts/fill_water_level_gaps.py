#!/usr/bin/env python3
"""
Fills small trailing gaps in `lake_water_levels` (e.g. BAFU's daily-mean
publish lag means "yesterday" often isn't available yet) by carrying the
most recent known value forward into the missing day(s), one row per
missing date, per lake.

These are placeholders, not real readings — since the upsert key is
(lake_name, date), a later real write for the same date (from the app's
own daily fetch, or a re-run of scripts/backfill_water_levels.py once
BAFU has published it) overwrites the placeholder automatically.

Only fills gaps up to --max-gap days (default 3) so a lake with no data
in a long time doesn't get silently padded with a stale value.

Usage: python3 scripts/fill_water_level_gaps.py [--max-gap 3] [--dry-run]
"""

import argparse
import json
import urllib.request
import urllib.error
from datetime import date, timedelta

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


def latest_per_lake() -> dict[str, dict]:
    """Most recent (date, level_m) row per lake, via PostgREST distinct-on ordering."""
    url = (
        f"{SUPABASE_URL}/rest/v1/lake_water_levels"
        "?select=lake_name,date,level_m&order=lake_name.asc,date.desc"
    )
    rows = http_json(url, headers={"apikey": SUPABASE_ANON_KEY})
    latest: dict[str, dict] = {}
    for row in rows:
        # Rows arrive sorted date.desc within each lake_name — first one wins.
        latest.setdefault(row["lake_name"], row)
    return latest


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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-gap", type=int, default=3, help="Largest gap (days) to fill (default 3)")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be written, don't write it")
    args = parser.parse_args()

    today = date.today()
    latest = latest_per_lake()

    rows_to_write = []
    for lake_name, row in latest.items():
        last_date = date.fromisoformat(row["date"])
        gap_days = (today - last_date).days
        if gap_days <= 1:
            continue  # already up to date, nothing to fill
        if gap_days > args.max_gap:
            print(f"  {lake_name:<20} last={row['date']} gap={gap_days}d — skipped (exceeds --max-gap)")
            continue
        for offset in range(1, gap_days):
            fill_date = (last_date + timedelta(days=offset)).isoformat()
            rows_to_write.append({"lake_name": lake_name, "date": fill_date, "level_m": row["level_m"]})
        print(f"  {lake_name:<20} last={row['date']} ({row['level_m']}) — filling {gap_days - 1} day(s)")

    if not rows_to_write:
        print("\nNo gaps to fill.")
        return 0

    if args.dry_run:
        print(f"\nDry run — would write {len(rows_to_write)} placeholder row(s).")
        return 0

    print(f"\nSigning in anonymously to {SUPABASE_URL} ...")
    try:
        token = sign_in_anonymously()
        print(f"Writing {len(rows_to_write)} placeholder row(s) ...")
        upsert_levels(token, rows_to_write)
    except urllib.error.HTTPError as e:
        print(f"Write failed: {e.code} {e.read().decode('utf-8', errors='replace')}")
        return 1
    except urllib.error.URLError as e:
        print(f"Write failed: {e}")
        return 1

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
