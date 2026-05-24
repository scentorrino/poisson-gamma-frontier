test_that("efficiency_scores returns valid data.frame", {
  set.seed(1L)
  n_sim  <- 200L
  X_sim  <- cbind(1, rnorm(n_sim))
  u_sim  <- rexp(n_sim, rate = 2)
  y_sim  <- rpois(n_sim, exp(drop(X_sim %*% c(1, 0.5)) - u_sim))

  fit_exp <- fit_poisson_frontier(y_sim, X_sim, dist = "exponential")

  es <- efficiency_scores(fit_exp, y_sim, X_sim)
  expect_true(is.data.frame(es))
  expect_true(all(c("i", "eff_score", "eff_lower", "eff_upper") %in% names(es)))
  expect_equal(nrow(es), n_sim)
  expect_true(all(es$eff_score > 0 & es$eff_score < 1, na.rm = TRUE))
  expect_true(all(es$eff_lower <= es$eff_score + 1e-9, na.rm = TRUE))
  expect_true(all(es$eff_upper >= es$eff_score - 1e-9, na.rm = TRUE))
})
