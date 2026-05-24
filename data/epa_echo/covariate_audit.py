"""
ECHO_EXPORTER comprehensive covariate audit for the Poisson-frontier
empirical pivot.

Goal: enumerate candidate HPV outcomes and candidate covariates for
   (a) the frontier x  = drivers of TRUE HPV rate
   (b) the scaling z   = drivers of under-detection u
across the three programs with explicit HPV/SNC counts (CAA, CWA, RCRA),
and the multimedia rollup. Writes a single audit report to stdout.

No model fitting here. Only data summarisation.
"""

from pathlib import Path
import numpy as np
import pandas as pd

CSV = Path(__file__).resolve().parent / "ECHO_EXPORTER.csv"

# ---- columns to pull --------------------------------------------------------
USE_COLS = [
    # identifiers / location
    "REGISTRY_ID", "FAC_STATE", "FAC_COUNTY", "FAC_EPA_REGION",
    "FAC_LAT", "FAC_LONG", "FAC_ZIP", "FAC_FIPS_CODE",
    # facility-level flags
    "FAC_ACTIVE_FLAG", "FAC_MAJOR_FLAG", "FAC_FEDERAL_FLG",
    "FAC_INDIAN_CNTRY_FLG", "FAC_US_MEX_BORDER_FLG",
    "FAC_CHESAPEAKE_BAY_FLG", "FAC_NAA_FLAG", "FAC_IMP_WATER_FLG",
    "FAC_MYRTK_UNIVERSE",
    # demographics / EJ
    "FAC_PERCENT_MINORITY", "FAC_POP_DEN",
    # program flags
    "AIR_FLAG", "NPDES_FLAG", "SDWIS_FLAG", "RCRA_FLAG",
    "TRI_FLAG", "GHG_FLAG",
    # multimedia activity / enforcement
    "FAC_INSPECTION_COUNT", "FAC_DAYS_LAST_INSPECTION",
    "FAC_INFORMAL_COUNT", "FAC_FORMAL_ACTION_COUNT",
    "FAC_PENALTY_COUNT", "FAC_TOTAL_PENALTIES",
    "FAC_LAST_PENALTY_AMT",
    "FAC_DATE_LAST_INSPECTION_EPA", "FAC_DATE_LAST_INSPECTION_STATE",
    # multimedia outcome
    "FAC_QTRS_WITH_NC", "FAC_PROGRAMS_WITH_SNC",
    "FAC_SNC_FLG", "FAC_COMPLIANCE_STATUS",
    "FAC_3YR_COMPLIANCE_HISTORY",
    # NAICS / SIC sector
    "FAC_NAICS_CODES", "FAC_SIC_CODES",
    "CAA_NAICS", "CWA_NAICS", "RCRA_NAICS",
    # CAA (HPV)
    "CAA_PERMIT_TYPES", "CAA_EVALUATION_COUNT", "CAA_DAYS_LAST_EVALUATION",
    "CAA_INFORMAL_COUNT", "CAA_FORMAL_ACTION_COUNT",
    "CAA_PENALTIES", "CAA_LAST_PENALTY_AMT",
    "CAA_QTRS_WITH_NC", "CAA_COMPLIANCE_STATUS",
    "CAA_HPV_FLAG", "CAA_3YR_COMPL_QTRS_HISTORY",
    # CWA (SNC)
    "CWA_PERMIT_TYPES", "CWA_INSPECTION_COUNT", "CWA_DAYS_LAST_INSPECTION",
    "CWA_INFORMAL_COUNT", "CWA_FORMAL_ACTION_COUNT",
    "CWA_PENALTIES", "CWA_LAST_PENALTY_AMT",
    "CWA_QTRS_WITH_NC", "CWA_COMPLIANCE_STATUS",
    "CWA_SNC_FLAG", "CWA_13QTRS_COMPL_HISTORY",
    "CWA_13QTRS_EFFLNT_EXCEEDANCES",
    # RCRA (SNC)
    "RCRA_PERMIT_TYPES", "RCRA_INSPECTION_COUNT",
    "RCRA_DAYS_LAST_EVALUATION",
    "RCRA_INFORMAL_COUNT", "RCRA_FORMAL_ACTION_COUNT",
    "RCRA_PENALTIES", "RCRA_LAST_PENALTY_AMT",
    "RCRA_QTRS_WITH_NC", "RCRA_COMPLIANCE_STATUS",
    "RCRA_SNC_FLAG", "RCRA_3YR_COMPL_QTRS_HISTORY",
    # TRI / GHG (scale proxies)
    "TRI_RELEASES_TRANSFERS", "TRI_ON_SITE_RELEASES",
    "GHG_CO2_RELEASES",
]

