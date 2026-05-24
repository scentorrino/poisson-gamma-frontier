Read CLAUDE.md and code/estimation_functions.R.

Data source: $ARGUMENTS (e.g. "data/patents.csv" or "the Hausman et al. 1984 patent panel").

Write two things:

1. code/empirical/application.R:
   - Load and clean data; report any missing values or outliers
   - Fit four models: Poisson, Poisson-Exp-Frontier, Poisson-Gamma-Frontier,
     and Fé & Hofler PHN (if the sfcount Stata output is available as .csv)
   - LR test: H0: α=1 vs H1: α free, using lrtest() logic
   - Compute efficiency scores for the preferred model
   - Save all fit objects to code/empirical/fits.rds

2. 06-empirical.qmd:

   Structure:
   - Subsection: Data — prose description + summary stats table
     (#| label: tbl-data-summary) via kable
   - Subsection: Results — four-model comparison table
     (#| label: tbl-results-main)
   - Subsection: Efficiency Scores:
     - Histogram of scores (#| label: fig-eff-hist)
     - Scatter: efficiency vs main covariate (#| label: fig-eff-scatter)
   - Subsection: Specification Tests — LR test result inline via `r round(lr_stat, 2)`
   - All results cited with @tbl- and @fig- cross-references

Flag any convergence issues with a warning callout block:
::: {.callout-warning}
Convergence note: ...
:::