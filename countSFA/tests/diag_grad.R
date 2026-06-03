# Diagnose the alpha<1 discrepancy: is it my moment quadrature, the
# objective's PMF quadrature, or numDeriv noise?
source("R/pmf.R"); source("R/log_lik.R"); source("R/grad.R")
suppressMessages(library(numDeriv))

set.seed(42L)
n  <- 250L
X  <- cbind(1, rnorm(n), rnorm(n))
u  <- rgamma(n, shape = 2, rate = 1.5)
y  <- rpois(n, lambda = exp(drop(X %*% c(1.2, 0.4, -0.3)) - u))
p  <- c(0.8, 0.2, -0.1, log(0.7), log(0.5))   # the failing alpha=0.5 point

obj <- function(q) log_lik_poisson_frontier(q, y, X, alpha = NULL,
                                             orientation = "production")
g_an <- grad_loglik_poisson_frontier(p, y, X, alpha = NULL,
                                      orientation = "production")

# Central differences with a sweep of h, per component, to find the true
# derivative and the objective's noise floor.
cdiff <- function(idx, h) {
  pp <- p; pm <- p
  pp[idx] <- pp[idx] + h; pm[idx] <- pm[idx] - h
  (obj(pp) - obj(pm)) / (2 * h)
}
cat("Component-wise: analytic vs central differences over h\n")
hs <- c(1e-2, 3e-3, 1e-3, 3e-4, 1e-4, 3e-5, 1e-5)
for (idx in seq_along(p)) {
  cat(sprintf("\n  param[%d]  analytic = % .6f\n", idx, g_an[idx]))
  for (h in hs) {
    cat(sprintf("    h=%.0e  cd=% .6f  (diff %+.2e)\n",
                h, cdiff(idx, h), cdiff(idx, h) - g_an[idx]))
  }
}

# Independent gold-standard moments for a few single observations:
# integrate each moment over (0, Inf) with a singularity-splitting strategy
# and very tight tolerance, in the SAME kernel.
gold_moments <- function(yi, ai, bi, alpha) {
  log_g <- function(uu) (alpha - 1) * log(uu) - (yi + bi) * uu - exp(ai - uu)
  # robust normaliser via log-max on a fine adaptive grid
  ug <- exp(seq(log(1e-8), log(200), length.out = 4000L))
  lv <- log_g(ug); lv[!is.finite(lv)] <- -Inf
  lm <- max(lv)
  f  <- function(uu) exp(log_g(uu) - lm)
  # split at 1 to isolate the u->0 singularity for alpha<1
  G0 <- integrate(f, 0, 1, rel.tol = 1e-10, subdivisions = 2000L)$value +
        integrate(f, 1, 250, rel.tol = 1e-10, subdivisions = 2000L)$value
  Gu <- integrate(function(uu) uu * f(uu), 0, 1, rel.tol = 1e-10, subdivisions = 2000L)$value +
        integrate(function(uu) uu * f(uu), 1, 250, rel.tol = 1e-10, subdivisions = 2000L)$value
  Gl <- integrate(function(uu) { v <- log(uu)*f(uu); v[!is.finite(v)] <- 0; v }, 0, 1, rel.tol = 1e-10, subdivisions = 2000L)$value +
        integrate(function(uu) { v <- log(uu)*f(uu); v[!is.finite(v)] <- 0; v }, 1, 250, rel.tol = 1e-10, subdivisions = 2000L)$value
  Ge <- integrate(function(uu) exp(-uu) * f(uu), 0, 1, rel.tol = 1e-10, subdivisions = 2000L)$value +
        integrate(function(uu) exp(-uu) * f(uu), 1, 250, rel.tol = 1e-10, subdivisions = 2000L)$value
  list(Eu = Gu/G0, Elogu = Gl/G0, m = exp(ai) * Ge/G0)
}

cat("\n\nMoment check (my .grad_moments_production vs gold) for 6 obs at alpha=0.5:\n")
a <- drop(X %*% p[1:3]); bi <- exp(p[4]); al <- exp(p[5])
for (i in c(1, 5, 10, 50, 100, 200)) {
  mine <- .grad_moments_production(y[i], a[i], bi, al)
  gold <- gold_moments(y[i], a[i], bi, al)
  cat(sprintf("  obs %3d (y=%2d, a=% .2f): Eu mine=% .5f gold=% .5f | Elogu mine=% .5f gold=% .5f | m mine=% .5f gold=% .5f\n",
              i, y[i], a[i], mine$Eu, gold$Eu, mine$Elogu, gold$Elogu, mine$m, gold$m))
}
