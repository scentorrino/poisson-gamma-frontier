"""
Build the working CWA-majors panel for the Poisson stochastic frontier
application (production-orientation, under-detection interpretation).

Universe:  NPDES-active CWA majors (FAC_MAJOR_FLAG == 'Y',
           NPDES_FLAG == 'Y', CWA_PERMIT_TYPES populated & not INACTIVE).
Outcome:   y = CWA_QTRS_WITH_NC = number of quarters (0-13) the facility
           was flagged in ANY non-compliance status (RNC, violation, or
           SNC) over the rolling 13-quarter DMR window. Interpreted as
           the OBSERVED count of non-compliant quarters, which is a
           lower bound for the latent true count because each quarter's
           classification depends on DMR review / inspection coverage.

           For comparison the SNC-quarter count (count of 'S' characters
           in CWA_13QTRS_COMPL_HISTORY) is retained as an auxiliary
           column `snc_qtrs`.

Output:    data/epa_echo/cwa_facility_panel.csv (overwrites prior file).
"""

from pathlib import Path
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
SRC  = HERE / "ECHO_EXPORTER.csv"
OUT  = HERE / "cwa_facility_panel.csv"

USE_COLS = [
    # identifiers / location
    "REGISTRY_ID", "FAC_STATE", "FAC_EPA_REGION",
    # universe filters
    "NPDES_FLAG", "CWA_PERMIT_TYPES", "FAC_MAJOR_FLAG", "FAC_ACTIVE_FLAG",
    # outcome string
    "CWA_13QTRS_COMPL_HISTORY", "CWA_SNC_FLAG", "CWA_COMPLIANCE_STATUS",
    "CWA_QTRS_WITH_NC",
    # sector / context flags
    "CWA_NAICS", "FAC_NAICS_CODES",
    "FAC_INDIAN_CNTRY_FLG", "FAC_IMP_WATER_FLG", "FAC_CHESAPEAKE_BAY_FLG",
    "FAC_FEDERAL_FLG",
    # demographics / EJ
    "FAC_PERCENT_MINORITY", "FAC_POP_DEN",
    # co-regulation (scale proxies)
    "AIR_FLAG", "RCRA_FLAG", "TRI_FLAG", "GHG_FLAG",
    # multimedia (FAC_*) inspection / enforcement (dense)
    "FAC_INSPECTION_COUNT", "FAC_DAYS_LAST_INSPECTION",
    "FAC_INFORMAL_COUNT", "FAC_FORMAL_ACTION_COUNT",
    "FAC_TOTAL_PENALTIES", "FAC_LAST_PENALTY_AMT",
    # CWA-specific inspection / enforcement (sparse - NA->0)
    "CWA_INSPECTION_COUNT", "CWA_DAYS_LAST_INSPECTION",
    "CWA_INFORMAL_COUNT", "CWA_FORMAL_ACTION_COUNT",
    "CWA_PENALTIES", "CWA_LAST_PENALTY_AMT",
]

DTYPES = {
    "CWA_13QTRS_COMPL_HISTORY": str,
    "CWA_NAICS": str, "FAC_NAICS_CODES": str,
    "FAC_EPA_REGION": str,
}

print(f"Reading {len(USE_COLS)} columns from {SRC.name} ...")
df = pd.read_csv(SRC, usecols=USE_COLS, dtype=DTYPES, low_memory=False)
print(f"  total rows: {len(df):,}")

# ---- Universe filter: NPDES-active CWA majors -------------------------------
mask = (
    (df["NPDES_FLAG"] == "Y")
    & df["CWA_PERMIT_TYPES"].notna()
    & (df["CWA_PERMIT_TYPES"].str.upper() != "INACTIVE")
    & (df["FAC_MAJOR_FLAG"] == "Y")
)
sub = df.loc[mask].copy()
print(f"  CWA majors universe: {len(sub):,}")

# ---- Outcomes ---------------------------------------------------------------
# Primary y: CWA_QTRS_WITH_NC = number of quarters (0-13) in ANY non-compliance
# over the 13-quarter DMR window. This captures violations at any severity
# level (RNC, V, or S codes in the history string) and is the count we model.
# Auxiliary: snc_qtrs = count of 'S' characters in CWA_13QTRS_COMPL_HISTORY
# (significant non-compliance quarters only). Retained for comparison/diagnostics.
def count_S(s):
    return s.count("S") if isinstance(s, str) else np.nan

sub["snc_qtrs"] = sub["CWA_13QTRS_COMPL_HISTORY"].apply(count_S).astype("Int64")
sub["y"] = pd.to_numeric(sub["CWA_QTRS_WITH_NC"], errors="coerce").astype("Int64")
n_pre = len(sub)
sub = sub[sub["y"].notna()].copy()
print(f"  Dropped {n_pre - len(sub):,} rows with missing CWA_QTRS_WITH_NC")

# ---- Sector: 2-digit NAICS with FAC_NAICS_CODES fallback -------------------
def first_naics(s):
    if not isinstance(s, str):
        return None
    tok = s.split(",")[0].strip()
    return tok if tok else None

naics_primary  = sub["CWA_NAICS"].apply(first_naics)
naics_fallback = sub["FAC_NAICS_CODES"].apply(first_naics)
sub["naics_full"] = naics_primary.fillna(naics_fallback)
sub["naics2"] = sub["naics_full"].str[:2]
sub["naics4"] = sub["naics_full"].str[:4]

# Bucket low-frequency sectors into "other"; keep the dominant water/wastewater
# (22), manufacturing (31/32/33), construction (23), services (56), and
# transportation/utilities (48). Buckets chosen ex-ante from the 2-digit
# distribution on the CWA-majors universe.
KEEP_SECTORS = {"22", "31", "32", "33", "21", "23", "48", "56", "92"}
sub["sector2"] = sub["naics2"].where(sub["naics2"].isin(KEEP_SECTORS), "other")
sub.loc[sub["naics2"].isna(), "sector2"] = "unknown"

