"""
smoke_test_alternatives.py
==========================

The original AQUASTAT API endpoint in download_data.py is dead (404 across
every URL pattern). Probe the three alternatives the README mentions, plus
a couple of programmatic fallbacks worth trying:

    A. data.apps.fao.org/aquastat homepage and any API hints embedded in it
    B. World Bank Data360 mirror of AQUASTAT (FAO_AS)
    C. FAOSTAT bulk-CSV URL pattern used by download_data.py (verify it still
       works, since FAOSTAT's authenticated API now requires a key)
    D. WGI / World Bank Indicators API (the easy win — verify it works)
"""

from __future__ import annotations

import io
import json
import zipfile
from pprint import pformat

import requests


def banner(s: str) -> None:
    print("\n" + "=" * 70)
    print(s)
    print("=" * 70)


def probe(label: str, url: str, params: dict | None = None,
          show_body: int = 400) -> requests.Response | None:
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
    if show_body and len(r.content) < 200_000:
        print(f"  First {show_body} chars of body:\n{r.text[:show_body]}")
    return r


# ---------------------------------------------------------------------------
# A. AQUASTAT homepage — see if it embeds any data-API URL we can reverse out
# ---------------------------------------------------------------------------

def probe_aquastat_homepage():
    r = probe("A. AQUASTAT public homepage",
              "https://data.apps.fao.org/aquastat/", show_body=0)
    if r is None or r.status_code != 200:
        print("  Homepage not reachable.")
        return
    body = r.text
    print(f"  HTML length: {len(body):,}")
    # Look for any hint of an API base URL the SPA calls
    for hint in ("api/", "/data?", "fetch(", "axios.get", "/v1/", "/v2/"):
        idx = body.find(hint)
        if idx != -1:
            window = body[max(0, idx - 60):idx + 120].replace("\n", " ")
            print(f"  Hint '{hint}' found at offset {idx}: ...{window}...")
            break
    # Also try the apps.fao.org API root
    probe("    sub-probe: apps.fao.org/api/",
          "https://data.apps.fao.org/api/", show_body=200)


# ---------------------------------------------------------------------------
# B. World Bank Data360 — programmatic mirror of FAO datasets
# ---------------------------------------------------------------------------

def probe_data360():
    # Data360 catalogue lookup
    probe(
        "B1. Data360 dataset metadata for FAO_AS",
        "https://data360api.worldbank.org/data360/metadata/datasets/FAO_AS",
        show_body=600,
    )
    # Data360 indicators (the actual variable list under FAO_AS)
    probe(
        "B2. Data360 indicators under FAO_AS",
        "https://data360api.worldbank.org/data360/indicators",
        params={"datasetId": "FAO_AS", "skip": 0, "top": 5},
        show_body=600,
    )
    # Data360 actual data pull — irrigated area for one country, one year
    probe(
        "B3. Data360 data pull (sample)",
        "https://data360api.worldbank.org/data360/data",
        params={
            "DATABASE_ID":  "FAO_AS",
            "COUNTRY":      "MEX",
            "TIMEFRAME":    "2015",
            "skip": 0, "top": 5,
        },
        show_body=600,
    )


# ---------------------------------------------------------------------------
# C. FAOSTAT bulk CSV — verify the URL pattern in download_data.py still works
# ---------------------------------------------------------------------------

def probe_faostat_bulk():
    url = "https://bulks-faostat.fao.org/production/Macro-Statistics_Key_Indicators_E_All_Data.zip"
    r = probe("C. FAOSTAT bulk CSV (Macro-Statistics)", url, show_body=0)
    if r is None or r.status_code != 200:
        print("  Bulk endpoint did not respond 200.")
        return
    if "zip" not in r.headers.get("Content-Type", "").lower():
        print(f"  Got {len(r.content):,} bytes but Content-Type is not zip; aborting unzip.")
        return
    try:
        with zipfile.ZipFile(io.BytesIO(r.content)) as zf:
            names = zf.namelist()
            print(f"  ZIP contents ({len(names)} files): {names[:5]}")
            csv_name = next(
                n for n in names
                if n.endswith(".csv") and "Flag" not in n and "Symbol" not in n
            )
            with zf.open(csv_name) as f:
                head = f.read(800).decode("latin-1", errors="replace")
            print(f"  First 800 chars of {csv_name}:\n{head}")
    except Exception as e:
        print(f"  Unzip failed: {e}")


# ---------------------------------------------------------------------------
# D. World Bank Indicators API — sanity-check the easy path
# ---------------------------------------------------------------------------

def probe_wb_indicators():
    probe(
        "D. World Bank Indicators API (WGI: government effectiveness, MEX 2015)",
        "https://api.worldbank.org/v2/country/MEX/indicator/GE.EST",
        params={"format": "json", "date": "2015"},
        show_body=600,
    )


def main():
    probe_aquastat_homepage()
    probe_data360()
    probe_faostat_bulk()
    probe_wb_indicators()


if __name__ == "__main__":
    main()