DTYPES = {
    "CAA_NAICS": str, "CWA_NAICS": str, "RCRA_NAICS": str,
    "FAC_NAICS_CODES": str, "FAC_SIC_CODES": str,
    "FAC_ZIP": str, "FAC_FIPS_CODE": str, "FAC_EPA_REGION": str,
    "CAA_3YR_COMPL_QTRS_HISTORY": str,
    "CWA_13QTRS_COMPL_HISTORY": str,
    "RCRA_3YR_COMPL_QTRS_HISTORY": str,
    "FAC_3YR_COMPLIANCE_HISTORY": str,
}

print(f"Reading {len(USE_COLS)} columns from ECHO_EXPORTER.csv ...")
df = pd.read_csv(CSV, usecols=USE_COLS, dtype=DTYPES, low_memory=False)
print(f"  total facility rows: {len(df):,}")
print(f"  active facilities  : {(df['FAC_ACTIVE_FLAG']=='Y').sum():,}")


# ---- HPV-style outcome counts -----------------------------------------------
def count_chars(s, chars):
    """Count characters in `chars` within string s. NaN -> NaN."""
    if not isinstance(s, str):
        return np.nan
    return sum(s.count(c) for c in chars)


# CAA HPV-quarter count: 'H' in CAA_3YR_COMPL_QTRS_HISTORY (12 quarters)
df["caa_hpv_qtrs"] = df["CAA_3YR_COMPL_QTRS_HISTORY"].apply(
    lambda s: count_chars(s, "H"))
# CAA any-violation quarter count: 'V' or 'H' (V = violation but not HPV; H = HPV)
df["caa_viol_qtrs"] = df["CAA_3YR_COMPL_QTRS_HISTORY"].apply(
    lambda s: count_chars(s, "VH"))
# CWA SNC-quarter count: 'S' in CWA_13QTRS_COMPL_HISTORY (13 quarters)
df["cwa_snc_qtrs"] = df["CWA_13QTRS_COMPL_HISTORY"].apply(
    lambda s: count_chars(s, "S"))
# CWA any-violation quarter count: 'S','V','D','E','T','X' (RNC/violation codes)
df["cwa_viol_qtrs"] = df["CWA_13QTRS_COMPL_HISTORY"].apply(
    lambda s: count_chars(s, "SVDETX"))
# RCRA SNC-quarter count: 'S' in RCRA_3YR_COMPL_QTRS_HISTORY (12 quarters)
df["rcra_snc_qtrs"] = df["RCRA_3YR_COMPL_QTRS_HISTORY"].apply(
    lambda s: count_chars(s, "S"))
df["rcra_viol_qtrs"] = df["RCRA_3YR_COMPL_QTRS_HISTORY"].apply(
    lambda s: count_chars(s, "SV"))


def summarise_count(y, label, scope_mask=None):
    if scope_mask is None:
        scope_mask = y.notna()
    yv = y[scope_mask].astype(float)
    n = len(yv)
    if n == 0:
        print(f"\n[{label}] EMPTY scope")
        return
    mean = yv.mean()
    var = yv.var()
    zero_pct = 100 * (yv == 0).mean()
    vm = var / mean if mean > 0 else float("nan")
    q = yv.quantile([0.5, 0.75, 0.9, 0.95, 0.99, 1.0]).tolist()
    print(f"\n[{label}]  n={n:>8,}  mean={mean:6.3f}  var={var:8.3f}  "
          f"V/M={vm:6.2f}  zero%={zero_pct:5.1f}  "
          f"med/p75/p90/p95/p99/max = {q[0]:.0f}/{q[1]:.0f}/{q[2]:.0f}/"
          f"{q[3]:.0f}/{q[4]:.0f}/{q[5]:.0f}")


