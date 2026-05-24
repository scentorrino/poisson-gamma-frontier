"""
probe_count_verify.py
=====================

Verify which AQUASTAT indicators are *consistently* integer-valued counts,
not continuous quantities that happened to sample as integers.

Method: for each candidate indicator, pull a moderate cross-country panel
(20 large-irrigation countries x 2010-2020) and check the share of
non-missing observations whose OBS_VALUE is an integer. A genuine count
should be 100% integer; a continuous variable rounded for display would
be far less.

Also investigate (a) the OBS_STATUS distribution — heavy "I" (imputed)
flags suggest the count is reconstructed from regression rather than
reported. We want indicators where direct reports dominate.
"""

from __future__ import annotations

import json
import time
from collections import Counter
from typing import Optional

import requests


CANDIDATES = [
    "FAO_AS_4192",   # claimed "Number of large dams"
    "FAO_AS_4193",   # claimed "Number of small dams"
    "FAO_AS_4194",   # "Total dam capacity"
    "FAO_AS_4196",   # unknown — sampled integer
    "FAO_AS_4460",   # unknown
    "FAO_AS_4469",   # unknown
    "FAO_AS_4473",   # unknown
    # Add a couple of definitely-continuous controls to validate the
    # is-integer test rejects them
    "FAO_AS_4308",   # area equipped for irrigation (continuous)
    "FAO_AS_4250",   # agricultural water withdrawal (continuous)
]

REF_AREAS = [
    "USA", "MEX", "BRA", "ARG", "CHN", "IND", "PAK", "EGY", "TUR", "IRN",
    "AUS", "ESP", "ITA", "FRA", "JPN", "VNM", "THA", "MAR", "ZAF", "RUS",
]
YEARS = list(range(2000, 2023))


def fetch_panel(indicator: str) -> list[dict]:
    """Pull the indicator across all countries / years (no filter), then
    filter client-side. Avoids 417 from over-long REF_AREA / TIME_PERIOD
    URL parameters."""
    url = "https://data360api.worldbank.org/data360/data"
    rows = []
    skip = 0
    page = 5000
    while True:
        params = {
            "DATABASE_ID": "FAO_AS",
            "INDICATOR":   indicator,
            "skip": skip, "top": page,
        }
        try:
            r = requests.get(url, params=params, timeout=120)
            r.raise_for_status()
            payload = r.json()
        except (requests.RequestException, json.JSONDecodeError) as e:
            print(f"  fetch error for {indicator}: {e}")
            break
        recs = payload.get("value", []) if isinstance(payload, dict) else []
        rows.extend(recs)
        if len(recs) < page:
            break
        skip += page
        time.sleep(0.3)
    # Filter client-side to the country / year sample
    yrs = set(str(y) for y in YEARS)
    rows = [r for r in rows
            if r.get("REF_AREA") in REF_AREAS
            and str(r.get("TIME_PERIOD")) in yrs]
    return rows


def is_integer_valued(s: str | None) -> Optional[bool]:
    if s is None or s == "":
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    return v == int(v)


def summarise(indicator: str, rows: list[dict]) -> dict:
    if not rows:
        return {"indicator": indicator, "n": 0,
                "n_int": 0, "pct_int": None,
                "min": None, "max": None,
                "obs_status": {}, "unit_mults": {},
                "sample": None}

    int_flags = [is_integer_valued(r.get("OBS_VALUE")) for r in rows]
    valid    = [f for f in int_flags if f is not None]
    n_int    = sum(1 for f in valid if f)
    pct_int  = (100.0 * n_int / len(valid)) if valid else None

    vals = []
    for r in rows:
        try:
            vals.append(float(r.get("OBS_VALUE")))
        except (TypeError, ValueError):
            pass

    return {
        "indicator":  indicator,
        "n":          len(rows),
        "n_int":      n_int,
        "pct_int":    pct_int,
        "min":        min(vals) if vals else None,
        "max":        max(vals) if vals else None,
        "obs_status": dict(Counter(r.get("OBS_STATUS") for r in rows)),
        "unit_mults": dict(Counter(r.get("UNIT_MULT")  for r in rows)),
        "sample":     {
            "REF_AREA": rows[0].get("REF_AREA"),
            "TIME_PERIOD": rows[0].get("TIME_PERIOD"),
            "OBS_VALUE":   rows[0].get("OBS_VALUE"),
            "COMMENT_OBS": (rows[0].get("COMMENT_OBS") or "")[:120],
            "DECIMALS":    rows[0].get("DECIMALS"),
        },
    }


def main():
    print(f"{'INDICATOR':<14} {'N':<5} {'%INT':<6} "
          f"{'RANGE':<22} {'STATUS':<24} SAMPLE")
    print("-" * 120)
    for ind in CANDIDATES:
        rows = fetch_panel(ind)
        s = summarise(ind, rows)
        rng = (f"{s['min']:.2f}-{s['max']:.2f}"
               if s["min"] is not None else "—")
        status_str = ", ".join(f"{k}:{v}" for k, v in s["obs_status"].items())
        sample_str = (f"{s['sample']['REF_AREA']}/{s['sample']['TIME_PERIOD']}"
                      f"={s['sample']['OBS_VALUE']}"
                      if s["sample"] else "—")
        pct_str = "?" if s["pct_int"] is None else f"{s['pct_int']:.0f}%"
        print(f"{s['indicator']:<14} {s['n']:<5} "
              f"{pct_str:<6} {rng:<22} {status_str:<24} {sample_str}")
        if s["sample"] and s["sample"]["COMMENT_OBS"]:
            print(f"               comment: {s['sample']['COMMENT_OBS']}")
        if s["unit_mults"]:
            print(f"               unit_mults: {s['unit_mults']}")


if __name__ == "__main__":
    main()
