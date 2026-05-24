# countSFA Code Audit — General Gamma Case
**Date:** 2026-05-20
**Scope:** `countSFA/R/{pmf,log_lik,scores,fit}.R` (v0.3.0)
**Focus:** correctness and numerical robustness of the general-α Gamma branch (production + cost), against the paper's @prp-pmf, @prp-te, and §4.

---

## Verdict

**Sound on correctness; one MAJOR numerical asymmetry between production and cost score evaluators, plus a handful of MINOR items.**

The closed-form α = 1 expressions match the paper exactly (lower / upper incomplete gamma in production / cost). The production alternating series is implemented with log-sum-exp guards. The cost-orientation v-substitution change of variable is correctly derived and stabilised. The fit wrapper's warm-start + bound-constrained refinement + fallback grid matches §4.

The one substantive numerical defect is asymmetric: `.te_moments_production` (general α) lacks the `log_max` stabilisation that `.te_moments_cost` carries, and will overflow at large `y * a`.

---

## Findings

### CRITICAL: none

### MAJOR

#### M1. `.te_moments_production` lacks log-max stabilisation
- **Location:** `scores.R:156–183`
- **Problem:** the general-α production posterior kernel is
  `log_kern(u) = -exp(a-u) + y·a - (y+b)u + (α-1) log u`. The `y·a` term is a constant in `u` and cancels in the ratio `I1/I0`, but it is included in the un-stabilised exponential `exp(log_kern(u))` that `integrate()` evaluates. For moderate-to-large `y·a` (e.g. `y = 100`, `a = log(8)` gives `y·a ≈ 208`; `y = 300`, `a = 5` gives `y·a = 1500`) the integrand overflows to `Inf` and `integrate()` either fails or returns `Inf`, making `I1/I0 = Inf/Inf = NaN`.
