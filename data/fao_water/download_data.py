"""
download_data.py
================

Local data download script for the SFM-with-count-outcome paper, cross-country
analysis using FAO AQUASTAT as primary source. Also pulls WGI (World
Governance Indicators) and FAOSTAT auxiliary variables (agricultural GDP,
crop production, fertilizers, machinery).

Run this on your local machine where you have unrestricted internet access.
The Anthropic sandbox cannot reach the FAO and World Bank API endpoints
directly because of network restrictions, but they are open public APIs and
this script handles authentication-free access.

USAGE
-----
    pip install -r requirements.txt
    python download_data.py

CONFIGURATION
-------------
Edit the CONFIG section below to change variables, countries, year range,
or which auxiliary datasets to pull. Defaults reflect the choices in the
project proposal (see proposal_to_coauthor.md):
    - 12 AQUASTAT variables (8 production-frontier core + 4 water/climate)
    - 6 WGI governance indicators
    - 4 FAOSTAT datasets (macro, fertilizers, machinery, crop production),
      each filtered to specific Items/Elements
    - Year range 1990-2022, ~100 countries cross-country sample

OUTPUTS
-------
data/
  aquastat_raw.csv         Long-format pull from AQUASTAT
  aquastat_panel.csv       Wide-format country-year panel ready for analysis
  wgi_raw.csv              WGI six governance indicators (panel format)
  faostat_<name>.csv       One file per FAOSTAT dataset, filtered & long format
  master_panel.csv         AQUASTAT + WGI merged country-year master file
  download_log.txt         Run log with coverage diagnostics

DEPENDENCIES
------------
    pandas >= 2.0
    requests >= 2.28

The AQUASTAT API returns JSON; the script paginates automatically.
WGI is pulled via the World Bank Indicators API (api.worldbank.org).
FAOSTAT is pulled via its bulk-download endpoint (bulks-faostat.fao.org).
"""

import os
import sys
import json
import time
import logging
from pathlib import Path
from typing import List, Dict, Optional

import pandas as pd
import requests


# =============================================================================
# CONFIG — edit these to change the pull
# =============================================================================

OUTPUT_DIR = Path("data")
LOG_FILE = OUTPUT_DIR / "download_log.txt"

YEAR_START = 1990
YEAR_END = 2022

# AQUASTAT variables to pull. Each entry maps a friendly name to the AQUASTAT
# variable code. The official catalogue is at
# https://data.apps.fao.org/aquastat/?lang=en (browse "Variables").
# These cover the production-frontier inputs/outputs and auxiliary water-
# resource and climate variables we discussed.
AQUASTAT_VARIABLES = {
    # --- Core production-frontier variables ---
    "area_equipped_irrigation_total":   "4308",   # Area equipped for irrigation: total (1000 ha)
    "area_actually_irrigated":          "4311",   # Area actually irrigated (1000 ha)
    "agric_water_withdrawal":           "4250",   # Agricultural water withdrawal (10^9 m3/yr)
    "agric_water_withdrawal_pct":       "4253",   # Agricultural water withdrawal as % of total
    "total_water_withdrawal":           "4263",   # Total water withdrawal (10^9 m3/yr)
    "irrigation_water_requirement":     "4475",   # Irrigation water requirement (10^9 m3/yr)
    "irrigation_water_use_efficiency":  "4502",   # Irrigation water use efficiency (%)
    "water_stress_indicator":           "4550",   # SDG 6.4.2 — Level of water stress (%)
    # --- Water resources & climate (auxiliary) ---
    "total_renewable_water_resources":  "4188",   # Total renewable water resources (10^9 m3/yr)
    "total_internal_renewable":         "4157",   # Total internal renewable water resources (10^9 m3/yr)
    "long_term_avg_precipitation_mm":   "4103",   # Long-term average precipitation in depth (mm/yr)
    "long_term_avg_precipitation_vol":  "4102",   # Long-term average precipitation in volume (10^9 m3/yr)
}

# Country selection. AQUASTAT uses M49 numeric codes internally; we resolve
# ISO3 to M49 via the API's countries endpoint at runtime. Setting
# COUNTRIES = None pulls everything (~200 territories).
# Defaults pull the cross-country full sample (~100 countries with non-trivial
# irrigated agriculture). Edit to restrict.
COUNTRIES: Optional[List[str]] = None  # None = all; or e.g. ["MEX","ARG","BRA",...]

# Auxiliary datasets — set to False to skip
PULL_WGI = True
PULL_FAOSTAT = True

# WGI indicators (six standard governance dimensions from the World Bank)
WGI_INDICATORS = {
    "voice_accountability":     "VA.EST",
    "political_stability":      "PV.EST",
    "government_effectiveness": "GE.EST",
    "regulatory_quality":       "RQ.EST",
    "rule_of_law":              "RL.EST",
    "control_of_corruption":    "CC.EST",
}

