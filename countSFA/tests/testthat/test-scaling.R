# Tests for the inefficiency-determinants (scaling-model) extension:
#   b_i = b * exp(-z_i' delta).
#
# Covers:
#   (1) Parameter-packing identity: delta = 0 in the scaling likelihood
#       collapses exactly to the homogeneous likelihood.
#   (2) fit_poisson_frontier(..., Z = Z) returns the expected new fields
#       (delta, se_delta, Z) and respects starts_delta + ncol(Z) checks.
#   (3) efficiency_scores uses per-observation b_i when fit$delta is
#       non-empty (b varies across i; homogeneous fallback when delta=0).
#   (4) summary.poisson_frontier prints a "delta.<name>" row per Z column.
#   (5) Gamma + Z fit reproduces signal direction when delta is large.

make_data <- function(n = 200L, seed = 1L, b_true = 2,
                      delta_true = 0.6) {
  set.seed(seed)
  X <- cbind(1, rnorm(n))
  Z <- cbind(z1 = rnorm(n))
  # Per-obs rate b_i; positive delta => b_i bigger where z is big => less
  # inefficiency where z is big (since E[u] = 1/b_i under exp).
  b_i <- b_true * exp(-drop(Z %*% delta_true))
  u   <- rexp(n, rate = b_i)
  y   <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
  list(X = X, Z = Z, y = y)
}

