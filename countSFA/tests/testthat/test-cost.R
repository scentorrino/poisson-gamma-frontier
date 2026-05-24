# =============================================================================
# Cost-orientation regression tests.
#
# All tests in this file exercise the cost-frontier code paths in pmf.R,
# scores.R, and fit.R, which are not touched by the other test files.
# =============================================================================

# ---- PMF correctness --------------------------------------------------------

test_that("Cost PMF sums to 1 for alpha = 1 (closed-form path)", {
  a_test <- log(8); b_test <- 2.0
  y_grid <- 0:600
  log_probs <- vapply(y_grid, pmf_poisson_gamma,
                      numeric(1), a = a_test, b = b_test, alpha = 1,
                      orientation = "cost")
  total_prob <- sum(exp(log_probs))
  expect_equal(total_prob, 1, tolerance = 1e-3)
})

test_that("Cost PMF sums to 1 for alpha < 1 (singular integrand)", {
  # Use b = 3 so the marginal variance exists (cost case requires b > 2);
  # alpha < 1 with b near the variance-boundary at b = 2 has a power-law
  # right tail that requires impractically large y grids to sum close to 1.
  a_test <- log(8); b_test <- 3.0
  y_grid <- 0:600
  log_probs <- vapply(y_grid, pmf_poisson_gamma,
                      numeric(1), a = a_test, b = b_test, alpha = 0.5,
                      orientation = "cost")
  total_prob <- sum(exp(log_probs))
  expect_equal(total_prob, 1, tolerance = 5e-3)
})

test_that("Cost PMF sums to 1 for alpha > 1 (hump-shaped inefficiency)", {
  # b = 3 keeps us comfortably above the variance-existence threshold b > 2;
  # at b = 2 the right tail does not sum tightly within a tractable y grid.
  a_test <- log(8); b_test <- 3.0
  y_grid <- 0:600
  log_probs <- vapply(y_grid, pmf_poisson_gamma,
                      numeric(1), a = a_test, b = b_test, alpha = 2,
                      orientation = "cost")
  total_prob <- sum(exp(log_probs))
  expect_equal(total_prob, 1, tolerance = 5e-3)
})

test_that("Cost PMF alpha=1 closed form matches v-quadrature when y > b", {
  # The dispatch uses the closed form for alpha=1 with y > b.  Forcing the
  # quadrature path via alpha = 1 + eps must agree to high precision.
  a_test <- log(8); b_test <- 2.0
  for (y in c(5L, 10L, 50L, 100L)) {
    lp_closed <- pmf_poisson_gamma(y, a_test, b_test, alpha = 1,
                                   orientation = "cost")
    lp_quad   <- pmf_poisson_gamma(y, a_test, b_test, alpha = 1 + 1e-7,
                                   orientation = "cost")
    expect_equal(lp_quad, lp_closed, tolerance = 1e-5,
                 info = sprintf("y = %d", y))
  }
})

test_that("Cost PMF alpha=1 negative-shape regime (y <= b) matches u-form", {
  # The closed-form upper-incomplete-gamma path requires y > b; for y <= b
  # the code falls back to v-quadrature.  Cross-validate against direct
  # u-form integration.
  a_test <- log(8); b_test <- 2.5
  for (y in 0:2) {
    lp_pkg <- pmf_poisson_gamma(y, a_test, b_test, alpha = 1,
                                orientation = "cost")
    integrand_u <- function(u) exp((y - b_test) * u - exp(a_test + u))
    I <- integrate(integrand_u, 0, Inf, rel.tol = 1e-12)$value
    lp_direct <- log(b_test) + y * a_test - lgamma(y + 1) + log(I)
    expect_equal(lp_pkg, lp_direct, tolerance = 1e-8,
                 info = sprintf("y = %d", y))
  }
})

test_that("Cost PMF general alpha matches direct u-form integration", {
  skip_on_cran()  # 5x3x4 = 60 quadrature pairs; ~10s aggregate
  # The v-substitution must agree with direct u-form integration for any
  # (a, b, alpha).  Tests both alpha < 1 (singular integrand) and alpha > 1.
  a_test <- log(8)
  for (al in c(0.5, 0.8, 1.5, 2.0, 5.0)) {
    for (b_test in c(1.0, 2.0, 3.0)) {
      for (y in c(0L, 5L, 20L, 50L)) {
        lp_pkg <- pmf_poisson_gamma(y, a_test, b_test, alpha = al,
                                    orientation = "cost")
        integrand_u <- function(u)
          u^(al - 1) * exp((y - b_test) * u - exp(a_test + u))
        I <- tryCatch(integrate(integrand_u, 0, Inf, rel.tol = 1e-12)$value,
                      error = function(e) NA_real_)
        if (is.na(I) || I <= 0) next
        lp_direct <- al * log(b_test) + y * a_test - lgamma(y + 1) -
          lgamma(al) + log(I)
        expect_equal(lp_pkg, lp_direct, tolerance = 1e-6,
                     info = sprintf("y=%d b=%g al=%g", y, b_test, al))
      }
    }
  }
})

