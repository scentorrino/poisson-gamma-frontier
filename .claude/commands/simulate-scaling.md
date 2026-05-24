---
description: Rewrite the Monte Carlo simulation code and results section to incorporate inefficiency determinants via the scaling model. Extends the existing homogeneous simulations with a new experimental design that varies the strength and functional form of inefficiency determinants.
argument-hint: [optional: "code-only" to regenerate R scripts without touching .qmd, or "write-only" to rewrite the section assuming results.rds already exists]
---

Read CLAUDE.md for the model specification, notation, and file structure.

Then read:
- code/simulations/montecarlo.R (existing simulation code)
- 05-simulations.qmd (existing results section)
- code/estimation_functions.R (PMF and likelihood functions)

Understand the existing experimental design before making any changes.
The new simulations must be **additive** — do not delete the existing
homogeneous experiments. Add new experiments as clearly labelled
additional sections in both the R script and the .qmd file.

---

## YOUR TASK

### PART A — Rewrite code/simulations/montecarlo.R

Append a new block to the existing simulation script.
Label it clearly with a comment header:

```r
# =============================================================
# EXPERIMENT 4: SCALING MODEL — INEFFICIENCY DETERMINANTS
# =============================================================
```

(Use experiment number 4 if experiments 1–3 already exist; adjust if not.)

#### Data generating process

