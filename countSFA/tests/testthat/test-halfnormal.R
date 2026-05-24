test_that("pmf_poisson_halfnormal sums to ~1 over y = 0:30", {
  a     <- 1.0
  sigma <- 0.6
  log_p <- vapply(0:30, function(y)
    pmf_poisson_halfnormal(y, a = a, sigma = sigma, R = 500),
    numeric(1L))
  total <- sum(exp(log_p))
  expect_true(abs(total - 1) < 5e-3,
              info = sprintf("sum of PMF = %.6f", total))
})


test_that("fit_poisson_halfnormal recovers a known DGP", {
  skip_on_cran()  # ~30s on a fast laptop; can exceed CRAN budget
  set.seed(42L)
  n     <- 500L
  beta  <- c(1.0, 0.5)
  sigma <- 0.7
  X     <- cbind(1, rnorm(n))
  u     <- abs(rnorm(n, sd = sigma))
  y     <- rpois(n, exp(drop(X %*% beta) - u))

  fit <- fit_poisson_halfnormal(y, X, R = 200)
  expect_s3_class(fit, "poisson_halfnormal")
  expect_s3_class(fit, "poisson_frontier")
  expect_true(is.finite(fit$loglik))
  expect_true(is.finite(fit$sigma) && fit$sigma > 0)
  expect_lt(abs(fit$sigma - sigma), 0.2)
  expect_lt(abs(unname(fit$coefficients[2]) - beta[2]), 0.1)
})


test_that("compare_models works across exp + halfnormal fits", {
  skip_on_cran()  # half-normal MLE is slow; covered locally
  set.seed(7L)
  n  <- 250L
  X  <- cbind(1, rnorm(n))
  u  <- rexp(n, rate = 2)
  y  <- rpois(n, exp(drop(X %*% c(1, 0.5)) - u))

  fit_exp <- fit_poisson_frontier(y, X, dist = "exponential")
  fit_hn  <- fit_poisson_halfnormal(y, X, R = 100)

  cmp <- compare_models(list(Exp = fit_exp, HN = fit_hn))
  expect_s3_class(cmp, "data.frame")
  expect_equal(nrow(cmp), 2L)
  expect_true(all(c("Model", "Distribution", "alpha", "b",
                    "Npar", "LogLik", "AIC", "BIC", "Converged")
                  %in% colnames(cmp)))
})