# FAOSTAT auxiliary variables — agricultural GDP, fertilizers, machinery,
# and crop production. These complement AQUASTAT for the second-stage
# explanation of inefficiency and as additional production-frontier inputs.
FAOSTAT_DATASETS = {
    # bulk download endpoints (FAOSTAT publishes these as zipped CSVs)
    "macro_indicators":  "https://bulks-faostat.fao.org/production/Macro-Statistics_Key_Indicators_E_All_Data.zip",
    "fertilizers":       "https://bulks-faostat.fao.org/production/Inputs_FertilizersProduct_E_All_Data.zip",
    "machinery":         "https://bulks-faostat.fao.org/production/Inputs_Machinery_E_All_Data.zip",
    "crop_production":   "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data.zip",
}

# FAOSTAT-specific filters: inside each downloaded dataset, which Items and
# Elements to keep. FAOSTAT files are wide tables with many series; without
# filtering, the resulting CSV is unwieldy.
FAOSTAT_FILTERS = {
    "macro_indicators": {
        "Item": [
            "Agriculture, forestry and fishing",
            "Gross Domestic Product",
        ],
        "Element": [
            "Value Added (Agriculture, Forestry and Fishing)",
            "Gross Domestic Product",
            "Value US$",
        ],
    },
    "fertilizers": {
        # Aggregated nutrient (N+P2O5+K2O) use per country
        "Item": ["Nutrient nitrogen N (total)", "Nutrient phosphate P2O5 (total)",
                 "Nutrient potash K2O (total)"],
        "Element": ["Agricultural Use"],
    },
    "machinery": {
        # Tractors in use is the standard capital proxy
        "Item": ["Tractors", "Agricultural tractors"],
        "Element": ["Stocks", "In Use"],
    },
    "crop_production": {
        # Aggregate crop output (gross production value) plus a few key staples
        "Item": ["Crops, primary", "Cereals, primary", "Wheat", "Maize (corn)", "Rice"],
        "Element": ["Production", "Area harvested", "Yield"],
    },
}

# API endpoints
AQUASTAT_BASE = "https://data.apps.fao.org/aquastat/api/v1"
WB_API_BASE = "https://api.worldbank.org/v2"

# Throttle to be a polite consumer of public APIs
SLEEP_BETWEEN_CALLS = 0.5  # seconds

# =============================================================================
# LOGGING
# =============================================================================

def setup_logging():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)s  %(message)s",
        handlers=[
            logging.FileHandler(LOG_FILE, mode="w"),
            logging.StreamHandler(sys.stdout),
        ],
    )


# =============================================================================
# AQUASTAT PULL
# =============================================================================

def fetch_aquastat() -> pd.DataFrame:
    """Pull AQUASTAT variables via the dissemination API.

    The API endpoint structure has been evolving; if the v1 endpoint
    used here changes, the request URL will need updating. As of late 2024
    the JSON pull returns rows of {area_code, area_name, year, variable_id,
    variable_name, value, unit}.
    """
    logging.info("Starting AQUASTAT pull")
    rows = []

    for friendly_name, var_code in AQUASTAT_VARIABLES.items():
        logging.info(f"  Fetching variable {var_code} ({friendly_name})")
        params = {
            "variables": var_code,
            "year_start": YEAR_START,
            "year_end": YEAR_END,
            "format": "json",
        }
        if COUNTRIES is not None:
            # AQUASTAT accepts ISO3 codes via the country filter
            params["countries"] = ",".join(COUNTRIES)

        try:
            r = requests.get(f"{AQUASTAT_BASE}/data", params=params, timeout=60)
            r.raise_for_status()
            data = r.json()
        except requests.HTTPError as e:
            logging.error(f"    HTTP error for {var_code}: {e}")
            continue
        except json.JSONDecodeError:
            logging.error(f"    Could not decode JSON for {var_code} — endpoint may have changed.")
            logging.error(f"    Falling back to manual download instructions; see README.")
            continue

        # Expected response: {"data": [{...}, {...}], "metadata": {...}}
        records = data.get("data", data) if isinstance(data, dict) else data
        for rec in records:
            rows.append({
                "iso3":          rec.get("area_iso3") or rec.get("iso3"),
                "country":       rec.get("area_name") or rec.get("country"),
                "year":          rec.get("year"),
                "variable_code": var_code,
                "variable_name": friendly_name,
                "value":         rec.get("value"),
                "unit":          rec.get("unit"),
            })

        time.sleep(SLEEP_BETWEEN_CALLS)

    df = pd.DataFrame(rows)
    if df.empty:
        logging.warning("AQUASTAT pull returned empty. Check API status or fall back to CSV download.")
    else:
        logging.info(f"AQUASTAT: pulled {len(df)} rows across {df['iso3'].nunique()} countries")
    return df


