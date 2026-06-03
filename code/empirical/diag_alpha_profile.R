# Non-destructive diagnostic: profile the empirical cost-frontier log-likelihood
# in the Gamma shape alpha for the homogeneous model (M3), to determine whether
# alpha has an interior maximum or the likelihood pushes it toward degeneracy.
#
# The cost-orientation PMF is evaluated by adaptive numerical quadrature
# (countSFA:::.log_pmf_cost via pmf_poisson_gamma); there is no series and no
# truncation parameter to set. Reads results/cwa_fits.rds for X, y, and warm
# starts. Writes ONLY results/diag_alpha_profile.rds + stdout; does not touch
# canonical caches.

suppressPackageStartupMessages(library(countSFA))

emp <- readRDS("results/cwa_fits.rds")
X <- emp$X
y <- as.integer(emp$y)
k <- ncol(X)

beta_warm <- emp$fit_exp$par[1:k]
logb_warm <- log(emp$fit_exp$b)

# NLL at fixed alpha, optimised over (beta, log_b), cost orientation, quadrature.
profile_one <- function(alpha_val, start) {
  obj <- function(p) {
    v <- suppressWarnings(
      log_lik_poisson_frontier(p, y, X, alpha = alpha_val,
                               orientation = "cost"))
    if (!is.finite(v) || v >= .Machine$double.xmax * 0.5) return(1e8)
    v
  }
  opt <- optim(start, obj, method = "L-BFGS-B",
               lower = c(rep(-30, k), -5), upper = c(rep(30, k), 8),
               control = list(maxit = 2000, factr = 1e8))
  list(alpha = alpha_val, loglik = -opt$value, log_b = opt$par[k + 1L],
       par = opt$par, conv = opt$convergence)
}

# Grid spans the old M3 boundary (alpha=7.39) and well beyond, to see the shape.
alphas <- c(1, 1.5, 2, 3, 5, 7.389, 10, 15, 20, 30, 50, 80)

cat(sprintf("Profiling M3 (homogeneous Gamma, cost, adaptive quadrature) over %d alpha values, n=%d\n\n",
            length(alphas), length(y)))
cat(sprintf("%8s %14s %10s %6s\n", "alpha", "loglik", "log_b", "conv"))

start <- c(beta_warm, logb_warm)
res <- vector("list", length(alphas))
for (i in seq_along(alphas)) {
  r <- profile_one(alphas[i], start)
  start <- r$par                       # warm-chain to next alpha
  res[[i]] <- r
  cat(sprintf("%8.3f %14.4f %10.4f %6d\n", r$alpha, r$loglik, r$log_b, r$conv))
}

prof <- data.frame(
  alpha  = vapply(res, `[[`, numeric(1), "alpha"),
  loglik = vapply(res, `[[`, numeric(1), "loglik"),
  log_b  = vapply(res, `[[`, numeric(1), "log_b")
)
best <- prof[which.max(prof$loglik), ]
cat(sprintf("\nProfile max at alpha=%.3f (loglik=%.4f).\n", best$alpha, best$loglik))
cat(sprintf("Old M3 reported: alpha=7.389 (log_alpha=2, AT BOUND), loglik=%.4f\n",
            emp$fit_gam$loglik))
if (best$alpha == max(prof$alpha)) {
  cat("VERDICT: profile is still increasing at the largest alpha tried -> NO interior max;",
      "the Gamma shape diverges toward degeneracy. The 'interior-mode' claim is NOT supported.\n")
} else {
  cat(sprintf("VERDICT: interior maximum near alpha=%.2f -> alpha IS interior once the bound is widened.\n",
              best$alpha))
}

saveRDS(list(profile = prof, best = best, old_m3_ll = emp$fit_gam$loglik),
        "results/diag_alpha_profile.rds")
cat("\nSaved results/diag_alpha_profile.rds\n")
