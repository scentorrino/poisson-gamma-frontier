test_that("fit_poisson_frontier returns correct class and fields", {
  set.seed(1L)
  n_sim  <- 200L
  X_sim  <- cbind(1, rnorm(n_sim))
  u_sim  <- rexp(n_sim, rate = 2)
  y_sim  <- rpois(n_sim, exp(drop(X_sim %*% c(1, 0.5)) - u_sim))

  fit_exp <- fit_poisson_frontier(y_sim, X_sim, dist = "exponential")
  expect_s3_class(fit_exp, "poisson_frontier")
  expect_true(all(c("coefficients", "se", "b", "se_b", "alpha",
                    "loglik", "AIC", "BIC", "vcov", "convergence") %in% names(fit_exp)))
  expect_equal(fit_exp$alpha, 1)
  expect_true(is.finite(fit_exp$loglik))

  skip_on_cran()  # Gamma fit is slower; cheap exp branch above always runs.
  fit_gam <- fit_poisson_frontier(y_sim, X_sim, dist = "gamma")
  expect_s3_class(fit_gam, "poisson_frontier")
  expect_true(is.finite(fit_gam$alpha) && fit_gam$alpha > 0)
})
