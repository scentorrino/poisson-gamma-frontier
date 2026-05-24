# Data download — SFM with count outcome paper

This folder contains a download script that pulls the data we need for the
cross-country analysis: AQUASTAT (primary), World Bank WGI (governance),
and FAOSTAT (auxiliary agricultural variables).

The script is meant to run on **your local machine**, not on the server
where Claude was helping me draft it. The Anthropic sandbox cannot reach
the FAO and World Bank API endpoints because of network restrictions, but
all three are open public APIs with no authentication required.

## What the script pulls (defaults)

**AQUASTAT — 12 variables, 1990-2022, ~200 countries (about 100 with usable coverage)**

Production-frontier core:
- Area equipped for irrigation (1000 ha) — candidate count outcome
- Area actually irrigated (1000 ha) — candidate count outcome
- Agricultural water withdrawal (10⁹ m³/yr)
- Agricultural water withdrawal (% of total)
- Total water withdrawal (10⁹ m³/yr)
- Irrigation water requirement (10⁹ m³/yr)
- Irrigation water use efficiency (%)
- Water stress indicator (SDG 6.4.2)

Auxiliary water-resource and climate:
- Total renewable water resources (10⁹ m³/yr)
- Total internal renewable water resources (10⁹ m³/yr)
- Long-term average precipitation in depth (mm/yr)
- Long-term average precipitation in volume (10⁹ m³/yr)

**WGI — 6 governance indicators**: voice & accountability, political stability,
government effectiveness, regulatory quality, rule of law, control of corruption.

**FAOSTAT — 4 datasets, filtered to specific items**:
- Macro-Statistics: agricultural value added, GDP
- Fertilizers: agricultural use of N, P₂O₅, K₂O nutrients
- Machinery: tractors in use (capital proxy)
- Crop Production: aggregate crops/cereals plus wheat, maize, rice (production, area harvested, yield)

## Setup

```bash
python -m venv .venv
source .venv/bin/activate   # (or .venv\Scripts\activate on Windows)
pip install -r requirements.txt
```

## Run

```bash
python download_data.py
```

Output is written to `data/` and a run log to `data/download_log.txt`.

## What you get

| File | Description |
|---|---|
| `aquastat_raw.csv` | Long format (iso3, country, year, variable, value, unit) |
| `aquastat_panel.csv` | Wide format country-year panel, ready for analysis |
| `wgi_raw.csv` | World Governance Indicators (six dimensions, wide) |
| `faostat_macro_indicators.csv` | Filtered & reshaped to long format |
| `faostat_fertilizers.csv` | Filtered & reshaped |
| `faostat_machinery.csv` | Filtered & reshaped |
| `faostat_crop_production.csv` | Filtered & reshaped |
| `master_panel.csv` | AQUASTAT + WGI merged on (iso3, year) |
| `download_log.txt` | Coverage diagnostics: country count, missingness per variable |

## Configuration

Edit the top of `download_data.py`:

- `YEAR_START`, `YEAR_END`: temporal window
- `AQUASTAT_VARIABLES`: which AQUASTAT variables to pull (12 by default)
- `COUNTRIES`: `None` for all, or a list of ISO3 codes to restrict
- `PULL_WGI`, `PULL_FAOSTAT`: toggle auxiliary datasets
- `FAOSTAT_FILTERS`: which Items/Elements to keep within each FAOSTAT dataset

## What can go wrong

**The AQUASTAT API endpoint may have changed since this script was written.**
The new dissemination platform (`data.apps.fao.org/aquastat`, launched late
2022) is still evolving, and the exact API URL pattern is not as stable as
FAOSTAT's bulk endpoints. If the AQUASTAT pull fails, three fallbacks:

1. Check the current API at https://data.apps.fao.org/aquastat — there is a
   built-in "Download data" button that exports CSVs directly. Manual download
   is fine for a one-off pull; the script is for replicability.
2. Use the World Bank Data360 mirror of AQUASTAT: dataset code `FAO_AS` at
   https://data360.worldbank.org/en/dataset/FAO_AS — this is queryable via
   the Data360 API with the same data but in a different schema. Drop me a
   line if you want the script adapted to that source.
3. If the R workflow is preferable, the `FAOSTAT` package on R-universe has
   `get_faostat_bulk()` which handles AQUASTAT and is more robust than direct
   API calls because it uses the bulk download endpoints.

**FAOSTAT bulk URLs are stable but large.** Crop Production is ~150 MB and
Macro-Statistics is ~50 MB. Running all four FAOSTAT pulls on a slow
connection may time out; bump `timeout=300` in `fetch_faostat()` if needed.

**FAOSTAT Item names may have shifted.** The `FAOSTAT_FILTERS` dict uses
exact-string matching against the `Item` column. If an item returns 0 rows
after filtering, FAOSTAT may have renamed it (e.g. "Maize" became "Maize
(corn)" in the 2023 release). The log will warn you; check the unfiltered
CSV briefly to find the new name.

**Coverage will be uneven.** Many AQUASTAT variables are reported only every
five years for many countries, especially before 2010. The coverage report
in `download_log.txt` will tell us which countries to drop from the analysis
sample. Expect to lose 20-30 countries to incompleteness.

## Next step after download

Once the data lands, the next thing we should do together is the
distributional check we discussed: variance-to-mean ratio of the count
outcome (irrigated area in 1000 ha), share of zeros, and histogram by income
group. That tells us whether Negative Binomial SFM is justified over Poisson
SFM, which is the methodological hook of the paper.