The DGP for firm i is:

  Y_i | u_i ~ Poisson(exp(a_i - u_i))          [goods case]
  u_i        ~ Exp(b_i)
  b_i        = b * exp(-z_i' * delta)
  a_i        = x_i' * beta
  x_i        = (1, x_{i1}, x_{i2})             [intercept + 2 inputs]
  z_i        = (z_{i1}, z_{i2})                [2 inefficiency determinants]

Generate regressors as follows:
  x_{i1} ~ Uniform(0, 5)
  x_{i2} ~ Uniform(0, 5)
  z_{i1} ~ Bernoulli(0.5)                      [binary: e.g. ownership type]
  z_{i2} ~ Normal(0, 1)                        [continuous: e.g. log firm age]

True parameter values:
  beta  = c(1, 0.5, 0.3)                       [frontier coefficients]
  b     = 2                                     [baseline rate]
  delta_grid:  vary across experiments (see below)

#### Experimental grid

Design a factorial grid over:

  n     in {200, 500, 1000}
  delta in the following FOUR scenarios:

  Scenario 0 — No determinants (null):
    delta = c(0, 0)
    Purpose: verify size of the LR test; confirm no bias in beta estimates

  Scenario 1 — Weak determinants:
    delta = c(0.3, 0.2)
    Purpose: power of LR test in small samples; bias under mild heterogeneity

  Scenario 2 — Strong determinants:
    delta = c(1.0, 0.5)
    Purpose: bias if determinants are ignored (homogeneous model fitted to
    heterogeneous data); efficiency score distortion

  Scenario 3 — Sign reversal (one determinant reduces inefficiency):
    delta = c(0.8, -0.4)
    Purpose: verify that the estimator correctly recovers negative delta

For each cell in the grid, run R = 1000 replications.

#### For each replication, fit THREE models:

Model 1 — Scaling model (correct specification):
  Estimate beta, b, delta jointly by maximising the log-likelihood:
  ell = sum_i [ log(b_i) - b_i*a_i + log(pgamma(y_i+b_i, exp(a_i))) - lgamma(y_i+1) ]
  where b_i = b * exp(-z_i' * delta)
  Use optim() with method = "BFGS" and analytical gradient if available,
  fall back to Nelder-Mead if BFGS fails to converge.

Model 2 — Homogeneous model (misspecified, ignores determinants):
  Estimate beta, b only (delta forced to zero).
  This is the baseline model from the existing simulations.

Model 3 — Two-step model:
  Step 1: fit the homogeneous model to obtain efficiency scores v_i_hat
  Step 2: regress log(v_i_hat) on z_i by OLS
  This is the Wang & Schmidt (2002) two-step estimator. It is included
  as a benchmark because it is common in applied work despite being
  known to be inefficient.

#### Quantities to record for each replication

For each of the three models, record:

  1. Point estimates: beta_hat, b_hat, delta_hat (where applicable)
  2. Bias:           beta_hat - beta_true, etc.
  3. RMSE:           computed across replications
  4. Coverage:       indicator that 95% CI covers true value
                     (use Hessian-based standard errors)
  5. LR statistic:   2*(ell_scaling - ell_homogeneous)
                     Record as lr_stat; compare to qchisq(0.95, df=2)
  6. Efficiency scores: for each firm, record mean(|v_hat_i - v_true_i|)
                        across firms (mean absolute error of efficiency scores)
  7. Convergence flag: 1 if optim converged (code 0 or 1), 0 otherwise

Store results as a list with structure:
  results_scaling[[scenario]][[n]]  — a data frame with R rows

Save to results/scaling_results.rds using saveRDS().

Use parallel::mclapply() for the outer replication loop.
Set set.seed(20250101) before the grid loop for reproducibility.
Add a progress message at the start of each (scenario, n) cell:
  message(sprintf("Scenario %d | n = %d | starting...", scenario_id, n))

---

### PART B — Rewrite 05-simulations.qmd

Append a new section after the existing simulation results.
The section header should be:

  ## Experiment 4: Inefficiency Determinants and the Scaling Model {#sec-sim-scaling}

Structure the new section as follows:

#### Subsection 1 — Design (prose, ~3 paragraphs)

Paragraph 1: State the DGP. Reference @eq-scaling-pmf and @eq-scaling-bi
from the theory section (@sec-scaling) using cross-references.
Explain why two regressors in z_i — one binary, one continuous — are
chosen: they represent the type of heterogeneity most common in applied
work (ownership dummies and continuous firm characteristics).

Paragraph 2: Explain the three estimators being compared and the rationale
for including the two-step estimator as a benchmark. Cite Wang & Schmidt
(2002) and note that the one-step scaling MLE should dominate in large
samples by the Cramér–Rao bound, but the two-step may perform comparably
in small samples.

Paragraph 3: State what the null scenario (delta = 0) is designed to check:
that the LR test has correct size, and that beta estimates are unaffected
by adding unnecessary delta parameters.

#### Subsection 2 — Bias and RMSE of frontier coefficients (table chunk)

```{r}
#| label: tbl-scaling-rmse
#| tbl-cap: "Bias and RMSE of frontier coefficient estimates under the scaling model. Scaling = one-step MLE; Homogeneous = misspecified model; Two-step = Wang & Schmidt (2002) benchmark."
#| cache: true
```

Load results/scaling_results.rds.
Compute bias and RMSE for beta_1 (the intercept) and b across all
(scenario, n, model) cells.
Display as a kable table with:
  - Rows: scenarios (0, 1, 2, 3) × sample sizes (200, 500, 1000)
  - Columns: Bias(beta_1), RMSE(beta_1), Bias(b), RMSE(b) for each of the
    three models, side by side
  - Bold entries where the scaling model beats the homogeneous model
  - Use kableExtra::kable_styling() and collapse_rows() for scenario labels

Key result to highlight in the prose below the table:
  In Scenario 2 (strong determinants), the homogeneous model should show
  substantial upward bias in b_hat (it absorbs the unmodelled heterogeneity
  into the overall inefficiency level). The scaling model should be
  approximately unbiased for all n.

#### Subsection 3 — Bias and RMSE of delta estimates (table chunk)

```{r}
#| label: tbl-delta-rmse
#| tbl-cap: "Bias and RMSE of inefficiency determinant estimates (delta) under the one-step scaling MLE."
#| cache: true
```

Show bias and RMSE for delta_1 (binary z) and delta_2 (continuous z)
across scenarios 1–3 (exclude scenario 0) and all n.
Include a column for coverage probability of the 95% CI for each delta.
Note in the prose whether coverage is close to 95% for n = 500 and 1000;
flag any undercoverage in n = 200 as a finite-sample caveat.

#### Subsection 4 — Power of the LR test (figure chunk)

```{r}
#| label: fig-lr-power
#| fig-cap: "Power of the likelihood ratio test for inefficiency determinants. Scenario 0 gives the size (nominal 5% level shown as dashed line). Scenarios 1–3 give power at weak, strong, and sign-reversal alternatives."
#| fig-width: 7
#| fig-height: 4
#| cache: true
```

Plot rejection rates of the LR test (lr_stat > qchisq(0.95, 2)) across
all four scenarios and three sample sizes.
Use ggplot2 with:
  - x-axis: sample size (200, 500, 1000)
  - y-axis: rejection rate (0 to 1)
  - colour/linetype: scenario (0=size, 1=weak, 2=strong, 3=sign-reversal)
  - horizontal dashed line at 0.05 (nominal size)
  - theme_bw() + clean legend
Key result: size should be close to 0.05 for scenario 0; power should
approach 1 for scenarios 2 and 3 by n = 500.

#### Subsection 5 — Efficiency score accuracy (figure chunk)

```{r}
#| label: fig-score-mae
#| fig-cap: "Mean absolute error of firm-level efficiency scores. The scaling model uses the analytic posterior mean; the homogeneous model ignores inefficiency determinants."
#| fig-width: 7
#| fig-height: 4
#| cache: true
```

Plot mean absolute error of efficiency scores (averaged over firms and
replications) for the scaling vs homogeneous model, across scenarios and n.
Use a grouped bar chart (geom_col with dodge) with:
  - x-axis: scenario
  - y-axis: mean absolute error
  - fill: model (scaling vs homogeneous)
  - facet by sample size
Key result: in scenario 2, the homogeneous model should produce
substantially worse efficiency scores, illustrating the cost of ignoring
determinants.

#### Subsection 6 — Convergence and computation (short prose)

Report, in one paragraph:
  - Overall convergence rate of the scaling model MLE across all cells
    (compute as mean(convergence_flag) from the stored results)
  - Whether BFGS or Nelder-Mead fallback was used more often
  - Approximate wall-clock time per cell (use proc.time() in the R script
    and store it; report the range here)
  - A note that all computations use only base R and the incomplete gamma
    via pgamma(), so no specialised packages beyond parallel are required

#### Subsection 7 — Summary paragraph

Write 3–4 sentences summarising the key findings:
  1. The one-step scaling MLE recovers delta accurately and the LR test
     achieves correct size and good power by n = 500
  2. Ignoring determinants (homogeneous model) biases b upward in proportion
     to the strength of delta, distorting efficiency score rankings
  3. The two-step estimator performs [report actual finding from results]
  4. These results support using the scaling model whenever firm-level
     covariates that may drive inefficiency are available

---

## ADDITIONAL REQUIREMENTS

1. Update the existing simulation summary table (if any) to add a row
   noting that Experiment 4 results are in @sec-sim-scaling.

2. Add the following inline check at the start of the new .qmd section:
   ```{r}
   #| include: false
   stopifnot(file.exists("results/scaling_results.rds"))
   ```
   This prevents the document from compiling silently with missing results.

3. Ensure all new chunk labels are unique across the entire document.
   Prefix all new labels with "scaling-" if there is any risk of collision.

4. After writing all code, run the simulation for a single small test:
   R = 5 replications, n = 200 only, scenario 2 only.
   Confirm the script runs without errors and produces a valid .rds file.
   Report the test output. Do NOT run the full R = 1000 simulation —
   leave that for the user to run manually or via a background job.

5. At the end, print a checklist:
   - [ ] code/simulations/montecarlo.R updated and test run passed
   - [ ] results/scaling_results.rds produced by test run
   - [ ] 05-simulations.qmd section appended
   - [ ] All cross-references to @sec-scaling resolve
   - [ ] references.bib contains Wang & Schmidt (2002)
   - [ ] quarto check passes with no errors
