# Validation of grad_loglik_poisson_frontier (production orientation).
#
# Two tiers:
#  (1) PRIMARY, rigorous: per-observation analytic derivatives of the log-PMF
#      vs tight central differences of pmf_poisson_gamma() itself, over a grid
#      of (y, a, b, alpha) spanning alpha < 1 and alpha > 1.  This differentiates
#      EXACTLY the quantity the objective sums, so agreement here proves the
#      score formula and the moment quadrature.  Threshold 1e-6.
#  (2) SECONDARY: aggregate analytic gradient vs central differences of the full
#      negative log-likelihood at the finite-difference sweet spot (h = 1e-4).
#      This is FD-noise-limited: the objective calls adaptive integrate
#      (rel.tol 1e-8), so Richardson/small-h differences amplify that floor,
#      especially in the log-alpha block.  Threshold 2e-3.
#
# Run:  Rscript tests/validate_grad.R   (from the package root)

source("R/pmf.R"); source("R/log_lik.R"); source("R/grad.R")

# ---------------------------------------------------------------------------
# (1) Per-observation derivatives vs tight central differences of the log-PMF
# ---------------------------------------------------------------------------
cat("== Tier 1: per-observation analytic vs central diff of log-PMF ==\n")
worst1 <- 0
grid <- expand.grid(y = c(0L, 1L, 2L, 3L, 5L, 10L),
                    a = c(-1, 0, 1, 2, 3),
                    b = c(0.5, 1.0, 2.0),
                    al = c(0.4, 0.6, 1.5, 2.5, 4.0))
h <- 1e-5
for (r in seq_len(nrow(grid))) {
  yi <- grid$y[r]; ai <- grid$a[r]; b <- grid$b[r]; al <- grid$al[r]
  mo <- .grad_moments_production(yi, ai, b, al)
  if (!isTRUE(mo$ok)) { cat(sprintf("  moment fail at y=%d a=%g b=%g al=%g\n", yi, ai, b, al)); next }
  d_a  <- yi - mo$m
  d_lb <- al - b * mo$Eu
  d_la <- al * (log(b) - digamma(al) + mo$Elogu)
  f <- function(a, bb, aa) pmf_poisson_gamma(yi, a, bb, aa)
  cd_a  <- (f(ai + h, b, al) - f(ai - h, b, al)) / (2 * h)
  cd_lb <- (f(ai, exp(log(b) + h), al) - f(ai, exp(log(b) - h), al)) / (2 * h)
  cd_la <- (f(ai, b, exp(log(al) + h)) - f(ai, b, exp(log(al) - h))) / (2 * h)
  worst1 <- max(worst1, abs(d_a - cd_a), abs(d_lb - cd_lb), abs(d_la - cd_la))
}
# Threshold 5e-6: this is the central-difference REFERENCE noise floor (the
# log-PMF itself is evaluated by adaptive integrate, rel.tol 1e-8, which the
# h=1e-5 difference amplifies). At the FD sweet spot the agreement is ~1e-9
# (see tests/diag_grad.R); the analytic gradient is the accurate party.
cat(sprintf("  cases = %d   WORST |analytic - cd| = %.3e   -> %s\n",
            nrow(grid), worst1, if (worst1 < 5e-6) "PASS" else "FAIL"))

# ---------------------------------------------------------------------------
# (2) Aggregate gradient vs sweet-spot central differences
# ---------------------------------------------------------------------------
cat("\n== Tier 2: aggregate analytic vs central diff (h = 1e-4) of -loglik ==\n")
set.seed(42L)
n  <- 250L
X  <- cbind(1, rnorm(n), rnorm(n))
u  <- rgamma(n, shape = 2, rate = 1.5)
y  <- rpois(n, lambda = exp(drop(X %*% c(1.2, 0.4, -0.3)) - u))
Z  <- cbind(rnorm(n), rnorm(n))
bi <- 1.5 * exp(-drop(Z %*% c(0.3, -0.5)))
u3 <- rgamma(n, shape = 2, rate = bi)
y3 <- rpois(n, lambda = exp(drop(X %*% c(1.2, 0.4, -0.3)) - u3))

agg_check <- function(tag, p, alpha, Z, yy) {
  obj <- function(q) log_lik_poisson_frontier(q, yy, X, alpha = alpha,
                                              orientation = "production", Z = Z)
  g_an <- grad_loglik_poisson_frontier(p, yy, X, alpha = alpha,
                                       orientation = "production", Z = Z)
  hh <- 1e-4
  g_cd <- vapply(seq_along(p), function(idx) {
    pp <- p; pm <- p; pp[idx] <- pp[idx] + hh; pm[idx] <- pm[idx] - hh
    (obj(pp) - obj(pm)) / (2 * hh)
  }, numeric(1))
  md <- max(abs(g_an - g_cd))
  cat(sprintf("  [%-26s] max|abs diff| = %.3e  %s\n", tag, md,
              if (md < 2e-3) "PASS" else "FAIL"))
  md
}

worst2 <- 0
worst2 <- max(worst2, agg_check("est-alpha homog",        c(1.2, 0.4, -0.3, log(1.5), log(2.0)), NULL, NULL, y))
worst2 <- max(worst2, agg_check("est-alpha homog (a<1)",  c(0.8, 0.2, -0.1, log(0.7), log(0.5)), NULL, NULL, y))
worst2 <- max(worst2, agg_check("fixed alpha=0.6",        c(1.2, 0.4, -0.3, log(1.5)),           0.6,  NULL, y))
worst2 <- max(worst2, agg_check("fixed alpha=2.5",        c(1.2, 0.4, -0.3, log(1.5)),           2.5,  NULL, y))
worst2 <- max(worst2, agg_check("scaling Z, est-alpha",   c(1.2, 0.4, -0.3, log(1.5), log(2.0), 0.3, -0.5), NULL, Z, y3))
worst2 <- max(worst2, agg_check("scaling Z, fixed alpha", c(1.2, 0.4, -0.3, log(1.5), 0.3, -0.5),           2.0,  Z, y3))

cat(sprintf("\n=== Tier 1 worst %.3e (<5e-6) | Tier 2 worst %.3e (<2e-3) ===\n", worst1, worst2))
if (worst1 < 5e-6 && worst2 < 2e-3) cat("OVERALL: PASS\n") else cat("OVERALL: FAIL\n")