- **Why it's MAJOR:** the cost path (`.te_moments_cost`, `scores.R:199–268`) computes log of the integral via a coarse 200-point grid, subtracts the maximum, integrates the stabilised integrand, then adds the max back. The production path does not. The asymmetry is real and a referee will flag it.
- **Fix:** insert the same `log_max` stabilisation. Replace
  ```r
  I0 <- safe_int(function(u) exp(log_kern(u)))
  ```
  with a coarse-grid evaluation of `log_kern` to find `log_max`, then
  ```r
  I0 <- safe_int(function(u) exp(log_kern(u) - log_max))
  log_I0 <- log(I0) + log_max
  ```
  and compare `log_J0`, `log_J1`, `log_J2` in log space exactly as the cost path does. Drop the leading `y·a` term from `log_kern` entirely (it's a constant) for a cleaner implementation.
- **Empirical impact:** for the patent application (`y ≤ a few hundred`, `a` from a log-mean of 1–4) this likely fires occasionally but not catastrophically — the closed-form α = 1 path is used in §6 because the Gamma frontier did not converge. Simulations with `α_0 = 2` at large `n` may hit it.

### MINOR

#### m1. Default series truncation `K = 100` is undersized at large frontier means
- **Location:** `log_lik.R:18, 41, 74`; `pmf.R:19, 72`
- **Problem:** the default `K = 100` is far below the rule `K ≈ 3 e^{a_i}` documented in `fit.R:159–171`. Direct callers of `log_lik_poisson_frontier` or `pmf_poisson_gamma` who forget to pass `K` get silent truncation error at large `a_i`. The convergence warning at `|t_K|/total > 1e-6` (`pmf.R:123–129`) is the safety net, but is suppressed throughout `code/empirical/cwa_application.R` and `code/simulations/montecarlo.R` via `suppressWarnings()`.
- **Fix:** make the default `K = NULL` and compute `K` internally from `max(y) + max(exp(a_i))` when invoked directly, mirroring the auto-selection in `fit_poisson_frontier`. Or document that direct callers must override `K`.

#### m2. Cost closed-form for `e1` requires `y - b > 2` rather than `> 1`
- **Location:** `scores.R:201`
- **Problem:** the closed form `e1 = exp(a + log Γ(y-b-1, e^a) - log Γ(y-b, e^a))` requires only `y - b > 1` (so that `pgamma` shape `y - b - 1 > 0`); `e2` needs `y - b > 2`. The current gate requires both, falling back to quadrature for `1 < y - b ≤ 2` where `e1` could be evaluated in closed form.
- **Fix:** split the dispatch: compute `e1` in closed form for `y - b > 1`, and `e2` either in closed form (when `y - b > 2`) or by quadrature. Pure efficiency improvement.

#### m3. `.te_moments_production` mode uses α = 1 approximation
- **Location:** `scores.R:163`
- **Problem:** `u_mode <- pmax(ai - log(pmax(yi + b, 1)), 1e-4)` is the mode of the α = 1 kernel. For α ≠ 1, the true mode shifts by a term involving `(α − 1)/u`. The width 10/√(y+b+1) is generous, so the ±width envelope still covers the true mode, but for large `|α − 1|` (e.g. α near the upper bound 55) the integration grid may sparsely sample the true peak.
- **Fix:** compute the mode by solving the first-order condition `λ e^{-u} − (y + b) + (α − 1)/u = 0` numerically (one or two Newton steps starting from the α = 1 mode). Low-priority.

#### m4. `var(y) − mean(y)` heuristic ignored in cost orientation, but the production case keeps the original heuristic
- **Location:** `fit.R:154–158`
- **Problem:** the floor `pmax(b0_raw, 2.5)` for cost orientation is correct (above the variance-existence threshold `b > 2`; see the §4 paragraph added on 2026-05-19). But the production case keeps the MoM heuristic `b0_raw = mean(mu_hat)^2 / max(var(y) − mean(y), 1e-2)`. When data are exactly Poisson (excess = 0) the floor of `1e-2` produces `b0` ≈ 100 × E[μ]², a wildly large value. The optimiser typically corrects this within a few iterations, but the warm start is poor in this corner case.
- **Fix:** either (a) raise the floor on `excess` to `1e-1 * mean(y)` so `b0` stays in `O(mean(mu_hat)²/mean(y))`, or (b) add a guard `b0 <- min(b0, 1e3)` matching the L-BFGS-B upper bound.

#### m5. Asymmetric optimiser choice between exponential (BFGS, unbounded) and Gamma (L-BFGS-B, bounded)
- **Location:** `fit.R:181–197`
- **Problem:** when `dist = "exponential"` and `Z` is absent, the exponential fit uses unconstrained BFGS (`fit.R:195`). When `Z` is present or `dist = "gamma"`, L-BFGS-B with `log_b ∈ [-8, 8]` is used. The bound exclusion of the degenerate ridge is documented in §4, but for the homogeneous exponential case the same exclusion is not enforced. Degenerate data (all zeros, constant `y`) can drive `log_b` to ±∞ in unconstrained BFGS, producing `NaN` Hessians.
- **Fix:** use L-BFGS-B with `log_b ∈ [-8, 8]` for all branches. Single-line change.

#### m6. No condition-number check on Hessian
- **Location:** `fit.R:291–297`
- **Problem:** `solve(opt$hessian)` only catches outright singularity (zero determinant). A near-singular Hessian (condition number 10¹⁰⁺) returns finite but extreme inverse entries, giving wildly large SEs. The user has no signal that the Hessian-based vcov is unreliable.
- **Fix:** compute `rcond(opt$hessian)`; if `< 1e-10`, warn "Hessian near-singular; SEs may be unreliable".

#### m7. K parameter has no effect in cost orientation but is silently accepted
- **Location:** `log_lik.R:41, 74`; `pmf.R:72`; `fit.R:159–171`
- **Problem:** `K` is the alternating-series truncation budget for the production case. The cost path (`.log_pmf_cost`, `.te_moments_cost`) uses adaptive quadrature and ignores `K`. The function signatures accept `K` for both orientations, and the docstring on `pmf_poisson_gamma` notes "Production orientation only", but `fit_poisson_frontier`'s K auto-selection runs even when `orientation = "cost"`. Wasted Poisson GLM-derived computation; not incorrect.
- **Fix:** short-circuit the K auto-selection when `orientation == "cost"`.

#### m8. No input validation on `y`
- **Location:** `fit.R:106–114`, `log_lik.R:41`, `pmf.R:72`
- **Problem:** `y` is documented as a non-negative integer vector but never type-checked. Passing a vector with negative or non-integer entries produces silently incorrect PMF values (`lgamma(y+1)` is defined for any `y > −1` but the PMF is no longer a probability mass over `{0, 1, 2, …}`).
- **Fix:** add `stopifnot(all(y >= 0L), all(y == round(y)))` at the head of `fit_poisson_frontier`.

#### m9. Cost-PMF mode estimate ignores the `(log v − a)^{α − 1}` factor at large α
- **Location:** `pmf.R:176`; `scores.R:230`
- **Problem:** `v_mode <- max(ea, y - b - 1, ea + 1)` is the mode of the dominant factor `v^{y-b-1} e^{-v}` only. The auxiliary factor `(log v − a)^{α − 1}` shifts the joint mode further from `ea` when `α > 1`. The envelope of `20 * v_sd` (where `v_sd = sqrt(max(y-b, 1) + α)`) does include an `α` adjustment, but the centre is wrong. Result: the 200-point grid for `log_max` may sample slightly off-peak, producing a slightly suboptimal stabilisation factor. Quadrature itself (500 subdivisions, `rel.tol = 1e-8`) should still recover the integral.
- **Fix:** solve the joint first-order condition `(α − 1) / [(log v − a) v] + (y − b − 1)/v − 1 = 0` for `v_mode`. Low-priority; the existing tolerance margin absorbs the error.

---

## What the audit verifies as correct

| Item | File:line | Verified against |
|---|---|---|
| Production α = 1 closed form via lower incomplete gamma | `pmf.R:89–93` | @cor-pmf-exp / @eq-pmf-exp |
| Production general-α alternating series with signed log-sum-exp | `pmf.R:96–131` | @prp-pmf (i) / @eq-pmf-gamma |
| Cost α = 1 closed form via upper incomplete gamma (with `y > b` guard) | `pmf.R:154–159` | @cor-pmf-exp / @eq-cost-pmf |
| Cost general-α v-substitution quadrature with log-max stabilisation | `pmf.R:161–209` | @prp-pmf (ii) / @eq-pmf-gamma-cost (and @eq-cost-quad) |
| `log_lik` aggregates per-observation log-PMFs, supports scaling block `b_i = b · exp(-z_i' δ)` | `log_lik.R:41–82` | @eq-scaling-bi / §3 scaling model |
| Production α = 1 efficiency closed form `E[e^{-u} \| y] = e^{-a} γ(y+b+1, e^a) / γ(y+b, e^a)` | `scores.R:138–154` | @cor-te-exp (verified by direct calculation) |
| Cost α = 1 efficiency closed form (when `y − b > 2`) | `scores.R:201–214` | @cor-te-exp |
| Cost general-α moments via shared `J(c)` factory in v-space | `scores.R:199–268` | @prp-te (ii) / @eq-te-gamma-cost |
| Fit wrapper: warm-start from Poisson GLM → exponential → Gamma, with mean-invariant fallback grid `(α, b) → (α t, b t)` | `fit.R:206–263` | §4 estimation strategy |
| Auto-K selection rule `K = min(1000, max(50, ⌈3 max λ̂⌉))` | `fit.R:169–171` | §4 series-truncation remark |
| Cost-orientation b₀ floor at 2.5 above variance-existence threshold `b > 2` | `fit.R:156–157` | §4 starting-values (2026-05-19) |
| Delta-method SE: `SE(b) = b · SE(log b)` | `fit.R:303–310` | §4 standard errors |

---

## Priority recommendations

1. **[MAJOR M1]** Add log-max stabilisation to `.te_moments_production` to match the cost path. Three lines of code. Closes the only substantive numerical asymmetry between the two orientations.
2. **[MINOR m5]** Use L-BFGS-B with `log_b ∈ [-8, 8]` uniformly. Single-line change; eliminates a quiet failure mode at the boundary.
3. **[MINOR m1]** Either raise the default `K` or make it `NULL` with internal auto-selection in `log_lik_poisson_frontier` / `pmf_poisson_gamma`. Avoids silent truncation in direct usage.
4. **[MINOR m6]** Add an `rcond(Hessian)` check with a warning when conditioning is poor. Two lines.

---

## Positive findings

1. The signed log-sum-exp in `.log_pmf_production` (`pmf.R:96–131`) is the right tool for the alternating series and handles catastrophic cancellation with an explicit `lse_pos ≤ lse_neg` guard.
2. The cost-orientation v-substitution is correctly derived (the prefactor `e^{a(b-y)}` converting v-form to u-form is right, `scores.R:255–257`) and avoids `integrate()`'s infinite-bound substitution that collapses sharp peaks (`pmf.R:187–198`).
3. The scaling-model integration (`b_i = b · exp(-z_i' δ)` everywhere `b` appears) is consistent across `log_lik.R`, `scores.R`, and `fit.R`; no observation index is silently broadcast against a scalar `b` when `Z` is present.
4. The warm-start chain (GLM → exponential → Gamma) and the mean-invariant fallback `(α, b) → (α t, b t)` directly implement §4 and avoid the degenerate `α → 0, b → ∞` ridge.