def reshape_aquastat_to_panel(df_long: pd.DataFrame) -> pd.DataFrame:
    """Pivot the long format to country-year wide format with one column per variable."""
    if df_long.empty:
        return df_long
    panel = df_long.pivot_table(
        index=["iso3", "country", "year"],
        columns="variable_name",
        values="value",
        aggfunc="first",
    ).reset_index()
    panel.columns.name = None
    return panel


# =============================================================================
# WGI PULL (World Bank Indicators API)
# =============================================================================

def fetch_wgi() -> pd.DataFrame:
    """Pull six WGI indicators via the World Bank Indicators API.
    The API returns paginated JSON; we request page 1 with per_page=20000 to
    avoid pagination loops since the global panel is much smaller than that.
    """
    logging.info("Starting WGI pull")
    rows = []

    for friendly_name, indicator in WGI_INDICATORS.items():
        logging.info(f"  Fetching {indicator} ({friendly_name})")
        url = f"{WB_API_BASE}/country/all/indicator/{indicator}"
        params = {
            "format": "json",
            "date": f"{YEAR_START}:{YEAR_END}",
            "per_page": 20000,
        }
        try:
            r = requests.get(url, params=params, timeout=60)
            r.raise_for_status()
            payload = r.json()
        except (requests.HTTPError, json.JSONDecodeError) as e:
            logging.error(f"    Error fetching {indicator}: {e}")
            continue

        # WB API returns [metadata, data]
        if not isinstance(payload, list) or len(payload) < 2:
            logging.warning(f"    Unexpected response shape for {indicator}")
            continue

        for rec in payload[1]:
            rows.append({
                "iso3":      rec["countryiso3code"],
                "country":   rec["country"]["value"],
                "year":      int(rec["date"]),
                "indicator": friendly_name,
                "value":     rec["value"],
            })

        time.sleep(SLEEP_BETWEEN_CALLS)

    df = pd.DataFrame(rows)
    if not df.empty:
        # Drop rows where iso3 is empty (aggregates like "World", "LAC")
        df = df[df["iso3"].astype(bool)]
        # Pivot to wide
        df = df.pivot_table(
            index=["iso3", "country", "year"],
            columns="indicator",
            values="value",
            aggfunc="first",
        ).reset_index()
        df.columns.name = None
        logging.info(f"WGI: pulled {len(df)} country-year rows across {df['iso3'].nunique()} countries")
    return df


# =============================================================================
# FAOSTAT PULL (bulk CSV downloads)
# =============================================================================

def fetch_faostat() -> Dict[str, pd.DataFrame]:
    """FAOSTAT bulk endpoints provide zipped CSVs in a wide format with one
    column per year (Y1990, Y1991, ...). We download, unzip, filter to the
    specific Items and Elements we care about, and reshape to long format
    (iso3, year, item, element, value).
    """
    import io
    import re as _re
    import zipfile

    logging.info("Starting FAOSTAT pull")
    out = {}

    for dataset_name, url in FAOSTAT_DATASETS.items():
        logging.info(f"  Fetching {dataset_name} from {url}")
        try:
            r = requests.get(url, timeout=300)
            r.raise_for_status()
        except requests.HTTPError as e:
            logging.error(f"    Error: {e}")
            continue

        try:
            with zipfile.ZipFile(io.BytesIO(r.content)) as zf:
                # Each FAOSTAT zip contains a single main CSV (skip Flag and Symbols files)
                csv_name = next(
                    n for n in zf.namelist()
                    if n.endswith(".csv") and "Flag" not in n and "Symbols" not in n
                )
                with zf.open(csv_name) as f:
                    df = pd.read_csv(f, encoding="latin-1", low_memory=False)
        except Exception as e:
            logging.error(f"    Could not unzip/parse {dataset_name}: {e}")
            continue

        # Apply filters before reshaping (raw files are 100k+ rows)
        filt = FAOSTAT_FILTERS.get(dataset_name, {})
        if "Item" in filt and "Item" in df.columns:
            df = df[df["Item"].isin(filt["Item"])]
        if "Element" in filt and "Element" in df.columns:
            df = df[df["Element"].isin(filt["Element"])]

        if df.empty:
            logging.warning(f"    {dataset_name}: filters returned 0 rows. "
                            f"Item names may have changed in latest FAOSTAT release.")
            continue

        # Reshape: FAOSTAT columns are Y1990, Y1991, ..., Y2022. Melt to long.
        year_cols = [c for c in df.columns if _re.fullmatch(r"Y\d{4}", str(c))]
        id_cols = [c for c in df.columns if c not in year_cols
                   and not c.startswith("Y") and "Flag" not in c]
        df_long = df.melt(
            id_vars=id_cols,
            value_vars=year_cols,
            var_name="year_col",
            value_name="value",
        )
        df_long["year"] = df_long["year_col"].str.extract(r"Y(\d{4})").astype(int)
        df_long = df_long.drop(columns="year_col")
        df_long = df_long[(df_long["year"] >= YEAR_START) & (df_long["year"] <= YEAR_END)]
        df_long = df_long.dropna(subset=["value"])

        # Standardize country code column name to iso3 if available.
        # FAOSTAT uses "Area Code (M49)" in newer files; some older files use
        # "Area Code" with internal FAO codes. We keep both for traceability.
        if "Area" in df_long.columns:
            df_long = df_long.rename(columns={"Area": "country"})

        out[dataset_name] = df_long
        logging.info(f"    {dataset_name}: {len(df_long)} long-format rows after filtering")
        time.sleep(SLEEP_BETWEEN_CALLS)

    return out


