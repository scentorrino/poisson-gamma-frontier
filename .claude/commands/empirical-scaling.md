---
description: Extend the empirical application to include inefficiency determinants via the scaling model. Selects determinants from the PatentsHGH dataset on substantive grounds, fits homogeneous and scaling models, and halts with a detailed diagnostic report if the Gamma model fails to converge.
argument-hint: [optional: "diagnostics-only" to re-run convergence checks on existing fits without re-estimating]
---

Read CLAUDE.md for the model specification and notation.

Then read:
- code/empirical/application.R         (existing empirical code)
- 06-empirical.qmd                     (existing empirical section)
- code/estimation_functions.R          (PMF, likelihood, efficiency score functions)
- results/ directory listing           (check what .rds files already exist)

Understand the existing estimation pipeline before making any changes.

---

## PART A — Choose inefficiency determinants

The dataset is PatentsHGH (Hall, Griliches & Hausman 1986), available via
`data(PatentsHGH, package="Ecdat")`. The variables are:

  pat      — patent count (output)
  logr     — log R&D expenditure (frontier input, already in model)
  logk     — log book value of capital stock
  scisect  — indicator: firm operates in a science-intensive sector
  year     — year (1975–1979); dataset is a panel used cross-sectionally

The frontier (mean production function) already conditions on logr.
The inefficiency determinants z_i must be chosen on **substantive economic
grounds**, not by data-dredging. Use the following three determinants and
motivate each one in a comment in the R code AND in a paragraph in the .qmd:

  z1 = logk    (log capital stock)
     Rationale: capital-intensive firms may be better at translating R&D
     into patents (complementarity between physical and knowledge capital).
     A negative delta_1 means more capital → lower inefficiency (higher b_i).
     Sign prediction: delta_1 < 0 (capital reduces inefficiency).

  z2 = scisect (science sector indicator, 0/1)
     Rationale: firms in science-intensive sectors have stronger absorptive
     capacity and established IP practices, making them more efficient at
     converting R&D into patents.
     Sign prediction: delta_2 < 0 (science sector reduces inefficiency).

  z3 = logk_sq = logk^2
     Rationale: the capital-inefficiency relationship may be non-monotone —
     very capital-heavy firms may be bureaucratic and less agile. Including
     the square allows a U-shaped relationship.
     Include only if logk_sq passes a preliminary LR test against the
     model with only logk and scisect (see Step 3 below).

Before fitting any model:
  1. Print a correlation matrix of (logr, logk, scisect) to check for
     collinearity between frontier inputs and inefficiency determinants.
     If |cor(logr, logk)| > 0.7, add a warning comment noting that
     identification partially relies on functional form.
  2. Print descriptive statistics for z1, z2, z3 and save to
     results/determinants_desc.rds.

---

## PART B — Rewrite code/empirical/application.R

Add a clearly labelled new block after the existing estimation code:

```r
# =============================================================
# SECTION 2: SCALING MODEL — INEFFICIENCY DETERMINANTS
# =============================================================
```

#### Step 1 — Define the scaling log-likelihood

Write a function `loglik_scaling_exp(params, y, X, Z)` where:
  - params = c(beta, log_b, delta)   [log_b to enforce b > 0]
  - y      = patent counts (vector, length n)
  - X      = frontier design matrix (n × p), includes intercept
  - Z      = inefficiency determinant matrix (n × q), NO intercept

The log-likelihood is:
  a_i   = X %*% beta
  b_i   = exp(log_b) * exp(-Z %*% delta)
  ell_i = log(b_i) - b_i*a_i + log(pgamma(y+b_i, exp(a_i), lower.tail=TRUE)) - lgamma(y+1)
  return(sum(ell_i))

Also write the gradient function `grad_scaling_exp(params, y, X, Z)` using
numerical differentiation via numDeriv::grad() as a fallback — but attempt
the analytical gradient first (see estimation_functions.R for the pattern).

#### Step 2 — Fit six models and store all results

