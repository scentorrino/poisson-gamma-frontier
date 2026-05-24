"""
probe_count_indicators.py
=========================

Search the AQUASTAT (FAO_AS) catalogue exposed via World Bank Data360 for
indicators that look like genuine integer counts — i.e. unit = "number"
or "count" or "head" — rather than continuous quantities like ha, m^3,
mm, %, etc.

The motivation: the count-data Poisson SFM framework needs an integer-
valued outcome. "Area equipped for irrigation (1000 ha)" is continuous,
not a count. We want to know whether AQUASTAT exposes any genuine count
variables (number of dams, number of reservoirs, number of irrigation
schemes, ...).

Output: a CSV file `fao_as_indicators.csv` with one row per indicator,
columns (indicator_id, name, unit, description) where available.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path
from typing import Optional

import requests


OUT_DIR = Path(__file__).resolve().parent
SLEEP = 0.3


def fetch_indicator_list(database_id: str) -> list[str]:
    """Pull the full indicator-ID list under a Data360 dataset."""
    print(f"\nFetching indicator list for {database_id}...")
    url = "https://data360api.worldbank.org/data360/indicators"
    out = []
    skip = 0
    page = 200
    while True:
        r = requests.get(url, params={"datasetId": database_id,
                                       "skip": skip, "top": page},
                         timeout=30)
        r.raise_for_status()
        chunk = r.json()
        if not isinstance(chunk, list):
            print(f"  Unexpected payload type {type(chunk)}; stopping.")
            break
        if not chunk:
            break
        out.extend(chunk)
        if len(chunk) < page:
            break
        skip += page
    print(f"  Got {len(out)} indicator IDs.")
    return out


def fetch_one_observation(indicator: str, ref_area: str = "USA",
                           year: int = 2010) -> Optional[dict]:
    """Fetch one observation to read the indicator's unit/multiplier from a
    real record. Indicator-metadata endpoint is 404, so we extract metadata
    from the data records themselves.
    """
    url = "https://data360api.worldbank.org/data360/data"
    try:
        r = requests.get(url, params={"DATABASE_ID": "FAO_AS",
                                       "INDICATOR": indicator,
                                       "REF_AREA": ref_area,
                                       "TIME_PERIOD": str(year),
                                       "skip": 0, "top": 1},
                         timeout=30)
        r.raise_for_status()
    except requests.RequestException:
        return None
    payload = r.json()
    if not isinstance(payload, dict) or not payload.get("value"):
        # Fallback to any country if USA 2010 is absent
        try:
            r = requests.get(url, params={"DATABASE_ID": "FAO_AS",
                                           "INDICATOR": indicator,
                                           "skip": 0, "top": 1},
                             timeout=30)
            r.raise_for_status()
            payload = r.json()
        except requests.RequestException:
            return None
    if isinstance(payload, dict) and payload.get("value"):
        return payload["value"][0]
    return None


def fetch_descriptive_search() -> dict[str, dict]:
    """Try the Data360 generic search endpoint to find indicator names.
    Some Data360 deployments expose a /search endpoint that returns names
    and descriptions; try a few likely shapes.
    """
    out = {}
    candidate_urls = [
        ("https://data360api.worldbank.org/data360/search",
         {"q": "FAO_AS", "skip": 0, "top": 200}),
        ("https://data360api.worldbank.org/data360/indicator-metadata",
         {"datasetId": "FAO_AS"}),
        ("https://data360.worldbank.org/api/data360/indicators",
         {"datasetId": "FAO_AS", "skip": 0, "top": 5}),
    ]
    for url, params in candidate_urls:
        print(f"  Discovery probe: {url}  params={params}")
        try:
            r = requests.get(url, params=params, timeout=30)
            print(f"    {r.status_code}  {r.headers.get('Content-Type','?')}"
                  f"  {len(r.content):,} B")
            if r.status_code == 200 and "json" in r.headers.get("Content-Type", ""):
                data = r.json()
                # If we get something useful, extract
                if isinstance(data, list) and data and isinstance(data[0], dict):
                    print(f"    First record keys: {list(data[0].keys())[:10]}")
                    # Heuristically pull (id, name) pairs
                    for rec in data:
                        idkey = next((k for k in ("id", "indicatorId",
                                                    "indicator_id", "code")
                                        if k in rec), None)
                        nmkey = next((k for k in ("name", "label",
                                                    "title", "description")
                                        if k in rec), None)
                        if idkey:
                            out[rec[idkey]] = {
                                "name": rec.get(nmkey, "") if nmkey else "",
                                "raw": rec,
                            }
                    if out:
                        return out
                elif isinstance(data, dict) and "value" in data:
                    print(f"    Dict.value keys: "
                          f"{list(data['value'][0].keys())[:10] if data.get('value') else []}")
        except (requests.RequestException, json.JSONDecodeError) as e:
            print(f"    {type(e).__name__}: {e}")
    return out


# AQUASTAT canonical names per indicator code, transcribed from the
# AQUASTAT manual (https://www.fao.org/aquastat/en/databases/maindatabase).
# Used as a fallback when the Data360 search endpoint doesn't return names.
# Only the codes most relevant to count outcomes are listed; the rest fall
# through with no name.
AQUASTAT_NAME_HINTS = {
    # Water resources
    "4100": "Long-term average annual precipitation in volume",
    "4103": "Long-term average annual precipitation in depth",
    "4150": "Total internal renewable surface water resources",
    "4157": "Total internal renewable water resources",
    "4188": "Total renewable water resources",
    "4194": "Total dam capacity",
    # Dams and infrastructure — these are the candidates we're hunting for
    "4192": "Number of large dams",
    "4193": "Number of small dams",
    "4197": "Total dam capacity per capita",
    # Irrigation
    "4308": "Area equipped for irrigation: total",
    "4309": "Area equipped for irrigation: surface irrigation",
    "4310": "Area equipped for irrigation: sprinkler irrigation",
    "4311": "Area actually irrigated",
    "4313": "Area equipped for irrigation: localized irrigation",
    "4314": "Area equipped for irrigation: spate irrigation",
    "4315": "Area equipped for full control irrigation: surface water",
    "4316": "Area equipped for full control irrigation: groundwater",
    "4451": "Number of agricultural water users (not standard)",
    # Water use
    "4250": "Agricultural water withdrawal",
    "4253": "Agricultural water withdrawal as % of total",
    "4263": "Total water withdrawal",
    # SDG
    "4550": "SDG 6.4.2 Level of water stress",
    "4551": "SDG 6.4.1 Water-use efficiency",
}


def main():
    # 1. Pull the full FAO_AS indicator ID catalogue
    ids = fetch_indicator_list("FAO_AS")
    if not ids:
        print("Could not pull indicator list; aborting.")
        sys.exit(2)

    # 2. Try to find a search endpoint that gives names; if not, we'll
    #    annotate from AQUASTAT_NAME_HINTS only
    print("\nProbing Data360 metadata / search endpoints for names...")
    names_map = fetch_descriptive_search()
    if names_map:
        print(f"  Got names for {len(names_map)} indicators via search.")
    else:
        print("  No search endpoint returned usable names; using static hints + sampling.")

    # 3. For the indicators we have name hints for, sample one observation
    #    each to capture UNIT_MULT and OBS_VALUE (helps spot integer-valued
    #    series). Skip the ones we have no hint for if there are too many.
    print("\nSampling one observation per hinted indicator to read units...")
    rows = []
    code_pat = re.compile(r"FAO_AS_(\d+)")

    for ind_id in ids:
        m = code_pat.match(ind_id)
        bare = m.group(1) if m else ind_id
        hint = AQUASTAT_NAME_HINTS.get(bare, "")
        # Sample if we have a name hint OR if the bare code is in a small
        # neighborhood of "dam"/"reservoir"/"facility"-type indicators
        # (the AQUASTAT manual codes 4190-4199 cover dams/infrastructure).
        try_sample = bool(hint) or bare.startswith(("419", "445",
                                                       "446", "447"))
        rec = fetch_one_observation(ind_id) if try_sample else None

        unit_mult = None
        obs_value = None
        is_integer = None
        if rec:
            unit_mult = rec.get("UNIT_MULT")
            obs_value = rec.get("OBS_VALUE")
            try:
                v = float(obs_value)
                is_integer = (v == int(v)) if v == v else None
            except (TypeError, ValueError):
                is_integer = None

        rows.append({
            "indicator":  ind_id,
            "code":       bare,
            "name_hint":  hint,
            "unit_mult":  unit_mult,
            "sample_value": obs_value,
            "sample_is_integer": is_integer,
        })

        if rec:
            import time as _time
            _time.sleep(SLEEP)

    out_path = OUT_DIR / "fao_as_indicators.csv"
    with open(out_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"\nWrote {out_path}  ({len(rows)} indicator rows)")

    # 4. Print the candidate count indicators (where name_hint mentions
    #    "number" or sample is integer-valued)
    print("\nCandidate COUNT indicators (name mentions 'Number' OR sample is integer):")
    print(f"{'INDICATOR':<14} {'CODE':<6} {'SAMPLE':<14} {'NAME HINT'}")
    print("-" * 80)
    for row in rows:
        looks_count = (
            ("number" in (row["name_hint"] or "").lower())
            or (row["sample_is_integer"] is True
                and row["sample_value"] is not None)
        )
        if looks_count:
            print(f"{row['indicator']:<14} {row['code']:<6} "
                  f"{str(row['sample_value']):<14} {row['name_hint']}")


if __name__ == "__main__":
    main()