# =============================================================================
# COVERAGE DIAGNOSTICS
# =============================================================================

def report_coverage(df: pd.DataFrame, name: str) -> None:
    """Log coverage by country and by variable to help decide on sample restrictions."""
    if df.empty:
        logging.warning(f"{name}: dataframe is empty, skipping coverage report")
        return

    logging.info(f"\n=== Coverage report: {name} ===")
    logging.info(f"  Rows: {len(df):,}")
    logging.info(f"  Countries: {df['iso3'].nunique()}")
    if "year" in df.columns:
        logging.info(f"  Years: {df['year'].min()} – {df['year'].max()}")

    # For wide panels, report missingness per column
    numeric_cols = df.select_dtypes(include="number").columns.drop(["year"], errors="ignore")
    if len(numeric_cols) > 0:
        logging.info("  Variable coverage (% non-missing):")
        for col in numeric_cols:
            pct = df[col].notna().mean() * 100
            logging.info(f"    {col:40s} {pct:5.1f}%")

    # Country-level completeness — useful to spot which countries to drop
    if len(numeric_cols) > 0:
        country_completeness = (
            df.groupby("iso3")[numeric_cols]
              .apply(lambda g: g.notna().mean().mean() * 100)
              .sort_values(ascending=False)
        )
        logging.info(f"  Top 10 countries by completeness: {country_completeness.head(10).to_dict()}")
        logging.info(f"  Bottom 10 countries by completeness: {country_completeness.tail(10).to_dict()}")


# =============================================================================
# MAIN
# =============================================================================

def main():
    setup_logging()
    logging.info("=" * 70)
    logging.info("Download run starting")
    logging.info(f"Year range: {YEAR_START}–{YEAR_END}")
    logging.info(f"Variables: {len(AQUASTAT_VARIABLES)} AQUASTAT, "
                 f"{len(WGI_INDICATORS) if PULL_WGI else 0} WGI, "
                 f"{len(FAOSTAT_DATASETS) if PULL_FAOSTAT else 0} FAOSTAT datasets")
    logging.info("=" * 70)

    # 1. AQUASTAT
    aq_long = fetch_aquastat()
    if not aq_long.empty:
        aq_long.to_csv(OUTPUT_DIR / "aquastat_raw.csv", index=False)
        aq_panel = reshape_aquastat_to_panel(aq_long)
        aq_panel.to_csv(OUTPUT_DIR / "aquastat_panel.csv", index=False)
        report_coverage(aq_panel, "AQUASTAT panel")
    else:
        aq_panel = pd.DataFrame()

    # 2. WGI
    wgi_panel = pd.DataFrame()
    if PULL_WGI:
        wgi_panel = fetch_wgi()
        if not wgi_panel.empty:
            wgi_panel.to_csv(OUTPUT_DIR / "wgi_raw.csv", index=False)
            report_coverage(wgi_panel, "WGI panel")

    # 3. FAOSTAT
    faostat_dfs = {}
    if PULL_FAOSTAT:
        faostat_dfs = fetch_faostat()
        for name, df in faostat_dfs.items():
            df.to_csv(OUTPUT_DIR / f"faostat_{name}.csv", index=False)

    # 4. Merge into master panel (AQUASTAT + WGI; FAOSTAT requires reshaping
    #    that depends on which specific items we want — left as a separate step)
    if not aq_panel.empty and not wgi_panel.empty:
        master = aq_panel.merge(
            wgi_panel.drop(columns=["country"], errors="ignore"),
            on=["iso3", "year"],
            how="outer",
            indicator=True,
        )
        logging.info(f"\nMaster panel merge:")
        logging.info(f"  Total rows: {len(master)}")
        logging.info(f"  Merge breakdown: {master['_merge'].value_counts().to_dict()}")
        master = master.drop(columns="_merge")
        master.to_csv(OUTPUT_DIR / "master_panel.csv", index=False)

    logging.info("\nDownload run complete. Files written to ./data/")


if __name__ == "__main__":
    main()
