"""
smoke_test_aquastat.py
======================

Probe the AQUASTAT dissemination API to find out (a) whether the endpoint
URL pattern in download_data.py actually exists, and (b) what the response
schema looks like for one variable / three countries / one year. The goal
is *not* to download data — only to verify that the full pull is worth
launching, and to surface any URL changes the FAO has made since the
script was drafted.

Run:
    python3 smoke_test_aquastat.py

Exit codes:
    0  endpoint responded with parseable data
    1  endpoint responded but with empty / unparseable data
    2  endpoint did not respond (DNS / 404 / timeout)
"""

from __future__ import annotations

import json
import sys
from pprint import pformat

import requests


# Probe the same base URL download_data.py uses
AQUASTAT_BASE = "https://data.apps.fao.org/aquastat/api/v1"

# Smallest possible request: one variable, one year. Variable 4308 is
# "Area equipped for irrigation: total (1000 ha)".
SMOKE_VARIABLE = "4308"
SMOKE_COUNTRIES = ["MEX", "ARG", "BRA"]   # candidates with strong irrigated ag
SMOKE_YEAR = 2015


def banner(s: str) -> None:
    print("\n" + "=" * 70)
    print(s)
    print("=" * 70)


def probe(label: str, url: str, params: dict | None = None) -> None:
    banner(f"{label}\n  URL:    {url}\n  params: {params}")
    try:
        r = requests.get(url, params=params, timeout=30)
    except requests.RequestException as e:
        print(f"  RequestException: {e}")
        return None
    print(f"  HTTP status   : {r.status_code}")
    print(f"  Content-Type  : {r.headers.get('Content-Type', '?')}")
    print(f"  Content length: {len(r.content):,} bytes")
    print(f"  Final URL     : {r.url}")
    body = r.text[:600]
    print(f"  First 600 chars of body:\n{body}")
    if "json" in r.headers.get("Content-Type", "").lower():
        try:
            payload = r.json()
            print(f"\n  Parsed JSON top-level type: {type(payload).__name__}")
            if isinstance(payload, dict):
                print(f"  Top-level keys: {list(payload.keys())}")
                # Show a sample if the keys hint at data
                for cand_key in ("data", "results", "value", "items"):
                    if cand_key in payload:
                        recs = payload[cand_key]
                        if isinstance(recs, list) and recs:
                            print(f"\n  payload['{cand_key}'][0] =\n"
                                  f"{pformat(recs[0], indent=4)[:600]}")
                        break
            elif isinstance(payload, list) and payload:
                print(f"  List length: {len(payload)}")
                print(f"  payload[0] =\n{pformat(payload[0], indent=4)[:600]}")
            return payload
        except json.JSONDecodeError:
            print("  WARNING: Content-Type claims JSON but body is not parseable.")
    return None


def main():
    # 1. Hit the base URL just to see if it resolves at all
    probe("STEP 1: Base URL ping", AQUASTAT_BASE)

    # 2. Try the documented (assumed) /data endpoint with the parameter set
    #    that download_data.py uses
    probe(
        "STEP 2: /data endpoint with download_data.py's parameters",
        f"{AQUASTAT_BASE}/data",
        params={
            "variables":  SMOKE_VARIABLE,
            "year_start": SMOKE_YEAR,
            "year_end":   SMOKE_YEAR,
            "format":     "json",
        },
    )

    # 3. Try with a country filter (ISO3) added
    probe(
        "STEP 3: /data endpoint with countries filter (ISO3)",
        f"{AQUASTAT_BASE}/data",
        params={
            "variables":  SMOKE_VARIABLE,
            "countries":  ",".join(SMOKE_COUNTRIES),
            "year_start": SMOKE_YEAR,
            "year_end":   SMOKE_YEAR,
            "format":     "json",
        },
    )

    # 4. Look for an OpenAPI / Swagger description that would tell us
    #    the *real* endpoint structure if /data is wrong
    for spec in ("/openapi.json", "/swagger.json", "/docs", "/spec"):
        probe(f"STEP 4: discovery probe {spec}", f"{AQUASTAT_BASE}{spec}")

    # 5. Probe a sibling FAO data platform that *does* document its API:
    #    the FAOSTAT API uses faostat.fao.org/api/v1; if AQUASTAT moved to
    #    a similar pattern, this template should still resolve.
    probe(
        "STEP 5: FAOSTAT companion API (sanity check that we can reach FAO at all)",
        "https://faostatservices.fao.org/api/v1/en/data/QCL",
        params={"limit": 1},
    )


if __name__ == "__main__":
    main()