print("\n" + "=" * 78)
print("SECTION 1: Candidate HPV/SNC outcome counts (full universe + scoped)")
print("=" * 78)

# Air universe = AIR_FLAG=='Y' and CAA_PERMIT_TYPES not blank
air_in = (df["AIR_FLAG"] == "Y") & df["CAA_PERMIT_TYPES"].notna()
print(f"\nAir-regulated facilities (AIR_FLAG=Y & permit): {air_in.sum():,}")
summarise_count(df["caa_hpv_qtrs"], "CAA HPV qtrs (full)")
summarise_count(df["caa_hpv_qtrs"], "CAA HPV qtrs (in scope)", air_in)
summarise_count(df["caa_viol_qtrs"], "CAA violation qtrs (in scope)", air_in)
# Title V majors
air_major = air_in & (df["FAC_MAJOR_FLAG"] == "Y")
print(f"\nAir majors (FAC_MAJOR_FLAG=Y & in scope): {air_major.sum():,}")
summarise_count(df["caa_hpv_qtrs"], "CAA HPV qtrs (air majors)", air_major)
summarise_count(df["caa_viol_qtrs"], "CAA violation qtrs (air majors)", air_major)

# CWA universe
cwa_in = (df["NPDES_FLAG"] == "Y") & df["CWA_PERMIT_TYPES"].notna() & \
         (df["CWA_PERMIT_TYPES"].str.upper() != "INACTIVE")
print(f"\nNPDES-active facilities: {cwa_in.sum():,}")
summarise_count(df["cwa_snc_qtrs"], "CWA SNC qtrs (full)")
summarise_count(df["cwa_snc_qtrs"], "CWA SNC qtrs (in scope)", cwa_in)
summarise_count(df["cwa_viol_qtrs"], "CWA violation qtrs (in scope)", cwa_in)
cwa_major = cwa_in & (df["FAC_MAJOR_FLAG"] == "Y")
print(f"\nCWA majors: {cwa_major.sum():,}")
summarise_count(df["cwa_snc_qtrs"], "CWA SNC qtrs (CWA majors)", cwa_major)

# RCRA universe (TSDs and LQGs)
rcra_in = (df["RCRA_FLAG"] == "Y") & df["RCRA_PERMIT_TYPES"].notna()
print(f"\nRCRA-regulated facilities: {rcra_in.sum():,}")
summarise_count(df["rcra_snc_qtrs"], "RCRA SNC qtrs (in scope)", rcra_in)
summarise_count(df["rcra_viol_qtrs"], "RCRA violation qtrs (in scope)", rcra_in)

# Multimedia FAC_PROGRAMS_WITH_SNC
fps = pd.to_numeric(df["FAC_PROGRAMS_WITH_SNC"], errors="coerce")
summarise_count(fps, "FAC_PROGRAMS_WITH_SNC (full)")


# ---- Covariate audit on the CHOSEN scope -----------------------------------
# Default scope shown below: CAA Title V majors (HPV is a CAA-defined concept).
# This is the universe we will report on most thoroughly.

scope = air_major.copy()
scope_label = "CAA majors (AIR_FLAG=Y & FAC_MAJOR_FLAG=Y)"
print("\n" + "=" * 78)
print(f"SECTION 2: Covariate availability on scope = {scope_label}  "
      f"(n={scope.sum():,})")
print("=" * 78)


def num_audit(col, mask):
    s = pd.to_numeric(df.loc[mask, col], errors="coerce")
    nm = s.notna().sum()
    n = mask.sum()
    if nm == 0:
        return f"{col:<40} : non-missing 0/{n}"
    q = s.quantile([0, .25, .5, .75, .95, 1]).tolist()
    return (f"{col:<40} : non-missing {nm:>7,}/{n:<7,} ({100*nm/n:5.1f}%)  "
            f"min/p25/med/p75/p95/max = {q[0]:.2f}/{q[1]:.2f}/{q[2]:.2f}/"
            f"{q[3]:.2f}/{q[4]:.2f}/{q[5]:.2f}")


