# Validation of grad_loglik_poisson_frontier for the COST orientation.
# Mirrors tests/validate_grad.R.
#  (1) per-observation analytic vs tight central diff of the cost log-PMF.
#  (2) aggregate gradient vs sweet-spot central diff of the cost -loglik.
# Run:  Rscript tests/validate_grad_cost.R   (from package root)

source("R/pmf.R"); source("R/log_lik.R"); source("R/grad.R")

cat("== Tier 1: per-observation analytic vs central diff of COST log-PMF ==\n")
worst1 <- 0
# cost needs the integral to be well-behaved; span y-b both signs, alpha </> 1.
grid <- expand.grid(y = c(0L, 1L, 3L, 8L, 15L),
                    a = c(-0.5, 0.5, 1.5),
                    b = c(0.5, 2.0, 5.0),
                    al = c(0.4, 0.7, 1.5, 3.0))
h <- 1e-5
fails <- 0L
for (r in seq_len(nrow(grid))) {
  yi <- grid$y[r]; ai <- grid$a[r]; b <- grid$b[r]; al <- grid$al[r]
  mo <- .grad_moments_cost(yi, ai, b, al)
  if (!isTRUE(mo$ok)) { fails <- fails + 1L; next }
  d_a  <- yi - mo$m
  d_lb <- al - b * mo$Eu
  d_la <- al * (log(b) - digamma(al) + mo$Elogu)
  f <- function(a, bb, aa) pmf_poisson_gamma(yi, a, bb, aa, orientation = "cost")
  cd_a  <- (f(ai + h, b, al) - f(ai - h, b, al)) / (2 * h)
  cd_lb <- (f(ai, exp(log(b) + h), al) - f(ai, exp(log(b) - h), al)) / (2 * h)
  cd_la <- (f(ai, b, exp(log(al) + h)) - f(ai, b, exp(log(al) - h))) / (2 * h)
  worst1 <- max(worst1, abs(d_a - cd_a), abs(d_lb - cd_lb), abs(d_la - cd_la))
}
cat(sprintf("  cases = %d (moment fails: %d)   WORST |analytic - cd| = %.3e   -> %s\n",
            nrow(grid), fails, worst1, if (worst1 < 5e-6) "PASS" else "FAIL"))

cat("\n== Tier 2: aggregate analytic vs central diff (h=1e-4) of cost -loglik ==\n")
set.seed(123L)
n  <- 250L
X  <- cbind(1, rnorm(n), rnorm(n))
u  <- rgamma(n, shape = 2, rate = 1.5)
y  <- rpois(n, lambda = exp(drop(X %*% c(0.5, 0.3, -0.2)) + u))   # cost: +u
Z  <- cbind(rnorm(n), rnorm(n))
bi <- 1.5 * exp(-drop(Z %*% c(0.3, -0.5)))
u3 <- rgamma(n, shape = 2, rate = bi)
y3 <- rpois(n, lambda = exp(drop(X %*% c(0.5, 0.3, -0.2)) + u3))

agg <- function(tag, p, alpha, Z, yy) {
  obj <- function(q) log_lik_poisson_frontier(q, yy, X, alpha = alpha,
                                              orientation = "cost", Z = Z)
  g_an <- grad_loglik_poisson_frontier(p, yy, X, alpha = alpha,
                                       orientation = "cost", Z = Z)
  hh <- 1e-4
  g_cd <- vapply(seq_along(p), function(idx) {
    pp <- p; pm <- p; pp[idx] <- pp[idx] + hh; pm[idx] <- pm[idx] - hh
    (obj(pp) - obj(pm)) / (2 * hh)
  }, numeric(1))
  md <- max(abs(g_an - g_cd))
  cat(sprintf("  [%-24s] max|abs diff| = %.3e  %s\n", tag, md,
              if (md < 2e-3) "PASS" else "FAIL"))
  md
}

worst2 <- 0
worst2 <- max(worst2, agg("est-alpha homog",      c(0.5, 0.3, -0.2, log(1.5), log(2.0)), NULL, NULL, y))
worst2 <- max(worst2, agg("fixed alpha=0.6",      c(0.5, 0.3, -0.2, log(1.5)),           0.6,  NULL, y))
worst2 <- max(worst2, agg("fixed alpha=3.0",      c(0.5, 0.3, -0.2, log(1.5)),           3.0,  NULL, y))
worst2 <- max(worst2, agg("scaling Z, est-alpha", c(0.5, 0.3, -0.2, log(1.5), log(2.0), 0.3, -0.5), NULL, Z, y3))
worst2 <- max(worst2, agg("scaling Z, fixed alpha",c(0.5, 0.3, -0.2, log(1.5), 0.3, -0.5),          2.0,  Z, y3))

cat(sprintf("\n=== Tier 1 worst %.3e (<5e-6) | Tier 2 worst %.3e (<2e-3) ===\n", worst1, worst2))
if (worst1 < 5e-6 && worst2 < 2e-3) cat("OVERALL: PASS\n") else cat("OVERALL: FAIL\n")
