"""
probe_indicator_names.py
========================

The Data360 indicator-metadata endpoint is 404. Try other ways to map
AQUASTAT variable codes (e.g. 4193, 4473) to human-readable names:

  1. The Data360 web UI: fetch the indicator landing page HTML and grep
     for the indicator name (typically embedded in the SPA shell).
  2. The legacy AQUASTAT metadata CSV (FAO publishes a flat catalogue of
     all variables with their full names and units).
  3. The data360 /data360/data response itself with extra fields — some
     deployments include a NAME or LABEL field even though the official
     SDMX schema doesn't.
"""

from __future__ import annotations

import re
from pprint import pformat

import requests


CANDIDATES = ["FAO_AS_4193", "FAO_AS_4473", "FAO_AS_4196",
              "FAO_AS_4460", "FAO_AS_4469", "FAO_AS_4192", "FAO_AS_4194"]


def banner(s: str) -> None:
    print("\n" + "=" * 70)
    print(s)
    print("=" * 70)


def probe_data360_landing(indicator: str) -> None:
    """The data360 web UI exposes pages of the form
       https://data360.worldbank.org/en/indicator/<INDICATOR>
       Fetch and grep for the title."""
    url = f"https://data360.worldbank.org/en/indicator/{indicator}"
    try:
        r = requests.get(url, timeout=30)
    except requests.RequestException as e:
        print(f"  {indicator}: request failed: {e}")
        return
    print(f"  {indicator}: HTTP {r.status_code}, {len(r.content):,} B "
          f"({r.headers.get('Content-Type','?')})")
    body = r.text
    # Look for <title>, <meta name="description">, or any ld+json schema
    for pat, label in [
        (r"<title>(.*?)</title>", "title"),
        (r'<meta[^>]+name="description"[^>]+content="([^"]+)"', "meta-desc"),
        (r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"', "og-title"),
        (r'<h1[^>]*>(.*?)</h1>', "h1"),
        (r'"name"\s*:\s*"([^"]+)"', "json-name"),
    ]:
        m = re.search(pat, body, flags=re.IGNORECASE | re.DOTALL)
        if m:
            text = m.group(1).strip()[:200]
            print(f"    {label}: {text}")


def probe_aquastat_catalogue() -> None:
    """The AQUASTAT homepage is an SPA. The variable catalogue is loaded
    from a static JSON file under data.apps.fao.org/aquastat/. Try a few
    plausible URLs."""
    candidates = [
        "https://data.apps.fao.org/aquastat/data/variables.json",
        "https://data.apps.fao.org/aquastat/api/variables",
        "https://data.apps.fao.org/aquastat/api/variables.json",
        "https://data.apps.fao.org/aquastat/static/variables.json",
        "https://data.apps.fao.org/aquastat/assets/variables.json",
        "https://data.apps.fao.org/aquastat/public/data/variables.json",
        "https://data.apps.fao.org/aquastat/dist/variables.json",
        "https://data.apps.fao.org/static/aquastat/variables.json",
    ]
    for url in candidates:
        try:
            r = requests.get(url, timeout=15)
            print(f"  {url[-50:]:<50}  {r.status_code}  "
                  f"{r.headers.get('Content-Type','?')[:30]:<30}  "
                  f"{len(r.content):>8,} B")
        except requests.RequestException:
            print(f"  {url}  -> error")


def fetch_aquastat_homepage_assets() -> None:
    """Look at the AQUASTAT homepage HTML for embedded asset URLs (likely
    JS bundles); grep one for the variable list."""
    r = requests.get("https://data.apps.fao.org/aquastat/", timeout=15)
    print(f"  Homepage: {r.status_code}, {len(r.content):,} B")
    body = r.text
    # Pull all script src and link href hrefs
    srcs = re.findall(r'<script[^>]+src="([^"]+)"', body)
    hrefs = re.findall(r'<link[^>]+href="([^"]+\.(?:js|json))"', body)
    print(f"  Scripts: {srcs}")
    print(f"  Asset hrefs: {hrefs}")


def probe_data360_data_with_extras(indicator: str) -> None:
    """The /data endpoint returned a record with COMMENT_OBS, COMMENT_TS,
    DATA_SOURCE etc. Also try requesting a smaller record with select
    fields to see if there's a NAME / LABEL field hiding."""
    url = "https://data360api.worldbank.org/data360/data"
    r = requests.get(url, params={"DATABASE_ID": "FAO_AS",
                                  "INDICATOR": indicator,
                                  "skip": 0, "top": 1},
                     timeout=30)
    if r.status_code == 200 and r.headers.get("Content-Type", "").startswith("application/json"):
        rec = r.json().get("value", [None])[0]
        if rec:
            print(f"  {indicator} sample record keys: {list(rec.keys())}")
            # Pretty-print only the candidate name-bearing keys
            for k in ("NAME", "LABEL", "TITLE", "INDICATOR_NAME",
                      "COMMENT_TS", "COMMENT_OBS"):
                if k in rec and rec[k]:
                    print(f"    {k}: {str(rec[k])[:120]}")


def main():
    banner("1. Data360 web UI per indicator")
    for ind in CANDIDATES:
        probe_data360_landing(ind)

    banner("2. AQUASTAT static catalogue probes")
    probe_aquastat_catalogue()

    banner("3. AQUASTAT homepage assets")
    fetch_aquastat_homepage_assets()

    banner("4. Data360 /data record extra fields per candidate")
    for ind in CANDIDATES[:3]:
        probe_data360_data_with_extras(ind)


if __name__ == "__main__":
    main()