def cat_audit(col, mask, top=6):
    s = df.loc[mask, col]
    nm = s.notna().sum()
    n = mask.sum()
    if nm == 0:
        return f"{col:<40} : non-missing 0/{n}"
    vc = s.value_counts(dropna=False).head(top)
    cats = ", ".join(f"{k}={v:,}" for k, v in vc.items())
    return (f"{col:<40} : non-missing {nm:>7,}/{n:<7,} ({100*nm/n:5.1f}%)  "
            f"top: {cats}")


print("\n--- Identifiers / location ---")
for c in ["FAC_STATE", "FAC_EPA_REGION", "FAC_INDIAN_CNTRY_FLG",
          "FAC_NAA_FLAG", "FAC_IMP_WATER_FLG", "FAC_CHESAPEAKE_BAY_FLG",
          "FAC_FEDERAL_FLG"]:
    print(" ", cat_audit(c, scope))

print("\n--- Sector (NAICS) ---")
for c in ["CAA_NAICS", "FAC_NAICS_CODES"]:
    n2 = df.loc[scope, c].astype(str).str.extract(r"(\d{2})", expand=False)
    nm = n2.notna().sum()
    top = n2.value_counts().head(8)
    cats = ", ".join(f"{k}={v:,}" for k, v in top.items())
    print(f"  {c:<40} 2-digit non-missing {nm:,} ({100*nm/scope.sum():.1f}%)  "
          f"top: {cats}")

print("\n--- Demographics / EJ ---")
for c in ["FAC_PERCENT_MINORITY", "FAC_POP_DEN"]:
    print(" ", num_audit(c, scope))

print("\n--- Inspection / enforcement (FAC-level) ---")
for c in ["FAC_INSPECTION_COUNT", "FAC_DAYS_LAST_INSPECTION",
          "FAC_INFORMAL_COUNT", "FAC_FORMAL_ACTION_COUNT",
          "FAC_PENALTY_COUNT", "FAC_TOTAL_PENALTIES",
          "FAC_LAST_PENALTY_AMT"]:
    print(" ", num_audit(c, scope))

print("\n--- CAA-specific inspection / enforcement ---")
for c in ["CAA_EVALUATION_COUNT", "CAA_DAYS_LAST_EVALUATION",
          "CAA_INFORMAL_COUNT", "CAA_FORMAL_ACTION_COUNT",
          "CAA_PENALTIES", "CAA_LAST_PENALTY_AMT",
          "CAA_QTRS_WITH_NC"]:
    print(" ", num_audit(c, scope))

print("\n--- Co-regulation (cross-program scale proxies) ---")
for c in ["NPDES_FLAG", "RCRA_FLAG", "TRI_FLAG", "GHG_FLAG"]:
    print(" ", cat_audit(c, scope, top=4))
for c in ["TRI_ON_SITE_RELEASES", "GHG_CO2_RELEASES"]:
    print(" ", num_audit(c, scope))


# ---- Cross-program comparison summary --------------------------------------
print("\n" + "=" * 78)
print("SECTION 3: Cross-program comparison (sample-size × overdispersion)")
print("=" * 78)


def block(scope_mask, outcome, label):
    y = pd.to_numeric(df.loc[scope_mask, outcome], errors="coerce")
    n = y.notna().sum()
    if n == 0:
        return
    mean = y.mean(); var = y.var()
    vm = var / mean if mean > 0 else float("nan")
    zp = 100 * (y == 0).mean()
    print(f"  {label:<45} n={n:>8,}  mean={mean:6.3f}  V/M={vm:6.2f}  "
          f"zero={zp:5.1f}%  p95={y.quantile(.95):.0f}  max={y.max():.0f}")


block(air_in, "caa_hpv_qtrs", "CAA HPV qtrs / all air-regulated")
block(air_major, "caa_hpv_qtrs", "CAA HPV qtrs / air majors")
block(air_in, "caa_viol_qtrs", "CAA viol qtrs / all air-regulated")
block(air_major, "caa_viol_qtrs", "CAA viol qtrs / air majors")
block(cwa_in, "cwa_snc_qtrs", "CWA SNC qtrs / all NPDES-active")
block(cwa_major, "cwa_snc_qtrs", "CWA SNC qtrs / CWA majors")
block(rcra_in, "rcra_snc_qtrs", "RCRA SNC qtrs / RCRA-regulated")
