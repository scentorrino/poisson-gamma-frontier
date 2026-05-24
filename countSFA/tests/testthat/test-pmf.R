test_that("PMF sums to 1 for alpha = 1", {
  a_test <- 1.5; b_test <- 2.0
  y_grid <- 0:30
  log_probs <- vapply(y_grid, pmf_poisson_gamma,
                      numeric(1), a = a_test, b = b_test, alpha = 1)
  total_prob <- sum(exp(log_probs))
  expect_equal(total_prob, 1, tolerance = 1e-4)
})

test_that("PMF sums to 1 for alpha = 2", {
  a_test <- 1.5; b_test <- 2.0
  y_grid <- 0:30
  log_probs2 <- vapply(y_grid, pmf_poisson_gamma,
                       numeric(1), a = a_test, b = b_test, alpha = 2, K = 150)
  total_prob2 <- sum(exp(log_probs2))
  expect_equal(total_prob2, 1, tolerance = 5e-3)
})

test_that("Series (alpha = 1 + eps) matches closed-form", {
  a_test <- 1.5; b_test <- 2.0
  eps <- 1e-6
  lp_series <- pmf_poisson_gamma(3, a_test, b_test, alpha = 1 + eps, K = 200)
  lp_closed <- pmf_poisson_gamma(3, a_test, b_test, alpha = 1)
  expect_equal(lp_series, lp_closed, tolerance = 1e-4)
})
