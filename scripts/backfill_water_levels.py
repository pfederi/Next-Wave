#!/usr/bin/env python3
"""
One-time backfill: pull the last 40 days of real daily water-level history
from the official BAFU GraphQL API (https://data.bafu.admin.ch/api) and
write it into `lake_water_levels`, so the history chart doesn't have to
build up organically from scratch.

Covers 15 of the app's 17 lakes — Greifensee has no active BAFU station
(decommissioned), and Aare is a river, not a lake with a level baseline.
The app's day-to-day live source (MeteoNewsAPI / vesseldata-api proxy) is
untouched; this only backfills history once.

Station numbers were picked by matching `riverName` in the BAFU station
list against each app lake, then sanity-checked against today's live
value from the app's existing proxy (all matched within a millimetre).

Usage: python3 scripts/backfill_water_levels.py [--days 40]
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
from datetime import date, timedelta

BAFU_API = "https://data.bafu.admin.ch/api"
SUPABASE_URL = "https://nextwaveapp.db.lakeshorestudios.ch"
SUPABASE_ANON_KEY = (
    "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3MzIyMjMwMCwiZXhwIjo0OTI4ODk1OTAwLCJyb2xlIjoiYW5vbiJ9."
    "grHX8Y9WcO08HrvamEgUpfcDvYJmjo6thF3rL9-wD3Y"
)

# App lake name -> BAFU station number (parameter "W" = Wasserstand, m ü.M.)
LAKE_STATIONS = {
    "Zürichsee": "2209",
    "Vierwaldstättersee": "2207",
    "Bodensee": "2032",
    "Lac Léman": "2028",
    "Thunersee": "2093",
    "Brienzersee": "2023",
    "Lago Maggiore": "2022",
    "Lago di Lugano": "2101",
    "Bielersee": "2208",
    "Neuenburgersee": "2642",
    "Murtensee": "2004",
    "Zugersee": "2017",
    "Walensee": "2118",
    "Hallwilersee": "2097",
    "Ägerisee": "2031",
    # Greifensee: no active BAFU station (last one, 2082, was decommissioned).
    # Aare: a river, not one of the lakes this feature tracks.
}


def http_json(url: str, method: str = "GET", headers: dict | None = None, body: bytes | None = None):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_history(station_no: str, since: date) -> list[dict]:
    query = (
        "{ water { observations { data_1day_mean("
        f'where:{{station:{{no:{{_eq:"{station_no}"}}}}, parameterName:{{_eq:"W"}}, '
        f'timestamp:{{_gte:"{since.isoformat()}T00:00:00Z"}}}}, limit: 100'
        ") { timestamp value } } } }"
    )
    body = json.dumps({"query": query}).encode("utf-8")
    result = http_json(BAFU_API, method="POST", headers={"Content-Type": "application/json"}, body=body)
    if result.get("errors"):
        raise RuntimeError(f"BAFU API error for station {station_no}: {result['errors']}")
    return result["data"]["water"]["observations"]["data_1day_mean"]


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
    # Batch in chunks to keep individual requests reasonably sized.
    chunk_size = 200
    for i in range(0, len(rows), chunk_size):
        chunk = rows[i : i + chunk_size]
        body = json.dumps(chunk).encode("utf-8")
        url = f"{SUPABASE_URL}/rest/v1/lake_water_levels?on_conflict=lake_name,date"
        req = urllib.request.Request(url, data=body, method="POST", headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp.read()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=40, help="How many days back to backfill (default 40)")
    args = parser.parse_args()

    since = date.today() - timedelta(days=args.days)
    print(f"Backfilling {args.days} days (since {since.isoformat()}) for {len(LAKE_STATIONS)} lakes ...\n")

    all_rows = []
    for lake_name, station_no in LAKE_STATIONS.items():
        try:
            history = fetch_history(station_no, since)
        except (urllib.error.URLError, RuntimeError) as e:
            print(f"  {lake_name:<20} station {station_no}: FAILED — {e}", file=sys.stderr)
            continue

        rows = [
            {"lake_name": lake_name, "date": point["timestamp"][:10], "level_m": point["value"]}
            for point in history
            if point.get("value") is not None
        ]
        all_rows.extend(rows)
        print(f"  {lake_name:<20} station {station_no}: {len(rows)} day(s)")

    if not all_rows:
        print("\nNothing to write.")
        return 0

    print(f"\nSigning in anonymously to {SUPABASE_URL} ...")
    try:
        token = sign_in_anonymously()
        print(f"Writing {len(all_rows)} row(s) total ...")
        upsert_levels(token, all_rows)
    except urllib.error.HTTPError as e:
        print(f"Write failed: {e.code} {e.read().decode('utf-8', errors='replace')}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"Write failed: {e}", file=sys.stderr)
        return 1

    print(f"Done. {len(all_rows)} row(s) written across {len(LAKE_STATIONS)} lakes.")
    print("Note: Greifensee (no active BAFU station) and Aare (river) are not covered.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