Fit the following models IN ORDER. For each model:
  - Use optim() with method = "BFGS", maxit = 2000, reltol = 1e-10
  - If BFGS does not converge (convergence code != 0), automatically retry
    with method = "Nelder-Mead", maxit = 5000
  - If Nelder-Mead also fails, retry from 5 random starting points drawn
    from a neighbourhood of the BFGS result (or prior estimates if available)
  - Record: convergence code, number of iterations, final log-likelihood,
    method used, wall-clock time via proc.time()

Models:
  M1: Poisson (no inefficiency)         — baseline, estimate beta only
  M2: PHN — Poisson half-normal         — Fé & Hofler (2013) benchmark
  M3: Exponential homogeneous           — our model, no determinants
  M4: Exponential scaling               — our model + z1, z2
  M5: Exponential scaling + logk_sq     — our model + z1, z2, z3
  M6: Gamma homogeneous (alpha free)    — our model, no determinants

For M6 (Gamma model), implement the following CONVERGENCE PROTOCOL:

  ── GAMMA CONVERGENCE PROTOCOL ──────────────────────────────────────

  Attempt 1: BFGS from starting values (beta from M3, log_alpha=0, log_b from M3)
  Attempt 2: BFGS from starting values (beta from M3, log_alpha=log(2), log_b from M3)
  Attempt 3: Nelder-Mead from Attempt 1 starting values
  Attempt 4: Nelder-Mead from Attempt 2 starting values
  Attempt 5: BFGS from 10 random starting points (log_alpha ~ Uniform(-1, 2),
             other params perturbed by rnorm(sd=0.1) around M3 estimates)

  After each attempt, check:
    (a) convergence code == 0
    (b) Hessian is negative definite (all eigenvalues of -H negative)
    (c) alpha_hat = exp(log_alpha_hat) is in (0.1, 20) — flag if outside
    (d) b_hat is in (0.1, 50) — flag if outside
    (e) log-likelihood of M6 > log-likelihood of M3 (must improve on M3
        since M3 is nested in M6 as alpha=1)

  If ALL FIVE attempts fail ANY of checks (a)–(e):

    ── HARD STOP ──────────────────────────────────────────────────────

    Do NOT proceed to fitting M7 or writing the .qmd section.
    Instead, execute the following diagnostic routine and then STOP:

    1. Save to results/gamma_convergence_diagnostics.rds:
         list(
           attempts        = list of all 5 optim() output objects,
           starting_values = list of all 5 starting value vectors,
           hessians        = list of all 5 numerical Hessians,
           eigenvalues     = list of eigenvalue vectors for each Hessian,
           loglik_trace    = named vector of final log-likelihoods per attempt,
           loglik_M3       = log-likelihood of M3 (the nested benchmark),
           data_summary    = list(y=y, X=X, cor_matrix=cor(cbind(y,X[,-1]))),
           session_info    = sessionInfo()
         )

    2. Print to console (clearly visible):
    cat("
    ══════════════════════════════════════════════════════════════════
    GAMMA MODEL CONVERGENCE FAILURE — HARD STOP
    ══════════════════════════════════════════════════════════════════

    All 5 estimation attempts failed to satisfy convergence criteria.

    Diagnostics saved to: results/gamma_convergence_diagnostics.rds

    What to check:
      1. Load diagnostics: d <- readRDS('results/gamma_convergence_diagnostics.rds')
      2. Inspect log-likelihood traces: d$loglik_trace
      3. Check Hessian eigenvalues: d$eigenvalues
         (negative definite = all negative; any positive = flat/saddle point)
      4. Check if alpha is hitting a boundary: look at d$attempts[[k]]$par
      5. Compare M6 log-likelihood to M3: d$loglik_trace vs d$loglik_M3
         (if M6 barely improves M3, the Gamma generalisation may not be
          warranted for this dataset — alpha ≈ 1 is consistent with this)
      6. Plot the profile likelihood for alpha:
         source('code/empirical/profile_alpha.R')  [script created below]
      7. Check for data issues: d$data_summary

    Suggested remedies:
      A. If eigenvalues show a near-zero direction: the model is weakly
         identified; consider fixing alpha and doing a grid search
      B. If log-likelihood of M6 ≈ log-likelihood of M3: the exponential
         model (alpha=1) may be adequate; report LR test result
      C. If alpha_hat is at the boundary of (0.1, 20): widen the search
         range and re-run this command with $ARGUMENTS = 'diagnostics-only'

    ══════════════════════════════════════════════════════════════════
    ")

    3. Create code/empirical/profile_alpha.R containing code to:
       - Fix alpha on a grid from 0.5 to 5 in steps of 0.1
       - At each alpha, maximise the log-likelihood over (beta, b)
       - Plot profile log-likelihood vs alpha using ggplot2
       - Mark the alpha=1 (exponential) value with a vertical dashed line
       - Save the plot to results/profile_alpha.png
       This script is for the user to run interactively after inspecting
       the diagnostics.

    4. STOP execution immediately. Do not write any .qmd content.
       Use stop("Gamma model convergence failure. See diagnostics above.")

  ── END GAMMA CONVERGENCE PROTOCOL ──────────────────────────────────

  If M6 converges successfully, proceed normally.

#### Step 3 — Model selection and LR tests

After fitting all models that converged, compute:

  LR_1: M3 vs M1   — test for any inefficiency (exponential vs Poisson)
  LR_2: M4 vs M3   — test for inefficiency determinants (scaling vs homogeneous)
  LR_3: M5 vs M4   — test for non-linear capital effect (add logk_sq)
  LR_4: M6 vs M3   — test for Gamma vs Exponential (only if M6 converged)

For each test, compute:
  lr_stat = 2 * (loglik_unrestricted - loglik_restricted)
  df      = difference in number of parameters
  p_value = 1 - pchisq(lr_stat, df)
  decision = ifelse(p_value < 0.05, "Reject H0", "Fail to reject H0")

Store all results in a named list and save to results/empirical_fits.rds.

Based on LR_3, decide whether to include logk_sq in the preferred model.
Set preferred_model <- if (p_value_LR3 < 0.05) "M5" else "M4".
Print the preferred model choice with justification.

#### Step 4 — Efficiency scores

For the preferred scaling model, compute:
  - Fitted b_i = exp(log_b_hat) * exp(-Z %*% delta_hat) for each firm
  - Efficiency score: E[exp(-u_i)|y_i, x_i, z_i] using the analytic formula
    pgamma(y_i + b_i_hat + 1, exp(a_i_hat)) / pgamma(y_i + b_i_hat, exp(a_i_hat)) * exp(-a_i_hat)
  - Predicted mean inefficiency: 1 / b_i_hat

Also compute efficiency scores for M3 (homogeneous) for comparison.

Check: for the bads-case caveat (not applicable here since patents are a
good, but add as a comment): confirm all b_i_hat > 1. If any b_i_hat <= 1,
print a warning noting that the efficiency score formula relies on b_i > 0
(goods case is always fine) and that the bads-case analogue would require b_i > 1.

Save efficiency scores for all firms to results/efficiency_scores.rds.

---

## PART C — Rewrite 06-empirical.qmd

Append a new subsection after the existing results:

  ### Inefficiency Determinants {#sec-emp-scaling}

Structure:

#### Paragraph 1 — Motivation and variable choice

Motivate z1 (logk), z2 (scisect), and if included z3 (logk_sq) on
economic grounds as described in Part A above. Note that logr is excluded
from z_i to ensure that identification of beta vs delta is driven by
the exclusion restriction rather than functional form alone.

#### Table chunk — Correlation matrix

```{r}
#| label: tbl-correlations
#| tbl-cap: "Pearson correlations between frontier inputs and inefficiency determinants. High correlation between logr and logk would indicate identification concerns."
#| cache: true
```

Load results/determinants_desc.rds and display the correlation matrix
using kable with 2 decimal places. Add a footnote if any correlation
exceeds 0.6 in absolute value.

#### Table chunk — Model comparison

```{r}
#| label: tbl-model-comparison
#| tbl-cap: "Model comparison: Poisson, Poisson half-normal (Fé & Hofler 2013), homogeneous exponential frontier, and scaling model with inefficiency determinants. Standard errors in parentheses."
#| cache: true
```

Load results/empirical_fits.rds.
Display a coefficient table with:
  Rows: Intercept, logr coefficient, b (or b_hat), delta_1 (logk),
        delta_2 (scisect), delta_3 (logk_sq if included), alpha (if M6 converged),
        Log-likelihood, N, AIC, Mean efficiency score
  Columns: M1 (Poisson), M2 (PHN), M3 (Exp homog), M4/M5 (Exp scaling), M6 (Gamma, if converged)
  Mark significance: *** p<0.01, ** p<0.05, * p<0.10

#### Table chunk — LR tests

```{r}
#| label: tbl-lr-tests
#| tbl-cap: "Likelihood ratio tests. Each row tests the row model against the column restriction."
#| cache: true
```

Display lr_stat, df, p_value, and decision for LR_1 through LR_4.

#### Paragraph — Interpretation of delta estimates

Interpret delta_1 and delta_2 in one paragraph.
For delta_1: a negative estimate confirms that capital-intensive firms
are more efficient; compute the implied marginal effect:
  d(E[u_i])/d(logk_i) = (1/b) * exp(z_i'delta) * delta_1
  evaluated at the mean of z_i (report the number).
For delta_2: compare mean predicted inefficiency for science-sector firms
vs non-science-sector firms (i.e. exp(delta_2_hat) gives the inefficiency
ratio, holding other z constant).

#### Figure chunk — Efficiency score distribution

```{r}
#| label: fig-efficiency-scaling
#| fig-cap: "Distribution of firm-level efficiency scores. Scaling model (solid) accounts for capital stock and sector; homogeneous model (dashed) ignores these determinants."
#| fig-width: 7
#| fig-height: 4
#| cache: true
```

Load results/efficiency_scores.rds.
Plot overlaid density curves (geom_density) for efficiency scores from
M3 (homogeneous) and preferred scaling model.
Use theme_bw(), informative axis labels, and a legend.

#### Figure chunk — Efficiency scores vs determinants

```{r}
#| label: fig-efficiency-determinants
#| fig-cap: "Firm efficiency scores plotted against log capital stock (left) and coloured by science sector (right). Lines show predicted efficiency from the scaling model."
#| fig-width: 9
#| fig-height: 4
#| cache: true
```

Two-panel ggplot:
  Left panel: scatter of efficiency score vs logk with a loess smooth
  Right panel: boxplot of efficiency scores by scisect (0 vs 1)
Use cowplot::plot_grid() or patchwork to combine.

#### Paragraph — Comparison with homogeneous model

Compare mean efficiency across firms between M3 and the preferred scaling
model. Note whether ignoring determinants over- or under-estimates mean
efficiency, and for which firms the gap is largest (highest logk? science sector?).
This connects to the simulation results in @sec-sim-scaling, where ignoring
determinants was shown to bias the overall inefficiency level.

---

## ADDITIONAL REQUIREMENTS

1. At the very start of the R script additions, print the R session info
   and package versions to results/session_info.txt using:
   writeLines(capture.output(sessionInfo()), "results/session_info.txt")

2. All optim() calls must have a tryCatch() wrapper. Any error (not just
   non-convergence) must be caught, printed with the error message, and
   stored in the diagnostics object before the hard stop logic runs.

3. After writing code but BEFORE running any estimation, print a preview:
   - Number of observations
   - Range of y (patents)
   - Number of zeros in y
   - Mean and SD of each z variable
   Confirm with: "Data checks passed. Proceeding to estimation."

4. After completing all estimation (if no hard stop), print a final summary:
   "
   Estimation complete.
   Preferred model: [M4 or M5]
   Log-likelihood:  [value]
   delta estimates: [delta_1_hat], [delta_2_hat] [, delta_3_hat if applicable]
   Mean efficiency: [value]
   All results saved to results/empirical_fits.rds
   "

5. After writing the .qmd additions, run quarto check on 06-empirical.qmd
   and report any unresolved cross-references.
