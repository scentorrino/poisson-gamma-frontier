test_that("compare_models returns valid data.frame", {
  skip_on_cran()  # Gamma frontier MLE is slow; covered locally.
  set.seed(1L)
  n_sim  <- 200L
  X_sim  <- cbind(1, rnorm(n_sim))
  u_sim  <- rexp(n_sim, rate = 2)
  y_sim  <- rpois(n_sim, exp(drop(X_sim %*% c(1, 0.5)) - u_sim))

  fit_exp <- fit_poisson_frontier(y_sim, X_sim, dist = "exponential")
  fit_gam <- fit_poisson_frontier(y_sim, X_sim, dist = "gamma")

  cmp <- compare_models(list(fit_exp, fit_gam), names = c("Exponential", "Gamma"))
  expect_true(is.data.frame(cmp))
  expect_equal(nrow(cmp), 2L)
  expect_true(all(c("Model", "LogLik", "AIC", "BIC") %in% names(cmp)))
})

test_that("summary.poisson_frontier runs cleanly", {
  set.seed(1L)
  n_sim  <- 200L
  X_sim  <- cbind(1, rnorm(n_sim))
  u_sim  <- rexp(n_sim, rate = 2)
  y_sim  <- rpois(n_sim, exp(drop(X_sim %*% c(1, 0.5)) - u_sim))

  fit_exp <- fit_poisson_frontier(y_sim, X_sim, dist = "exponential")
  tbl <- summary(fit_exp)
  expect_true(is.data.frame(tbl))
  expect_true("Parameter" %in% names(tbl))
})
