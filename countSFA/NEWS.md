# countSFA 0.5.0

## Breaking change

- `pmf_poisson_gamma()` production-frontier PMF now uses **adaptive
  quadrature** at \eqn{\alpha \neq 1} instead of the alternating
  series. The series remains the closed-form path at \eqn{\alpha = 1}
  via the lower incomplete gamma function. The series is also still
  reachable as the un-exported `.log_pmf_production_series()` for
  validation. The default change is motivated by the observation that
  the alternating-series convergence rate has an \eqn{\alpha}-dependent
  polynomial tail-suppression factor \eqn{(y + b + K)^{-\alpha}} that
  loses leverage as \eqn{\alpha \to 0^+}, so any practical truncation
  \eqn{K} leaves residual noise in the sub-exponential regime that the
  optimiser actually visits during profile-likelihood evaluation. The
  quadrature path eliminates this noise at the cost of \~1.5-3\eqn{\times}
  per-call work.

## Internal improvements

- Production quadrature is harmonised with the cost-frontier
  quadrature: log-space stability shift via a coarse 200-point grid,
  finite upper bound at \eqn{u_{\mathrm{hi}}} 20 standard deviations
  past the integrand mode (so `integrate()`'s infinite-bound
  substitution does not miss the narrow integrand peak at large
  \eqn{a}), 500 subdivisions, and an explicit \eqn{a > 500} overflow
  guard.
- The \eqn{\alpha}-aware auto-K rule \eqn{K \geq 3 e^a \max(1, 1/\alpha)}
  introduced in 0.4.0 is retained for users who explicitly pass
  \eqn{K} or call the series path directly, but the production default
  no longer consults it.

# countSFA 0.4.0

## New features

- `mom_starts()`: method-of-moments starting values for the homogeneous
  Poisson-Gamma frontier. Combines a Poisson-GLM warm-start for the
  slopes with an alpha-free root equation on the second and third
  Pearson-corrected moments of \eqn{Y} to recover \eqn{(\alpha, b)},
  and finishes with an intercept bias correction
  \eqn{\hat\alpha \log(b/(b - s))}. Exposed at the package level and
  used internally by `fit_poisson_frontier()` to seed optimisation.

## Internal improvements

- `fit_poisson_frontier()` now seeds the optimiser from `mom_starts()`
  output and uses standard-error-based bounds on the slope coefficients
  (`max(6 * se, 3)`), with a mean-invariant shift of `log_b` across the
  multi-start grid.
- `pmf_poisson_gamma()` auto-K rule is now alpha-aware:
  \eqn{K \geq 3 e^a \max(1, 1/\alpha)}, capped at 1,000. The
  alpha-free \eqn{3 e^a} formula previously used was conservative for
  \eqn{\alpha \geq 1} but under-truncated in the sub-exponential
  regime \eqn{\alpha < 1}, where the polynomial tail-size suppression
  \eqn{(y + b + K)^{-\alpha}} loses its leverage and the alternating
  series needs proportionally more terms. The cost-PMF mode-finder
  gains a Newton refinement step.
- `log_lik_poisson_frontier()` now clamps per-observation log-PMFs to
  the valid range \eqn{[-10^6, 0]} before summing instead of rejecting
  the whole likelihood with a 1e10 penalty as soon as one observation
  carries truncation noise. The optimiser sees a smooth bounded
  surface and individual numerically pathological observations no
  longer collapse the profile likelihood at extreme parameter
  values.

# countSFA 0.3.0

## New features

- Inefficiency-determinants ("scaling") extension. `fit_poisson_frontier()`
  and `log_lik_poisson_frontier()` now accept an optional `Z` matrix of
  determinants and parameterise the rate as
  \eqn{b_i = b \exp(-z_i' \delta)}.  Fits return the new components
  `delta`, `se_delta`, and `Z`; `summary.poisson_frontier()` appends one
  `delta.<zname>` row per determinant and reports the scaling-model
  dimension in the header.
- `efficiency_scores()` automatically uses the per-observation
  \eqn{b_i} when the supplied fit was estimated with a scaling model;
  homogeneous fits are unchanged.
- `fit_poisson_frontier()` gains a `starts_delta` argument for
  user-supplied starting values on the scaling block.

# countSFA 0.2.0

## New features

- `fit_poisson_halfnormal()`: maximum simulated likelihood fit of the
  Poisson half-normal frontier of Fé and Hofler (2013), with antithetic
  Halton draws.
- `vuong_test()`: Vuong (1989) test for non-nested model comparison,
  with optional AIC/BIC corrections.
- `efficiency_scores_halfnormal()`: posterior efficiency scores under
  the half-normal frontier.
- The series-truncation depth `K` in `fit_poisson_frontier()` is now
  selected automatically from the Poisson GLM warm-start
  (`K = min(1000, max(50, ceil(3 * max(mu_hat))))`).
- New `patents` dataset: the canonical Hausman, Hall, and Griliches
  (1984) panel of 346 firms × 5 years, with descriptive column names.
- New vignette `empirical-application` walking through the patents-R&D
  application.

# countSFA 0.1.0

- Initial release: `pmf_poisson_gamma()`, `log_lik_poisson_frontier()`,
  `fit_poisson_frontier()`, `efficiency_scores()`, `compare_models()`,
  and `summary.poisson_frontier()` for the exponential and Gamma
  inefficiency cases.
