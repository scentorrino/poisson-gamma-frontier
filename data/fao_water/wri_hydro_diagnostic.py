"""
wri_hydro_diagnostic.py
=======================

Aggregate the WRI Global Power Plant Database to a (country, year) panel of
hydropower plants, and run the count-frontier diagnostic:

  - variance-to-mean ratio (Poisson would have ratio = 1; Negative Binomial
    > 1; the patent panel from §6 shows ratio far above 1)
  - share of country-years with zero plants
  - distribution of counts (histogram-style summary)
  - imputation rate proxy (fraction of plants without commissioning_year)

Two count outcomes are computed:

  STOCK : number of hydro plants commissioned up to year t in country c
  FLOW  : number of hydro plants commissioned IN year t in country c

The flow count is the cleaner methodological fit (independent draws each
year), but is sparser (lots of zeros). The stock count is denser but has
serial correlation by construction.
"""

from __future__ import annotations

from pathlib import Path
import pandas as pd

CSV = Path(__file__).resolve().parent / "wri_gppd" / "gppd.csv"

YEAR_START = 1990
YEAR_END   = 2022


def main():
    df = pd.read_csv(CSV, low_memory=False)
    print(f"WRI GPPD: {len(df):,} plants total, "
          f"{df['country'].nunique()} countries, "
          f"{df['primary_fuel'].nunique()} primary fuels")

    # ---- 1. Filter to hydro --------------------------------------------------
    hydro = df[df["primary_fuel"] == "Hydro"].copy()
    print(f"\nHydro plants: {len(hydro):,}")
    print(f"  Countries with at least one hydro plant: {hydro['country'].nunique()}")
    n_with_year = hydro["commissioning_year"].notna().sum()
    print(f"  With commissioning_year:    {n_with_year:,} "
          f"({100*n_with_year/len(hydro):.1f}%)")
    print(f"  Without commissioning_year: {len(hydro) - n_with_year:,} "
          f"({100*(len(hydro) - n_with_year)/len(hydro):.1f}%)")

    # Year cleanup
    hydro["commissioning_year"] = pd.to_numeric(
        hydro["commissioning_year"], errors="coerce"
    )
    hydro_dated = hydro.dropna(subset=["commissioning_year"]).copy()
    hydro_dated["commissioning_year"] = hydro_dated["commissioning_year"].astype(int)
    print(f"  Year range observed: "
          f"{hydro_dated['commissioning_year'].min()}–"
          f"{hydro_dated['commissioning_year'].max()}")

    # ---- 2. Build the (country, year) panel ----------------------------------
    # All countries that ever appear (with at least one dated hydro plant)
    countries = sorted(hydro_dated["country"].unique())
    years     = list(range(YEAR_START, YEAR_END + 1))

    # FLOW: plants commissioned in year t
    flow = (
        hydro_dated.groupby(["country", "commissioning_year"])
                   .size()
                   .reset_index(name="n_flow")
                   .rename(columns={"commissioning_year": "year"})
    )

    # STOCK: plants commissioned up to and including year t
    # Compute by cumulative sum within country across years.
    panel = (
        pd.MultiIndex.from_product([countries, years],
                                    names=["country", "year"])
                       .to_frame(index=False)
                       .merge(flow, on=["country", "year"], how="left")
    )
    panel["n_flow"] = panel["n_flow"].fillna(0).astype(int)

    # Stock: also count plants commissioned before YEAR_START
    pre_start = (
        hydro_dated[hydro_dated["commissioning_year"] < YEAR_START]
        .groupby("country").size().rename("pre_start_count")
    )
    panel = panel.merge(pre_start, left_on="country",
                        right_index=True, how="left")
    panel["pre_start_count"] = panel["pre_start_count"].fillna(0).astype(int)

    panel = panel.sort_values(["country", "year"])
    panel["n_stock"] = (
        panel.groupby("country")["n_flow"].cumsum()
        + panel["pre_start_count"]
    )

    print(f"\nPanel built: {len(panel):,} country-year rows  "
          f"({len(countries)} countries × {len(years)} years)")

    # ---- 3. Diagnostic ON THE FLOW COUNT -------------------------------------
    diag(panel["n_flow"], "FLOW: hydro plants commissioned in year t",
         years_label=f"{YEAR_START}–{YEAR_END}")

    # ---- 4. Diagnostic ON THE STOCK COUNT ------------------------------------
    diag(panel["n_stock"], "STOCK: cumulative hydro plants up to year t")

    # ---- 5. Save panel for follow-up ----------------------------------------
    out = CSV.parent / "hydro_count_panel.csv"
    panel.to_csv(out, index=False)
    print(f"\nWrote {out}")

    # Snapshot the head for the eye-test
    print("\nFirst 20 rows of the panel:")
    print(panel.head(20).to_string(index=False))

    # And a few non-zero rows to confirm the data has bite
    print("\nFirst 20 non-zero FLOW rows:")
    print(panel[panel["n_flow"] > 0].head(20).to_string(index=False))


def diag(s: pd.Series, label: str, years_label: str = "") -> None:
    print(f"\n=== {label} ===")
    if years_label:
        print(f"  Window: {years_label}")
    print(f"  n        : {len(s):,}")
    print(f"  Mean     : {s.mean():.3f}")
    print(f"  Variance : {s.var():.3f}")
    print(f"  Var/Mean : {s.var()/s.mean() if s.mean() > 0 else float('nan'):.2f}")
    print(f"  Zero share: {(s == 0).mean()*100:.1f}%  "
          f"({(s == 0).sum()} of {len(s)} country-years)")
    print(f"  Min, median, max: {s.min()}, {s.median()}, {s.max()}")
    bins = [(0, 0), (1, 1), (2, 5), (6, 20), (21, 100), (101, 10**9)]
    print("  Distribution:")
    for lo, hi in bins:
        in_bin = ((s >= lo) & (s <= hi)).sum()
        label = f"={lo}" if lo == hi else f"{lo}–{hi if hi < 10**9 else '∞'}"
        print(f"    {label:>10}: {in_bin:>6}  ({100*in_bin/len(s):>5.1f}%)")


if __name__ == "__main__":
    main()