# ---- Recoding NA -> 0 for structurally-absent enforcement counters ---------
# These ECHO columns are populated only when the count is > 0 (the upstream
# program databases write rows only when an action exists). Within the
# CWA-majors universe, a missing CWA_FORMAL_ACTION_COUNT means "no formal
# action recorded," not "data unavailable." Same for the other CWA_ and
# FAC_-level enforcement aggregates.
NA_TO_ZERO = [
    "CWA_INSPECTION_COUNT", "CWA_INFORMAL_COUNT", "CWA_FORMAL_ACTION_COUNT",
    "CWA_PENALTIES", "CWA_LAST_PENALTY_AMT",
    "FAC_INSPECTION_COUNT", "FAC_INFORMAL_COUNT", "FAC_FORMAL_ACTION_COUNT",
    "FAC_TOTAL_PENALTIES", "FAC_LAST_PENALTY_AMT",
]
for c in NA_TO_ZERO:
    sub[c] = pd.to_numeric(sub[c], errors="coerce").fillna(0.0)

# Days-since columns: the natural fallback is "no inspection recorded" -> a
# large value (we use 9999 days, then `log(1+days/365)` shrinks the wedge
# while still ordering uninspected facilities below those inspected recently).
for c in ["FAC_DAYS_LAST_INSPECTION", "CWA_DAYS_LAST_INSPECTION"]:
    sub[c] = pd.to_numeric(sub[c], errors="coerce").fillna(9999.0)

# Numeric demographics
for c in ["FAC_PERCENT_MINORITY", "FAC_POP_DEN"]:
    sub[c] = pd.to_numeric(sub[c], errors="coerce")

# Y/N flags -> integer 0/1; NA -> 0
for c in ["FAC_INDIAN_CNTRY_FLG", "FAC_IMP_WATER_FLG",
          "FAC_CHESAPEAKE_BAY_FLG", "FAC_FEDERAL_FLG",
          "AIR_FLAG", "RCRA_FLAG", "TRI_FLAG", "GHG_FLAG"]:
    sub[c + "_Y"] = (sub[c] == "Y").astype("int8")
# (the raw Y/N strings are dropped from the panel; only the 0/1 ints kept)

# ---- Quarters-with-NC -------------------------------------------------------
sub["CWA_QTRS_WITH_NC"] = pd.to_numeric(
    sub["CWA_QTRS_WITH_NC"], errors="coerce").fillna(0).astype(int)

# ---- Final column selection -------------------------------------------------
OUT_COLS = [
    "REGISTRY_ID", "FAC_STATE", "FAC_EPA_REGION",
    "CWA_COMPLIANCE_STATUS", "CWA_SNC_FLAG",
    "y", "CWA_QTRS_WITH_NC", "snc_qtrs",
    "naics_full", "naics2", "naics4", "sector2",
    # context flags (Y -> 1)
    "FAC_INDIAN_CNTRY_FLG_Y", "FAC_IMP_WATER_FLG_Y",
    "FAC_CHESAPEAKE_BAY_FLG_Y", "FAC_FEDERAL_FLG_Y",
    "AIR_FLAG_Y", "RCRA_FLAG_Y", "TRI_FLAG_Y", "GHG_FLAG_Y",
    # demographics
    "FAC_PERCENT_MINORITY", "FAC_POP_DEN",
    # multimedia enforcement / inspection
    "FAC_INSPECTION_COUNT", "FAC_DAYS_LAST_INSPECTION",
    "FAC_INFORMAL_COUNT", "FAC_FORMAL_ACTION_COUNT",
    "FAC_TOTAL_PENALTIES", "FAC_LAST_PENALTY_AMT",
    # CWA-specific enforcement / inspection
    "CWA_INSPECTION_COUNT", "CWA_DAYS_LAST_INSPECTION",
    "CWA_INFORMAL_COUNT", "CWA_FORMAL_ACTION_COUNT",
    "CWA_PENALTIES", "CWA_LAST_PENALTY_AMT",
]
panel = sub[OUT_COLS].copy()

# ---- Summary ----------------------------------------------------------------
print(f"\nFinal panel: {len(panel):,} rows × {panel.shape[1]} columns")
for col, label in [("y", "y (CWA_QTRS_WITH_NC, primary outcome)"),
                   ("snc_qtrs", "snc_qtrs (auxiliary: SNC-only count)")]:
    s = panel[col].astype(float)
    print(f"\nOutcome {label}:")
    print(f"  mean   = {s.mean():.3f}")
    print(f"  var    = {s.var():.3f}")
    print(f"  V/M    = {s.var()/s.mean():.2f}" if s.mean() > 0 else "  V/M    = nan")
    print(f"  zero%  = {100*(s==0).mean():.1f}")
    print(f"  med/p75/p90/p95/p99/max = "
          + " / ".join(f"{q:.0f}" for q in s.quantile([.5,.75,.9,.95,.99,1])))

print(f"\nSector distribution (sector2):")
print(panel["sector2"].value_counts(dropna=False).to_string())

print(f"\nCovariate coverage (after NA-handling):")
for c in OUT_COLS:
    if c in ("REGISTRY_ID","y"): continue
    nm = panel[c].notna().sum()
    print(f"  {c:<32} {nm:>6,}/{len(panel):,}  ({100*nm/len(panel):5.1f}%)")

panel.to_csv(OUT, index=False)
print(f"\nWrote {OUT}  ({OUT.stat().st_size/1e6:.1f} MB)")