test_that("Cost PMF handles large y (regression test for upper=Inf bug)", {
  # Prior to the v_hi bound on the integration upper limit, large y combined
  # with alpha > 1 produced PMF values off by ~exp(50) because integrate's
  # infinite-bound substitution missed the integrand peak at v ~ y - b - 1.
  a_test <- log(8); b_test <- 2.0
  for (y in c(100L, 200L, 500L)) {
    for (al in c(1.5, 2.0, 5.0)) {
      lp_pkg <- pmf_poisson_gamma(y, a_test, b_test, alpha = al,
                                  orientation = "cost")
      # The PMF must be > -50 in log-space; the buggy version returned ~-60.
      expect_true(lp_pkg > -50,
                  info = sprintf("y=%d al=%g  lp=%.3f", y, al, lp_pkg))
      # And it must be smaller in absolute value than at y = 0 (which was
      # always handled correctly).
      lp_at_zero <- pmf_poisson_gamma(0L, a_test, b_test, alpha = al,
                                      orientation = "cost")
      expect_true(lp_pkg > lp_at_zero - 30,
                  info = sprintf("y=%d al=%g  lp=%.3f vs lp(0)=%.3f",
                                 y, al, lp_pkg, lp_at_zero))
    }
  }
})

# ---- Efficiency-score correctness -------------------------------------------

test_that("Cost efficiency scores lie in (0, 1] (alpha = 1)", {
  set.seed(1L)
  n <- 50L
  X <- cbind(1, rnorm(n))
  u <- rexp(n, rate = 2)
  y <- rpois(n, exp(drop(X %*% c(1, 0.5)) + u))
  fit <- structure(
    list(coefficients = setNames(c(1, 0.5), colnames(X)),
         b = 2, alpha = 1, orientation = "cost"),
    class = "poisson_frontier"
  )
  sc <- efficiency_scores(fit, y, X)
  expect_true(all(is.na(sc$eff_score) | (sc$eff_score > 0 & sc$eff_score <= 1)))
})

test_that("Cost efficiency scores lie in (0, 1] (alpha = 2)", {
  set.seed(2L)
  n <- 50L
  X <- cbind(1, rnorm(n))
  u <- rgamma(n, shape = 2, rate = 2)
  y <- rpois(n, exp(drop(X %*% c(1, 0.5)) + u))
  fit <- structure(
    list(coefficients = setNames(c(1, 0.5), colnames(X)),
         b = 2, alpha = 2, orientation = "cost"),
    class = "poisson_frontier"
  )
  sc <- suppressWarnings(efficiency_scores(fit, y, X))
  expect_true(all(is.na(sc$eff_score) | (sc$eff_score > 0 & sc$eff_score <= 1)))
})

test_that("Cost efficiency score continuity at alpha = 1 boundary", {
  # The closed-form cost path requires y - b > 2 (so y - b - 2 > 0); just
  # above that boundary the alpha = 1 + eps branch must agree.
  X <- cbind(1, 0)
  y <- 6L  # y - b = 4 > 2
  fit_eq <- structure(
    list(coefficients = setNames(c(log(8), 0), colnames(X)),
         b = 2, alpha = 1, orientation = "cost"),
    class = "poisson_frontier"
  )
  fit_eps <- fit_eq; fit_eps$alpha <- 1 + 1e-7
  sc_eq  <- efficiency_scores(fit_eq,  y, X)
  sc_eps <- suppressWarnings(efficiency_scores(fit_eps, y, X))
  expect_equal(sc_eps$eff_score, sc_eq$eff_score, tolerance = 1e-4)
})

# ---- End-to-end fit recovery ------------------------------------------------

test_that("Exp-cost frontier MLE recovers parameters within sampling noise", {
  skip_on_cran()  # cost-orientation MLE invokes per-observation quadrature
  set.seed(3L)
  n <- 1000L
  z <- rnorm(n); X <- cbind(1, z)
  u <- rexp(n, rate = 2)             # b = 2
  y <- rpois(n, exp(drop(X %*% c(1, 0.5)) + u))   # COST: + u
  fit <- suppressWarnings(
    fit_poisson_frontier(y, X, dist = "exponential", orientation = "cost")
  )
  expect_equal(fit$convergence, 0L)
  expect_equal(unname(fit$coefficients[1]), 1.0, tolerance = 0.10)
  expect_equal(unname(fit$coefficients[2]), 0.5, tolerance = 0.10)
  expect_equal(fit$b,                       2.0, tolerance = 0.30)
})