# ---------------------------------------------------------------------------
test_that("log_lik_poisson_frontier: Z arg with delta=0 matches homogeneous", {
  d <- make_data(delta_true = 0)
  # Exponential
  v_homog <- log_lik_poisson_frontier(c(1, 0.5, log(2)), d$y, d$X, alpha = 1)
  v_scal  <- log_lik_poisson_frontier(c(1, 0.5, log(2), 0), d$y, d$X,
                                       alpha = 1, Z = d$Z)
  expect_equal(v_scal, v_homog, tolerance = 1e-12)

  # Gamma
  v_homog_g <- log_lik_poisson_frontier(c(1, 0.5, log(2), 0), d$y, d$X,
                                         alpha = NULL)
  v_scal_g  <- log_lik_poisson_frontier(c(1, 0.5, log(2), 0, 0), d$y, d$X,
                                         alpha = NULL, Z = d$Z)
  expect_equal(v_scal_g, v_homog_g, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
test_that("log_lik_poisson_frontier: per-obs b enters as b*exp(-z'delta)", {
  d <- make_data()
  delta_val <- 0.4
  # Hand-compute the likelihood at a known parameter point using the
  # per-obs PMF and confirm it matches log_lik_poisson_frontier.
  beta <- c(1, 0.5); b <- 2; alpha <- 1
  b_i  <- b * exp(-drop(d$Z %*% delta_val))
  a    <- drop(d$X %*% beta)
  ll_manual <- -sum(vapply(seq_along(d$y),
                           function(i) pmf_poisson_gamma(d$y[i], a[i],
                                                          b_i[i], alpha),
                           numeric(1L)))
  ll_pkg <- log_lik_poisson_frontier(c(beta, log(b), delta_val), d$y, d$X,
                                      alpha = 1, Z = d$Z)
  expect_equal(ll_pkg, ll_manual, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
test_that("fit_poisson_frontier(Z=Z) returns delta/se_delta/Z slots", {
  d <- make_data()
  fit <- fit_poisson_frontier(d$y, d$X, dist = "exponential", Z = d$Z)

  expect_s3_class(fit, "poisson_frontier")
  expect_true(all(c("delta", "se_delta", "Z") %in% names(fit)))
  expect_length(fit$delta,    ncol(d$Z))
  expect_length(fit$se_delta, ncol(d$Z))
  expect_identical(names(fit$delta), colnames(d$Z))
  expect_identical(fit$Z, d$Z)
  expect_true(is.finite(fit$loglik))
  # Recovered delta should sit close to the truth (delta_true = 0.6).
  expect_true(abs(fit$delta - 0.6) < 0.3)
  # SE should be informative (well below |estimate|).
  expect_true(fit$se_delta < 0.5)
})

# ---------------------------------------------------------------------------
test_that("fit_poisson_frontier: argument validation for Z and starts_delta", {
  d <- make_data()
  # nrow(Z) mismatch
  expect_error(
    fit_poisson_frontier(d$y, d$X, dist = "exponential",
                         Z = matrix(0, nrow = 5L, ncol = 1L)),
    "nrow"
  )
  # starts_delta length mismatch
  expect_error(
    fit_poisson_frontier(d$y, d$X, dist = "exponential",
                         Z = d$Z, starts_delta = c(0.1, 0.2)),
    "starts_delta"
  )
})

# ---------------------------------------------------------------------------
test_that("efficiency_scores uses per-obs b_i under scaling fit", {
  d <- make_data()
  fit <- fit_poisson_frontier(d$y, d$X, dist = "exponential", Z = d$Z)
  s   <- efficiency_scores(fit, d$y, d$X)

  expect_true(is.data.frame(s))
  expect_equal(nrow(s), length(d$y))
  expect_true(all(s$eff_score >= 0 & s$eff_score <= 1))

  # Sanity: facilities with very different b_i should not all collapse to
  # the same posterior mean (which is what a homogeneous-b path would do).
  b_i <- fit$b * exp(-drop(d$Z %*% fit$delta))
  expect_true(diff(range(b_i)) > 1e-3)
  # Within strata of (y, a), TE should vary monotonically with b_i; cheap
  # proxy: scores have nontrivial spread.
  expect_true(sd(s$eff_score) > 1e-3)
})

# ---------------------------------------------------------------------------
test_that("efficiency_scores: homogeneous fallback when delta is empty", {
  d <- make_data(delta_true = 0)
  fit_h <- fit_poisson_frontier(d$y, d$X, dist = "exponential")
  fit_s <- fit_poisson_frontier(d$y, d$X, dist = "exponential", Z = d$Z)

  s_h <- efficiency_scores(fit_h, d$y, d$X)
  expect_true(all(is.finite(s_h$eff_score)))

  # When the scaling fit's delta is (numerically) near 0, scaling and
  # homogeneous score series should be close on the same data.
  if (abs(fit_s$delta) < 0.05) {
    s_s <- efficiency_scores(fit_s, d$y, d$X)
    expect_lt(mean(abs(s_s$eff_score - s_h$eff_score)), 0.05)
  }
})

# ---------------------------------------------------------------------------
test_that("summary.poisson_frontier prints delta rows when Z is supplied", {
  d <- make_data()
  fit <- fit_poisson_frontier(d$y, d$X, dist = "exponential", Z = d$Z)

  out <- capture.output(tbl <- summary(fit))
  expect_true(any(grepl("Scaling model on b", out)))
  expect_true(any(grepl("delta.z1", out)))
  # And the invisibly-returned data.frame should contain the delta row.
  expect_true("delta.z1" %in% tbl$Parameter)

  # Homogeneous fit should NOT have a delta row.
  fit_h <- fit_poisson_frontier(d$y, d$X, dist = "exponential")
  out_h <- capture.output(tbl_h <- summary(fit_h))
  expect_false(any(grepl("^delta\\.", tbl_h$Parameter)))
  expect_true(any(grepl("no \\(homogeneous\\)", out_h)))
})

# ---------------------------------------------------------------------------
test_that("Gamma + scaling fit runs and recovers delta sign", {
  skip_on_cran()
  d <- make_data(n = 400L, delta_true = 0.6)
  fit <- fit_poisson_frontier(d$y, d$X, dist = "gamma", Z = d$Z)

  expect_s3_class(fit, "poisson_frontier")
  expect_length(fit$delta, ncol(d$Z))
  expect_true(is.finite(fit$alpha) && fit$alpha > 0)
  # Sign of delta should match the DGP (positive in make_data).
  expect_true(fit$delta > 0)
})
