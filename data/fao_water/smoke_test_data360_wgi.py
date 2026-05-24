"""
smoke_test_data360_wgi.py
=========================

Two unresolved questions from the previous probe:

  1. Data360 /data endpoint accepted COUNTRY=MEX but returned LDC records,
     suggesting the filter parameter name is wrong (likely REF_AREA).
  2. World Bank Indicators API claimed GE.EST was "not found"; verify the
     indicator code and country-coverage path is still alive.
"""

from __future__ import annotations

import json
from pprint import pformat

import requests


def banner(s: str) -> None:
    print("\n" + "=" * 70)
    print(s)
    print("=" * 70)


def probe(label: str, url: str, params: dict | None = None,
          show: int = 600) -> requests.Response | None:
    banner(f"{label}\n  URL:    {url}\n  params: {params}")
    try:
        r = requests.get(url, params=params, timeout=30)
    except requests.RequestException as e:
        print(f"  RequestException: {e}")
        return None
    print(f"  HTTP status: {r.status_code}")
    print(f"  Content-Type: {r.headers.get('Content-Type', '?')}")
    print(f"  Length: {len(r.content):,} bytes")
    print(f"  Final URL: {r.url}")
    if show:
        print(f"  Body[:{show}]:\n{r.text[:show]}")
    return r


# ---------------------------------------------------------------------------
# 1. Data360 — try alternative parameter names
# ---------------------------------------------------------------------------

def probe_data360_filters():
    base = "https://data360api.worldbank.org/data360/data"

    # 1a. Try REF_AREA instead of COUNTRY
    probe("1a. Data360 with REF_AREA=MEX",
          base, params={"DATABASE_ID": "FAO_AS", "REF_AREA": "MEX",
                        "skip": 0, "top": 5})

    # 1b. Try INDICATOR + REF_AREA + TIME_PERIOD
    probe("1b. Data360 with INDICATOR + REF_AREA + TIME_PERIOD",
          base, params={"DATABASE_ID": "FAO_AS",
                        "INDICATOR": "FAO_AS_4308",
                        "REF_AREA": "MEX",
                        "TIME_PERIOD": "2015",
                        "skip": 0, "top": 5})

    # 1c. Multi-country, single indicator — what we'd actually want
    probe("1c. Data360 multi-country pull",
          base, params={"DATABASE_ID": "FAO_AS",
                        "INDICATOR": "FAO_AS_4308",
                        "REF_AREA": "MEX,ARG,BRA",
                        "TIME_PERIOD": "2015",
                        "skip": 0, "top": 10})

    # 1d. Get the metadata for a single indicator to confirm the schema and
    # find out the human-readable name + units
    probe("1d. Data360 indicator metadata",
          "https://data360api.worldbank.org/data360/metadata/indicators/FAO_AS_4308",
          show=800)


# ---------------------------------------------------------------------------
# 2. WGI — try alternative URL patterns and the WGI dataset in Data360
# ---------------------------------------------------------------------------

def probe_wgi_alternatives():
    # 2a. Lowercase indicator code
    probe("2a. WB Indicators API with lowercase indicator",
          "https://api.worldbank.org/v2/country/MEX/indicator/ge.est",
          params={"format": "json", "date": "2015"})

    # 2b. v2 with /all/ as country (not single-country path)
    probe("2b. WB Indicators API country=all",
          "https://api.worldbank.org/v2/country/all/indicator/GE.EST",
          params={"format": "json", "date": "2015", "per_page": 5})

    # 2c. Topic-based metadata search to find the correct WGI indicator IDs
    probe("2c. WB sources catalogue (find WGI source ID)",
          "https://api.worldbank.org/v2/sources",
          params={"format": "json", "per_page": 100}, show=1500)

    # 2d. WGI is also a Data360 dataset — try DATABASE_ID=WB_WGI
    probe("2d. Data360 indicators under WB_WGI",
          "https://data360api.worldbank.org/data360/indicators",
          params={"datasetId": "WB_WGI", "skip": 0, "top": 10})

    # 2e. Direct WGI alternative ID — World Governance Indicators landed
    # in DataBank as WB.WGI in some places; try that too
    probe("2e. WB Indicators API with WGI prefixed code",
          "https://api.worldbank.org/v2/country/MEX/indicator/WGI.GE.EST",
          params={"format": "json", "date": "2015"})


def main():
    probe_data360_filters()
    probe_wgi_alternatives()


if __name__ == "__main__":
    main()
