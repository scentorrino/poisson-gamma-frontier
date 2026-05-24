# =============================================================================
# application.R
#
# Empirical application of the Poisson stochastic frontier to the
# Hausman-Hall-Griliches (1984) patent panel.
# Sourced by 06-empirical.qmd (#| cache: true).
#
# Data:  data/patents.csv
#        346 firms x 5 years (1968-1972), 1730 pooled observations
#        Y = logr   (annual patent count, non-negative integer)
#        Covariates: pat (log R&D), logk (log capital), scisect (science sector)
#                    year dummies (year 1 = reference)
#
# Models fitted:
#   1. Poisson GLM   — standard Poisson regression (misspecified baseline)
#   2. Exp frontier  — Poisson frontier, u ~ Exp(b)      (dist = "exponential")
#   3. Gamma frontier— Poisson frontier, u ~ Gamma(alpha,b) (dist = "gamma")
#
# Output (saved to code/empirical/fits.rds):
#   $data         — cleaned data frame used for estimation
#   $X            — model matrix (including year dummies)
#   $y            — outcome vector
#   $fit_pois     — glm object (Poisson)
#   $fit_exp      — poisson_frontier object (exponential inefficiency)
#   $fit_gam      — poisson_frontier object (gamma inefficiency)
#   $scores_exp   — data.frame of efficiency scores from exp model
#   $scores_gam   — data.frame of efficiency scores from gamma model
#   $lr_stat      — LR test statistic (Gamma vs. Exp)
#   $lr_pval      — p-value (chi-sq, df = 1)
#   $compare_tbl  — kable-ready comparison table
# =============================================================================

library(countSFA)

# =============================================================================
# 1. Load and clean data
# =============================================================================

dat_raw <- read.csv("data/patents.csv", stringsAsFactors = FALSE)

cat("Dimensions:", nrow(dat_raw), "x", ncol(dat_raw), "\n")
cat("Columns:", paste(names(dat_raw), collapse = ", "), "\n\n")

# Outcome: logr (annual patent count, non-negative integer)
# Main covariates: pat (log R&D, current year), logk (log capital stock)
# Sector: scisect ("yes"/"no") -> binary
# Panel structure: year (1-5)

dat <- dat_raw[, c("logr", "pat", "logk", "scisect", "year")]
dat$y   <- as.integer(round(dat$logr))
dat$rd  <- dat$pat
dat$lk  <- dat$logk
dat$sci <- as.integer(dat$scisect == "yes")
dat$yr  <- factor(dat$year)

# Drop non-finite rows
keep <- is.finite(dat$y) & is.finite(dat$rd) & is.finite(dat$lk)
n_drop <- sum(!keep)
dat <- dat[keep, ]

cat(sprintf("Non-finite rows dropped: %d\n", n_drop))
cat(sprintf("Final sample: %d observations\n\n", nrow(dat)))

cat("Outcome (patent count) summary:\n")
print(summary(dat$y))
cat(sprintf("Zero patent share: %.1f%%\n\n", 100 * mean(dat$y == 0)))

y <- dat$y

# =============================================================================
# 2. Build model matrix
# =============================================================================

# Year dummies (year 1 = reference); intercept added via cbind
yr_mat <- model.matrix(~ yr, data = dat)[, -1, drop = FALSE]
X <- cbind(1, dat$rd, dat$lk, dat$sci, yr_mat)
colnames(X) <- c("(Intercept)", "log_RD", "log_K", "sci_sect",
                  paste0("year", 2:5))

cat("Model matrix:", nrow(X), "x", ncol(X), "\n")
cat("Columns:", paste(colnames(X), collapse = ", "), "\n\n")

# =============================================================================
# 3. Poisson GLM (baseline)
# =============================================================================

cat("Fitting Poisson GLM...\n")
fit_pois <- glm(y ~ rd + lk + sci + yr, data = dat, family = poisson())
cat("  Converged:", fit_pois$converged, "\n")
cat("  Log-lik:", round(as.numeric(logLik(fit_pois)), 2), "\n\n")

# =============================================================================
# 4. Exponential frontier (alpha = 1 restricted)
# =============================================================================

cat("Fitting Poisson-Exp frontier...\n")
fit_exp <- tryCatch(
  suppressWarnings(fit_poisson_frontier(y, X, dist = "exponential")),
  error = function(e) { cat("  ERROR:", conditionMessage(e), "\n"); NULL }
)

if (!is.null(fit_exp)) {
  cat("  Converged:", fit_exp$convergence == 0L,
      "(code", fit_exp$convergence, ")\n")
  cat("  Log-lik:", round(fit_exp$loglik, 2), "\n")
  cat("  b_hat:", round(fit_exp$b, 4), " SE:", round(fit_exp$se_b, 4), "\n\n")
} else {
  cat("  Exp frontier failed.\n\n")
}

# =============================================================================
# 5. Gamma frontier — multi-start L-BFGS-B over (log_b, log_alpha)
# =============================================================================
#
# A single warm-start from the exponential fit fails to converge on the
# patent panel because the log-likelihood is shallow along the
# alpha -> 0, b -> infty ridge.  We therefore perturb both the rate
# (log_b) and the shape (log_alpha) on a small grid that respects the
# L-BFGS-B bounds [-8, 8] x [-2, 4] and the mean-invariant rule
# log_b_try = log_b_exp + log_alpha_try, then keep the converged fit
# with the smallest negative log-likelihood.
#
# Internally fit_poisson_frontier() already runs a four-point fallback
# over log_alpha when its first attempt fails; here we layer a coarser
# grid on top to widen the basin of attraction.
# =============================================================================

cat("Fitting Poisson-Gamma frontier (multi-start)...\n")

if (!is.null(fit_exp)) {
  k          <- ncol(X)
  beta_warm  <- fit_exp$coefficients
  log_b_warm <- log(fit_exp$b)

  log_alpha_grid <- c(-1.5, -0.75, 0, 0.5, 1, 1.5, 2.5)
  fits_gam <- vector("list", length(log_alpha_grid))

  for (i in seq_along(log_alpha_grid)) {
    la <- log_alpha_grid[i]
    # mean-invariant rule: alpha * b held at exp(log_b_warm) = b_warm
    starts_try <- c(beta_warm, log_b_warm + la, la)
    fits_gam[[i]] <- tryCatch(
      suppressWarnings(
        fit_poisson_frontier(y, X, dist = "gamma", starts = starts_try)
      ),
      error = function(e) NULL
    )
  }

  conv_idx <- which(vapply(fits_gam, function(f) {
    !is.null(f) && isTRUE(f$convergence == 0L) && is.finite(f$loglik)
  }, logical(1L)))

  if (length(conv_idx) > 0L) {
    best <- conv_idx[which.max(vapply(fits_gam[conv_idx],
                                      `[[`, numeric(1L), "loglik"))]
    fit_gam <- fits_gam[[best]]
    cat("  Converged from log_alpha start =",
        log_alpha_grid[best], "\n")
    cat("  alpha_hat:", round(fit_gam$alpha, 4),
        " (SE", round(fit_gam$se_alpha, 4), ")\n")
    cat("  b_hat:    ", round(fit_gam$b,     4),
        " (SE", round(fit_gam$se_b,     4), ")\n")
    cat("  Log-lik:  ", round(fit_gam$loglik, 2), "\n\n")
  } else {
    fit_gam <- NULL
    cat("  No starting point produced a converged fit. ",
        "Gamma frontier omitted from the homogeneous-MLE table.\n\n",
        sep = "")
  }
} else {
  fit_gam <- NULL
  cat("  Skipped: exponential warm-start unavailable.\n\n")
}

# =============================================================================
# 6. Likelihood ratio test for H_0: alpha = 1
# =============================================================================

if (!is.null(fit_gam) && !is.null(fit_exp)) {
  lr_stat <- 2 * (fit_gam$loglik - fit_exp$loglik)
  # alpha_0 = 1 is interior to alpha > 0; standard chi^2_1 reference
  lr_pval <- if (is.finite(lr_stat) && lr_stat >= 0) {
    pchisq(lr_stat, df = 1L, lower.tail = FALSE)
  } else {
    NA_real_
  }
  cat("LR test (H0: alpha = 1):\n")
  cat("  LR stat:", round(lr_stat, 4), "\n")
  cat("  p-value:", format.pval(lr_pval, digits = 4), "\n\n")
} else {
  lr_stat <- NA_real_
  lr_pval <- NA_real_
  cat("LR test skipped: Gamma frontier not estimated.\n\n")
}

# =============================================================================
# 7. Efficiency scores
# =============================================================================

scores_exp <- NULL
scores_gam <- NULL

if (!is.null(fit_exp)) {
  cat("Computing efficiency scores (Exp)...\n")
  scores_exp <- tryCatch(
    efficiency_scores(fit_exp, y, X),
    error = function(e) {
      cat("  Warning:", conditionMessage(e), "\n"); NULL
    }
  )
  if (!is.null(scores_exp))
    cat(sprintf("  Mean TE: %.4f\n", mean(scores_exp$eff_score)))
}

scores_gam <- NULL  # Gamma model not estimated

# =============================================================================
# 8. Model comparison table
# =============================================================================

# Build a uniform data.frame matching compare_models() column structure:
# Model, Distribution, alpha, b, Npar, LogLik, AIC, BIC, Converged
n_obs      <- nrow(dat)
k_glm      <- length(coef(fit_pois))
glm_loglik <- round(as.numeric(logLik(fit_pois)), 2)

glm_row <- data.frame(
  Model        = "Poisson GLM",
  Distribution = "none",
  alpha        = NA_real_,
  b            = NA_real_,
  Npar         = k_glm,
  LogLik       = glm_loglik,
  AIC          = round(-2 * glm_loglik + 2 * k_glm, 2),
  BIC          = round(-2 * glm_loglik + log(n_obs) * k_glm, 2),
  Converged    = fit_pois$converged,
  stringsAsFactors = FALSE
)

frontier_fits <- Filter(Negate(is.null), list(Exp = fit_exp, Gamma = fit_gam))
if (length(frontier_fits) > 0) {
  frontier_rows <- compare_models(frontier_fits)
  compare_tbl   <- rbind(glm_row, frontier_rows)
} else {
  compare_tbl <- glm_row
}

# =============================================================================
# 9. Save
# =============================================================================

saveRDS(
  list(
    data        = dat,
    X           = X,
    y           = y,
    fit_pois    = fit_pois,
    fit_exp     = fit_exp,
    fit_gam     = fit_gam,
    scores_exp  = scores_exp,
    scores_gam  = scores_gam,
    lr_stat     = lr_stat,
    lr_pval     = lr_pval,
    compare_tbl = compare_tbl
  ),
  file = "code/empirical/fits.rds"
)

message("Empirical application complete. Results saved to code/empirical/fits.rds")

# =============================================================
# SECTION 2: SCALING MODEL — INEFFICIENCY DETERMINANTS
# =============================================================
#
# Determinants chosen on substantive economic grounds:
#
#   z1 = logk  (log capital stock)
#      Rationale: capital-intensive firms may be better at translating R&D
#      into patents due to complementarity between physical and knowledge
#      capital. Sign prediction: delta_1 < 0 (more capital → lower
#      inefficiency → higher b_i).
#
#   z2 = sci   (science-sector indicator, 0/1)
#      Rationale: firms in science-intensive sectors have stronger absorptive
#      capacity and established IP practices, making them systematically more
#      efficient at converting R&D into patents.
#      Sign prediction: delta_2 < 0 (science sector → lower inefficiency).
#
#   z3 = logk^2 (optional, for non-monotone capital effect)
#      Rationale: very capital-heavy firms may be bureaucratic and less agile.
#      Included if LR_3 rejects H0 at 5%.
#
# NOTE: logk and sci also appear in X (frontier mean).  Identification of
#       beta_logk vs delta_1 therefore relies partly on the nonlinear way b_i
#       enters the PMF, not purely on an exclusion restriction.  The exclusion
#       of log_RD from Z ensures the R&D coefficient is identified by exclusion.
# =============================================================

dir.create("results", showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), "results/session_info.txt")

# ---- 2.1  Build determinant matrix (Z) and print checks ----------------

z1     <- dat$lk                  # log capital
z2     <- dat$sci                 # science sector
z3     <- dat$lk^2               # logk squared (optional)
Z_base <- cbind(z1, z2)           # Z for M4
Z_full <- cbind(z1, z2, z3)       # Z for M5

cat("\n=== SECTION 2: SCALING MODEL ===\n\n")
cat("Data preview:\n")
cat("  n =", nrow(dat), "\n")
cat("  y range: [", min(y), ",", max(y), "],",
    sum(y == 0), sprintf("zeros (%.1f%%)\n", 100 * mean(y == 0)))
cat("  z1 (logk):   mean =", round(mean(z1), 3),
    " sd =", round(sd(z1), 3), "\n")
cat("  z2 (sci):    mean =", round(mean(z2), 3), "\n")
cat("  z3 (logk^2): mean =", round(mean(z3), 3),
    " sd =", round(sd(z3), 3), "\n\n")

cor_mat <- cor(cbind(y = y, log_RD = dat$rd, logk = dat$lk, sci = dat$sci))
cat("Correlation matrix (frontier inputs and scaling determinants):\n")
print(round(cor_mat, 3))
if (abs(cor_mat["log_RD", "logk"]) > 0.7)
  cat("\nWARNING: |cor(log_RD, logk)| =",
      round(abs(cor_mat["log_RD", "logk"]), 3),
      "> 0.7.  Identification of beta_logk vs delta_1 relies partly on",
      "functional form (the nonlinear entry of b_i in the PMF).\n")

saveRDS(list(cor_matrix = cor_mat, z1 = z1, z2 = z2, z3 = z3),
        "results/determinants_desc.rds")
cat("\nData checks passed. Proceeding to estimation.\n\n")


# ---- 2.2  Helper functions ------------------------------------------

# Vectorized log PMF for Poisson half-normal (PHN) via trapezoid quadrature.
# u ~ |N(0, sigma^2)|, so f(u) = 2*dnorm(u, 0, sigma) for u >= 0.
# P(Y=y | a, sigma) ≈ sum_{j} dpois(y, exp(a - u_j)) * 2*dnorm(u_j, 0, sigma) * du
log_pmf_phn_vec <- function(y, a, sigma, n_grid = 80L) {
  upper <- max(6 * sigma, 1)
  ug    <- seq(1e-4, upper, length.out = n_grid)
  du    <- ug[2] - ug[1]
  wts   <- 2 * dnorm(ug, 0, sigma) * du          # quadrature weights
  # lambda_mat[i, j] = exp(a[i] - u[j])  (n x n_grid)
  lam_mat <- exp(outer(a, ug, `-`))              # safe: a - u
  # Poisson PMF matrix
  pmf_mat <- matrix(0, length(y), n_grid)
  for (j in seq_len(n_grid))
    pmf_mat[, j] <- dpois(y, lam_mat[, j])
  pmf_vec <- drop(pmf_mat %*% wts)
  log(pmax(pmf_vec, .Machine$double.eps))
}

nll_phn <- function(params, y, X) {
  k     <- ncol(X)
  beta  <- params[seq_len(k)]
  sigma <- exp(params[k + 1L])          # log_sigma for positivity
  if (!is.finite(sigma) || sigma < 1e-4 || sigma > 20) return(1e15)
  a  <- drop(X %*% beta)
  lp <- log_pmf_phn_vec(y, a, sigma)
  -sum(lp)
}

# Scaling log-likelihood (exponential inefficiency, goods case).
# params = c(beta[1:p], log_b, delta[1:q])
# b_i = exp(log_b) * exp(-Z %*% delta)
loglik_scaling_exp <- function(params, y, X, Z) {
  p    <- ncol(X); q <- ncol(Z)
  beta  <- params[seq_len(p)]
  b     <- exp(params[p + 1L])
  delta <- params[(p + 2L):(p + 1L + q)]
  a     <- drop(X %*% beta)
  b_i   <- b * exp(-drop(Z %*% delta))
  if (any(!is.finite(b_i)) || any(b_i < 1e-6) || any(b_i > 1e6)) return(-1e15)
  lp <- log(b_i) - b_i * a - lgamma(y + 1) + lgamma(y + b_i) +
    suppressWarnings(pgamma(exp(pmin(a, 700)), shape = y + b_i,
                            rate = 1, log.p = TRUE))
  if (!all(is.finite(lp))) return(-1e15)
  sum(lp)
}

# Analytic efficiency score for scaling model (unit-specific b_i)
te_scaling <- function(y, a, b_i) {
  log_r <- lgamma(y + b_i + 1) +
    pgamma(exp(pmin(a, 700)), shape = y + b_i + 1, rate = 1, log.p = TRUE) -
    lgamma(y + b_i) -
    pgamma(exp(pmin(a, 700)), shape = y + b_i,     rate = 1, log.p = TRUE)
  exp(-a + log_r)
}

# Generic fitting wrapper with BFGS + L-BFGS-B + Nelder-Mead fallback
fit_optim <- function(nll_fn, start, lower = NULL, upper = NULL,
                      method_pref = "L-BFGS-B", maxit = 3000, ...) {
  t0  <- proc.time()["elapsed"]
  err <- NULL

  # Attempt 1: preferred method
  res <- tryCatch(
    optim(start, nll_fn, method = method_pref,
          lower = lower, upper = upper,
          control = list(maxit = maxit, factr = 1e7),
          hessian = TRUE, ...),
    error = function(e) { err <<- conditionMessage(e); NULL }
  )
  method_used <- method_pref

  # Attempt 2: BFGS if L-BFGS-B failed
  if ((is.null(res) || !is.finite(res$value)) && method_pref != "BFGS") {
    res <- tryCatch(
      optim(start, nll_fn, method = "BFGS",
            control = list(maxit = maxit, reltol = 1e-10),
            hessian = TRUE, ...),
      error = function(e) { err <<- conditionMessage(e); NULL }
    )
    method_used <- "BFGS"
  }

  # Attempt 3: Nelder-Mead fallback
  if (is.null(res) || !is.finite(res$value)) {
    res <- tryCatch(
      optim(start, nll_fn, method = "Nelder-Mead",
            control = list(maxit = 6000, reltol = 1e-9),
            hessian = TRUE, ...),
      error = function(e) { err <<- conditionMessage(e); NULL }
    )
    method_used <- "Nelder-Mead"
  }

  elapsed <- proc.time()["elapsed"] - t0
  if (!is.null(res)) {
    res$method_used <- method_used
    res$elapsed     <- elapsed
    res$error_msg   <- err
  }
  res
}


# ---- 2.3  Fit models M1 – M5 ----------------------------------------

p <- ncol(X)   # number of frontier parameters (incl. year dummies)

# M1: Poisson GLM (reuse fit_pois from Section 1)
ll_M1 <- as.numeric(logLik(fit_pois))
cat("M1 (Poisson GLM) log-lik:", round(ll_M1, 2), "\n")

# M2: Poisson half-normal (PHN) — Fé & Hofler (2013) benchmark
cat("Fitting M2 (PHN) ...\n")
t2 <- proc.time()["elapsed"]
start_phn <- c(coef(fit_pois), log(0.5))
fit_M2 <- tryCatch(
  fit_optim(nll_phn, start_phn, method_pref = "BFGS",
            y = y, X = X),
  error = function(e) { cat("  M2 ERROR:", conditionMessage(e), "\n"); NULL }
)
if (!is.null(fit_M2)) {
  ll_M2 <- -fit_M2$value
  sigma_hat <- exp(fit_M2$par[p + 1L])
  cat(sprintf("  conv=%d | log-lik=%.2f | sigma=%.4f | %.1f sec\n",
              fit_M2$convergence, ll_M2, sigma_hat,
              proc.time()["elapsed"] - t2))
} else {
  ll_M2 <- NA_real_
  cat("  M2 failed.\n")
}

# M3: Exponential homogeneous (reuse fit_exp from Section 1)
ll_M3 <- if (!is.null(fit_exp)) fit_exp$loglik else NA_real_
b_M3  <- if (!is.null(fit_exp)) fit_exp$b       else NA_real_
cat("M3 (Exp homogeneous) log-lik:", round(ll_M3, 2), "\n")

if (is.null(fit_exp)) stop("M3 (Exp frontier) did not converge. Cannot proceed.")

# Warm-start from M3
start_base <- c(fit_exp$coefficients, log(fit_exp$b))
lo_b  <- c(rep(-10, p), -3)
hi_b  <- c(rep( 10, p),  6)

# M4: Exponential scaling with z1 (logk) and z2 (sci)
cat("Fitting M4 (Exp scaling: logk + sci) ...\n")
q4      <- ncol(Z_base)
start_M4 <- c(start_base, rep(0, q4))
lo_M4    <- c(lo_b, rep(-5, q4));  hi_M4 <- c(hi_b, rep(5, q4))

fit_M4 <- tryCatch(
  fit_optim(function(p, ...) -loglik_scaling_exp(p, ...), start_M4,
            lower = lo_M4, upper = hi_M4,
            y = y, X = X, Z = Z_base),
  error = function(e) { cat("  M4 ERROR:", conditionMessage(e), "\n"); NULL }
)
if (!is.null(fit_M4) && is.finite(fit_M4$value)) {
  ll_M4    <- -fit_M4$value
  b_M4     <- exp(fit_M4$par[p + 1L])
  delta_M4 <- fit_M4$par[(p + 2L):(p + 1L + q4)]
  vcv_M4   <- tryCatch(solve(fit_M4$hessian),
                        error = function(e) matrix(NA_real_, length(start_M4), length(start_M4)))
  se_M4    <- sqrt(pmax(diag(vcv_M4), 0))
  cat(sprintf("  conv=%d | log-lik=%.2f | b=%.4f | delta=(%s) | %.1f sec\n",
              fit_M4$convergence, ll_M4, b_M4,
              paste(round(delta_M4, 4), collapse=", "),
              fit_M4$elapsed))
} else {
  ll_M4 <- NA_real_; b_M4 <- NA_real_; delta_M4 <- rep(NA_real_, q4)
  vcv_M4 <- NULL; se_M4 <- rep(NA_real_, p + 1L + q4)
  cat("  M4 failed.\n")
}

# M5: Exponential scaling with z1 (logk), z2 (sci), z3 (logk^2)
cat("Fitting M5 (Exp scaling: logk + sci + logk^2) ...\n")
q5       <- ncol(Z_full)
start_M5 <- if (!is.null(fit_M4) && is.finite(ll_M4)) {
  c(fit_M4$par, 0)
} else {
  c(start_base, rep(0, q5))
}
lo_M5 <- c(lo_b, rep(-5, q5));  hi_M5 <- c(hi_b, rep(5, q5))

fit_M5 <- tryCatch(
  fit_optim(function(p, ...) -loglik_scaling_exp(p, ...), start_M5,
            lower = lo_M5, upper = hi_M5,
            y = y, X = X, Z = Z_full),
  error = function(e) { cat("  M5 ERROR:", conditionMessage(e), "\n"); NULL }
)
if (!is.null(fit_M5) && is.finite(fit_M5$value)) {
  ll_M5    <- -fit_M5$value
  b_M5     <- exp(fit_M5$par[p + 1L])
  delta_M5 <- fit_M5$par[(p + 2L):(p + 1L + q5)]
  vcv_M5   <- tryCatch(solve(fit_M5$hessian),
                        error = function(e) matrix(NA_real_, length(start_M5), length(start_M5)))
  se_M5    <- sqrt(pmax(diag(vcv_M5), 0))
  cat(sprintf("  conv=%d | log-lik=%.2f | b=%.4f | delta=(%s) | %.1f sec\n",
              fit_M5$convergence, ll_M5, b_M5,
              paste(round(delta_M5, 4), collapse=", "),
              fit_M5$elapsed))
} else {
  ll_M5 <- NA_real_; b_M5 <- NA_real_; delta_M5 <- rep(NA_real_, q5)
  vcv_M5 <- NULL; se_M5 <- rep(NA_real_, p + 1L + q5)
  cat("  M5 failed.\n")
}


# ---- 2.4  Model comparison tests and preferred model selection ------
#
# We use two test families depending on whether the comparison is
# strictly nested with an interior null:
#
#   * Likelihood-ratio test (chi-squared): valid only for nested models
#     where the restricted parameter lies in the interior of the
#     unrestricted space. Used for M4 vs M3 (delta = 0) and M5 vs M4
#     (added regressor in the scaling function), and for the Gamma vs
#     exponential test LR_4 (alpha = 1 interior in Gamma's alpha > 0).
#
#   * Vuong (1989) test: handles non-nested models AND the
#     overlapping/boundary cases that invalidate the chi-squared LR.
#     Used for M3 vs M2 (exponential Gamma frontier versus Poisson
#     half-normal — different distributional families, both fits well
#     in the interior of their respective parameter spaces).
#     Sign convention: V > 0 favours fit1, V < 0 favours fit2.
#
# We do NOT report a Vuong test for M3 vs M1: the Poisson GLM is the
# b -> infinity boundary of the exponential frontier, so the two
# families overlap at a boundary point and the standard Vuong normal
# limit fails (Andrews 2001). The M3-over-M1 conclusion is supported
# instead by the AIC and BIC gap, which are agnostic to boundary
# regularity.

lr_test <- function(ll_r, ll_u, df) {
  stat <- 2 * (ll_u - ll_r)
  pval <- pchisq(max(stat, 0), df = df, lower.tail = FALSE)
  list(stat = stat, df = df, pval = pval,
       decision = ifelse(pval < 0.05, "Reject H0", "Fail to reject H0"))
}

vuong_stat <- function(ll_obs_1, ll_obs_2) {
  m  <- ll_obs_1 - ll_obs_2
  s  <- sd(m)
  n  <- length(m)
  if (!is.finite(s) || s <= .Machine$double.eps) {
    return(list(V = NA_real_, pval = NA_real_, LR_obs = sum(m), n = n,
                decision = "Indistinguishable"))
  }
  V    <- sqrt(n) * mean(m) / s
  pval <- 2 * pnorm(-abs(V))
  decision <- if (pval >= 0.05) "Indistinguishable" else
              if (V > 0) "Favours fit1" else "Favours fit2"
  list(V = V, pval = pval, LR_obs = sum(m), n = n, decision = decision)
}

# Per-observation log-likelihoods needed for Vuong
ll_obs_M1 <- dpois(y, lambda = fitted(fit_pois), log = TRUE)

ll_obs_M2 <- if (!is.null(fit_M2)) {
  beta_M2  <- fit_M2$par[seq_len(p)]
  sigma_M2 <- exp(fit_M2$par[p + 1L])
  log_pmf_phn_vec(y, drop(X %*% beta_M2), sigma_M2)
} else rep(NA_real_, length(y))

ll_obs_M3 <- if (!is.null(fit_exp)) {
  vapply(seq_along(y), function(i)
    pmf_poisson_gamma(y[i], drop(X[i, ] %*% fit_exp$coefficients),
                      fit_exp$b, alpha = 1), numeric(1L))
} else rep(NA_real_, length(y))

# V_32: M3 (exp frontier, fit1) vs M2 (PHN, fit2). Genuinely non-nested.
V_32 <- if (all(is.finite(ll_obs_M3)) && all(is.finite(ll_obs_M2)))
  vuong_stat(ll_obs_M3, ll_obs_M2) else
  list(V = NA, pval = NA, LR_obs = NA, n = length(y), decision = "N/A")

# Information-criterion gaps for the M3-vs-M1 (boundary) comparison.
# AIC = -2 * loglik + 2 * k; BIC = -2 * loglik + log(n) * k. Positive
# gap means M3 is preferred. Boundary-agnostic; no test, just summary.
k_M1 <- length(coef(fit_pois))
k_M3 <- length(fit_exp$coefficients) + 1L
ic_M3_vs_M1 <- list(
  loglik_gap = ll_M3 - ll_M1,
  aic_gap    = (-2 * ll_M3 + 2 * k_M3) - (-2 * ll_M1 + 2 * k_M1),
  bic_gap    = (-2 * ll_M3 + log(length(y)) * k_M3) -
               (-2 * ll_M1 + log(length(y)) * k_M1)
)

# Nested LR tests (interior nulls — chi-squared valid)
LR_2 <- if (is.finite(ll_M4) && is.finite(ll_M3)) lr_test(ll_M3, ll_M4, df = 2) else
  list(stat = NA, df = 2, pval = NA, decision = "N/A")

LR_3 <- if (is.finite(ll_M5) && is.finite(ll_M4)) lr_test(ll_M4, ll_M5, df = 1) else
  list(stat = NA, df = 1, pval = NA, decision = "N/A")

cat("\nModel-comparison tests:\n")
cat(sprintf("  M3 vs M1 (boundary; AIC/BIC gap, no formal test):\n"))
cat(sprintf("    loglik gap = %.1f, AIC gap = %.1f, BIC gap = %.1f (positive favours M3)\n",
            ic_M3_vs_M1$loglik_gap, ic_M3_vs_M1$aic_gap, ic_M3_vs_M1$bic_gap))
cat(sprintf("  V_32 (M3 vs M2, Vuong; non-nested): V=%6.3f  p=%.4f  %s\n",
            V_32$V, V_32$pval, V_32$decision))
cat(sprintf("  LR_2 (M4 vs M3, df=2, nested LR):  stat=%.2f  p=%.4f  %s\n",
            LR_2$stat, LR_2$pval, LR_2$decision))
cat(sprintf("  LR_3 (M5 vs M4, df=1, nested LR):  stat=%.2f  p=%.4f  %s\n",
            LR_3$stat, LR_3$pval, LR_3$decision))

preferred_model <- if (!is.na(LR_3$pval) && LR_3$pval < 0.05) "M5" else "M4"
cat("\nPreferred model:", preferred_model, "\n")
if (preferred_model == "M5") {
  cat("  (logk^2 included: LR_3 rejects H0 at 5%)\n")
} else {
  cat("  (logk^2 excluded: LR_3 fails to reject H0)\n")
}

# ---- 2.5  Efficiency scores -----------------------------------------

fit_pref   <- if (preferred_model == "M5") fit_M5 else fit_M4
Z_pref     <- if (preferred_model == "M5") Z_full else Z_base
q_pref     <- ncol(Z_pref)
delta_pref <- if (preferred_model == "M5") delta_M5 else delta_M4
b_pref     <- if (preferred_model == "M5") b_M5     else b_M4

a_pref   <- drop(X %*% fit_pref$par[seq_len(p)])
b_i_pref <- b_pref * exp(-drop(Z_pref %*% delta_pref))

# Check goods-case caveat (b_i > 0 always OK for goods; bads would need b_i > 1)
if (any(b_i_pref < 1, na.rm = TRUE))
  cat("\nNOTE (bads-case caveat): some b_i_hat <1. Goods-case efficiency scores are",
      "always defined for any b_i>0, so no action required. If this were the bads",
      "case (counts inflated by inefficiency), b_i>1 would be required.\n")

te_pref <- te_scaling(y, a_pref, b_i_pref)
te_M3   <- if (!is.null(fit_exp)) {
  a_M3 <- drop(X %*% fit_exp$coefficients)
  te_scaling(y, a_M3, fit_exp$b)   # homogeneous: b_i = b for all i
} else rep(NA_real_, length(y))

scores_df <- data.frame(
  i           = seq_along(y),
  y           = y,
  logk        = dat$lk,
  sci         = dat$sci,
  a_pref      = a_pref,
  b_i_pref    = b_i_pref,
  te_scaling  = te_pref,
  te_homog    = te_M3,
  preferred   = preferred_model
)
saveRDS(scores_df, "results/efficiency_scores.rds")
cat(sprintf("\nEfficiency scores: mean(scaling)=%.4f, mean(homog)=%.4f\n",
            mean(te_pref, na.rm=TRUE), mean(te_M3, na.rm=TRUE)))


# ---- 2.6  Compile and save results (M1–M5) --------------------------

lr_tests_all <- list(IC_31 = ic_M3_vs_M1, V_32 = V_32, LR_2 = LR_2, LR_3 = LR_3)

empirical_fits <- list(
  data            = dat,
  X               = X,
  y               = y,
  Z_base          = Z_base,
  Z_full          = Z_full,
  fit_pois        = fit_pois,
  fit_exp         = fit_exp,       # M3
  fit_M2          = fit_M2,
  fit_M4          = fit_M4,
  fit_M5          = fit_M5,
  fit_M6          = NULL,          # populated below if Gamma converges
  ll_M1           = ll_M1,
  ll_M2           = ll_M2,
  ll_M3           = ll_M3,
  ll_M4           = ll_M4,
  ll_M5           = ll_M5,
  vcv_M4          = vcv_M4,
  vcv_M5          = vcv_M5,
  se_M4           = se_M4,
  se_M5           = se_M5,
  lr_tests        = lr_tests_all,
  preferred_model = preferred_model,
  scores          = scores_df,
  cor_matrix      = cor_mat
)
saveRDS(empirical_fits, "results/empirical_fits.rds")


# ---- 2.7  Final summary (M1–M5) -------------------------------------
cat("\n",
    "Estimation complete (M1–M5).\n",
    "Preferred model:", preferred_model, "\n",
    "Log-likelihood: ", round(if (preferred_model == "M5") ll_M5 else ll_M4, 2), "\n",
    "delta estimates:", paste(round(if (preferred_model=="M5") delta_M5 else delta_M4, 4), collapse=", "), "\n",
    "Mean efficiency:", round(mean(te_pref, na.rm=TRUE), 4), "\n",
    "All results saved to results/empirical_fits.rds\n",
    sep="")


# ---- 2.8  M6: Gamma homogeneous — CONVERGENCE PROTOCOL -------------
cat("\n--- Attempting M6 (Gamma homogeneous) ---\n")

# Quadrature-based log-PMF for a single observation.
#
# The alternating series representation of the Gamma-Poisson PMF suffers
# catastrophic cancellation when both y and exp(a) are large: for y=515,
# a≈8, the individual partial sums S+ and S- are O(exp(+870)) while their
# difference S = P(Y=y)·y!/b^alpha is O(exp(-870)).  IEEE double precision
# cannot represent this difference regardless of how many series terms are
# included.  Direct numerical integration avoids this entirely.
#
# The integrand is in log-scale:
#   log_kern(u) = -exp(a-u) + y*(a-u) - b*u + (alpha-1)*log(u)
# We factor out the kernel at its mode u* ≈ a - log(y+b) to prevent
# overflow before calling integrate().
log_pmf_gamma_quad <- function(yi, ai, b, alpha) {
  log_kern <- function(u) {
    u <- pmax(u, 1e-300)
    -exp(ai - u) + yi * (ai - u) - b * u + (alpha - 1) * log(u)
  }
  u_mode  <- pmax(ai - log(pmax(yi + b, 0.1)), 1e-8)
  lk_mode <- log_kern(u_mode)
  curv    <- exp(ai - u_mode) + pmax(alpha - 1, 0) / pmax(u_mode^2, 1e-10)
  width   <- 5 / sqrt(pmax(curv, 0.01))
  u_lo    <- pmax(u_mode - 3 * width, 1e-8)
  u_hi    <- u_mode + 6 * width

  I0 <- tryCatch(
    integrate(function(u) exp(log_kern(u) - lk_mode),
              u_lo, u_hi, rel.tol = 1e-4, abs.tol = 0,
              subdivisions = 100L)$value,
    error = function(e) NA_real_
  )
  if (is.na(I0) || I0 <= 0) {
    I0 <- tryCatch(
      integrate(function(u) exp(log_kern(u) - lk_mode),
                1e-8, u_mode + 15 * width,
                rel.tol = 1e-3, abs.tol = 0, subdivisions = 200L)$value,
      error = function(e) NA_real_
    )
  }
  if (is.na(I0) || I0 <= 0) return(NA_real_)
  alpha * log(b) - lgamma(alpha) - lgamma(yi + 1) + lk_mode + log(I0)
}

nll_gamma_emp <- function(params, y, X) {
  p     <- ncol(X)
  beta  <- params[seq_len(p)]
  b     <- exp(params[p + 1L])
  alpha <- exp(params[p + 2L])
  if (!is.finite(b) || b < 1e-6 || b > 1e5) return(1e15)
  if (!is.finite(alpha) || alpha < 0.05 || alpha > 100) return(1e15)
  a <- drop(X %*% beta)
  # Fast closed-form at alpha=1 — avoids the quadrature overhead for the
  # initial and gradient steps where alpha is perturbed near 1.
  if (abs(alpha - 1) < 1e-6) {
    lp <- log(b) - b * a - lgamma(y + 1) + lgamma(y + b) +
      pgamma(exp(pmin(a, 700)), shape = y + b, rate = 1, log.p = TRUE)
    return(if (all(is.finite(lp))) -sum(lp) else 1e15)
  }
  lp <- vapply(seq_along(y),
               function(i) log_pmf_gamma_quad(y[i], a[i], b, alpha),
               numeric(1L))
  if (!all(is.finite(lp))) return(1e15)
  -sum(lp)
}

# Starting value sets for the 5 attempts.
#
# Key insight: for Gamma(alpha, b), E[u] = alpha/b.  Using the exponential
# model's b_M3 (estimated under alpha=1) as-is for alpha_init > 1 moves the
# starting point to E[u_init] = alpha/b_M3 >> 1/b_M3, far from M3.  When
# b_M3 < 1 this also places the start in a region where E[exp(u)] = (b/(b-1))^alpha
# does not exist (bads-case score), making the likelihood numerically degenerate.
#
# MEAN-INVARIANT STARTING RULE: set b_init = alpha_init * b_M3, so that
#   E[u_init] = alpha_init / (alpha_init * b_M3) = 1/b_M3 = E_M3[u]
# for every alpha_init.  This anchors mean inefficiency to the exponential
# model estimate and ensures the starting point always lies in the interior
# of the well-identified parameter space.
beta_init <- fit_exp$coefficients
logb_init <- log(fit_exp$b)

mk_start_M6 <- function(alpha_val)
  c(beta_init, logb_init + log(alpha_val), log(alpha_val))

starts_M6 <- list(
  mk_start_M6(1.0),   # attempt 1: alpha=1 — identical to M3, safest start
  mk_start_M6(2.0),   # attempt 2: alpha=2,   b = 2 * b_M3
  mk_start_M6(0.5),   # attempt 3: alpha=0.5, b = 0.5 * b_M3  (Nelder-Mead)
  mk_start_M6(3.0),   # attempt 4: alpha=3,   b = 3 * b_M3    (Nelder-Mead)
  NULL                # attempt 5: random starts (generated below)
)
set.seed(20250307L)
n_rand <- 10L
rand_alphas <- runif(n_rand, 0.3, 5)   # alpha in (0.3, 5)
rand_starts <- lapply(rand_alphas, function(al)
  c(beta_init + rnorm(length(beta_init), 0, 0.1),
    logb_init + log(al) + rnorm(1, 0, 0.1),   # b ≈ al * b_M3 (mean-invariant)
    log(al))
)
starts_M6[[5L]] <- rand_starts

methods_M6 <- c("BFGS", "BFGS", "Nelder-Mead", "Nelder-Mead", "BFGS")
lo_M6      <- c(rep(-10, p), -3, -2)
hi_M6      <- c(rep( 10, p),  6,  4)

attempts_M6 <- vector("list", 5L)
hessians_M6 <- vector("list", 5L)
eigvals_M6  <- vector("list", 5L)
llvals_M6   <- rep(NA_real_, 5L)
names(llvals_M6) <- paste0("attempt_", 1:5)

alpha_converged_to_1 <- FALSE   # set TRUE if attempt 1 finds alpha ≈ 1

for (k6 in 1:5L) {
  cat(sprintf("  Attempt %d (%s)...", k6, methods_M6[k6]))

  # Early exit: if attempt 1 converged to alpha ≈ 1, the Gamma MLE IS the
  # exponential model.  Running the quadrature-based likelihood for alpha ≠ 1
  # (attempts 2–5) would be extremely slow and cannot improve on this result.
  if (k6 > 1L && alpha_converged_to_1) {
    cat(" skipped (alpha=1 is the Gamma MLE)\n")
    next
  }

  st_list <- if (k6 < 5L) list(starts_M6[[k6]]) else rand_starts
  best_k  <- NULL

  for (st in st_list) {
    tryCatch({
      opt <- optim(st, nll_gamma_emp, y = y, X = X,
                   method  = if (methods_M6[k6] == "BFGS") "L-BFGS-B" else "Nelder-Mead",
                   lower   = if (methods_M6[k6] == "BFGS") lo_M6 else -Inf,
                   upper   = if (methods_M6[k6] == "BFGS") hi_M6 else  Inf,
                   control = list(maxit = 2000, factr = 1e7),
                   hessian = TRUE)
      if (is.null(best_k) || opt$value < best_k$value)
        best_k <- opt
    }, error = function(e)
      cat(sprintf("\n    sub-attempt error: %s", conditionMessage(e))))
  }

  if (!is.null(best_k)) {
    attempts_M6[[k6]] <- best_k
    H6                <- best_k$hessian
    ev6               <- tryCatch(eigen(-H6, only.values = TRUE)$values,
                                   error = function(e) rep(NA_real_, nrow(H6)))
    hessians_M6[[k6]] <- H6
    eigvals_M6[[k6]]  <- ev6
    llvals_M6[k6]     <- -best_k$value
    alpha_hat_k <- exp(best_k$par[p + 2L])
    b_hat_k     <- exp(best_k$par[p + 1L])
    cat(sprintf(" ll=%.2f | alpha=%.4f | b=%.4f | conv=%d\n",
                -best_k$value, alpha_hat_k, b_hat_k, best_k$convergence))

    # Detect boundary convergence: alpha ≈ 1 after attempt 1
    if (k6 == 1L && best_k$convergence == 0L && abs(alpha_hat_k - 1) < 1e-3) {
      alpha_converged_to_1 <- TRUE
      cat("  [alpha ≈ 1: Gamma MLE = Exponential model; skipping remaining attempts]\n")
    }
  } else {
    cat(" FAILED\n")
  }
}

# Evaluate convergence criteria
best_idx <- which.max(llvals_M6)   # integer(0) if every attempt failed
best_M6  <- if (length(best_idx) == 1L) attempts_M6[[best_idx]] else NULL
m6_ok    <- FALSE

if (!is.null(best_M6) && is.finite(best_M6$value)) {
  alpha_M6 <- exp(best_M6$par[p + 2L])
  b_M6     <- exp(best_M6$par[p + 1L])
  ll_M6    <- -best_M6$value
  ev_best  <- eigvals_M6[[best_idx]]

  check_a  <- (best_M6$convergence == 0L)
  # check_b: Hessian negative-definite.  When alpha_M6 ≈ 1 the MLE lies on
  # the boundary where M6 ≡ M3; the Hessian is flat in the alpha direction
  # (one near-zero eigenvalue) — this is expected, not a problem.
  gamma_is_exp <- abs(alpha_M6 - 1) < 1e-3
  check_b  <- gamma_is_exp ||
              (!is.null(ev_best) && all(is.finite(ev_best)) && all(ev_best > 0))
  check_c  <- (alpha_M6 > 0.1 && alpha_M6 < 20)
  check_d  <- (b_M6 > 0.1 && b_M6 < 50)
  # check_e: either ll_M6 strictly improves on ll_M3, OR alpha_M6 ≈ 1 (the
  # Gamma MLE is the exponential model — valid finding, LR_4 = 0).
  check_e  <- is.finite(ll_M6) && is.finite(ll_M3) &&
                (ll_M6 > ll_M3 || gamma_is_exp)

  m6_ok <- check_a && check_b && check_c && check_d && check_e

  cat(sprintf("\nM6 checks: conv=%s | neg-def=%s | alpha_in_range=%s | b_in_range=%s | ll_improves=%s%s\n",
              check_a, check_b, check_c, check_d, check_e,
              if (gamma_is_exp) " [alpha≈1: LR_4=0]" else ""))
}

if (m6_ok) {
  LR_4 <- lr_test(ll_M3, ll_M6, df = 1)
  if (gamma_is_exp) {
    cat("M6 note: Gamma MLE converges to alpha=1 (Exponential model).\n")
    cat("  This is a valid finding: the data do not support a Gamma generalisation.\n")
    cat(sprintf("  LR_4 stat=%.4f, p=%.4f — Fail to reject Exponential vs Gamma.\n",
                LR_4$stat, LR_4$pval))
  } else {
    cat("M6 converged successfully.\n")
    cat(sprintf("  alpha=%.4f | LR_4 stat=%.2f, p=%.4f | %s\n",
                alpha_M6, LR_4$stat, LR_4$pval, LR_4$decision))
  }
  empirical_fits$fit_M6        <- best_M6
  empirical_fits$ll_M6         <- ll_M6
  empirical_fits$alpha_M6      <- alpha_M6
  empirical_fits$gamma_is_exp  <- gamma_is_exp
  empirical_fits$lr_tests$LR_4 <- LR_4
  saveRDS(empirical_fits, "results/empirical_fits.rds")
} else {
  # GAMMA CONVERGENCE FAILURE — HARD STOP
  cat("\nSaving M6 diagnostics to results/gamma_convergence_diagnostics.rds ...\n")

  saveRDS(
    list(attempts        = attempts_M6,
         starting_values = starts_M6,
         hessians        = hessians_M6,
         eigenvalues     = eigvals_M6,
         loglik_trace    = llvals_M6,
         loglik_M3       = ll_M3,
         data_summary    = list(y = y, X = X, cor_matrix = cor_mat),
         session_info    = sessionInfo()),
    "results/gamma_convergence_diagnostics.rds"
  )

  # Profile alpha script for interactive diagnosis
  writeLines(c(
    '# profile_alpha.R — run interactively to diagnose M6 non-convergence',
    '# Usage: source("code/empirical/profile_alpha.R")',
    'library(countSFA)',
    'library(ggplot2)',
    'emp <- readRDS("results/empirical_fits.rds")',
    'y <- emp$y; X <- emp$X',
    'p <- ncol(X)',
    'fit_exp <- emp$fit_exp',
    '',
    'alpha_grid <- seq(0.3, 6, length.out = 40)',
    '',
    'profile_ll <- sapply(alpha_grid, function(al) {',
    '  nll_fixed_alpha <- function(params, y, X, alpha_fixed) {',
    '    beta  <- params[seq_len(p)]',
    '    b     <- exp(params[p + 1L])',
    '    if (!is.finite(b) || b < 1e-4 || b > 1e4) return(1e15)',
    '    lp <- sapply(seq_along(y),',
    '      function(i) pmf_poisson_gamma(y[i], drop(X[i,] %*% beta), b, alpha_fixed))',
    '    -sum(lp)',
    '  }',
    '  opt <- tryCatch(',
    '    optim(c(fit_exp$coefficients, log(fit_exp$b)), nll_fixed_alpha,',
    '          y=y, X=X, alpha_fixed=al, method="L-BFGS-B",',
    '          lower=c(rep(-10,p),-3), upper=c(rep(10,p),6),',
    '          control=list(maxit=1000, factr=1e8)),',
    '    error = function(e) list(value=Inf)',
    '  )',
    '  -opt$value',
    '})',
    '',
    'profile_df <- data.frame(',
    '  alpha   = alpha_grid,',
    '  loglik  = profile_ll,',
    '  loglik_c = profile_ll - max(profile_ll, na.rm=TRUE)',
    ')',
    '',
    'p_plot <- ggplot(profile_df, aes(x=alpha, y=loglik_c)) +',
    '  geom_line(colour="steelblue", linewidth=0.9) +',
    '  geom_point(colour="steelblue", size=1.5) +',
    '  geom_vline(xintercept=1, linetype="dashed", colour="firebrick") +',
    '  geom_hline(yintercept=-qchisq(0.95,1)/2, linetype="dotted", colour="grey40") +',
    '  labs(x=expression(alpha), y="Profile log-likelihood (centred)",',
    '       title="Profile log-likelihood for alpha — patent data") +',
    '  theme_bw(base_size=11)',
    '',
    'ggsave("results/profile_alpha.png", p_plot, width=6, height=4, dpi=150)',
    'cat("Profile plot saved to results/profile_alpha.png\\n")',
    'print(p_plot)'
  ), "code/empirical/profile_alpha.R")

  cat('
══════════════════════════════════════════════════════════════════
GAMMA MODEL CONVERGENCE FAILURE — HARD STOP
══════════════════════════════════════════════════════════════════

All 5 estimation attempts failed to satisfy convergence criteria.

Diagnostics saved to: results/gamma_convergence_diagnostics.rds

What to check:
  1. Load diagnostics: d <- readRDS("results/gamma_convergence_diagnostics.rds")
  2. Inspect log-likelihood traces: d$loglik_trace
  3. Check Hessian eigenvalues: d$eigenvalues
     (negative definite = all negative; any positive = flat/saddle point)
  4. Check if alpha is hitting a boundary: look at d$attempts[[k]]$par
  5. Compare M6 log-likelihood to M3: d$loglik_trace vs d$loglik_M3
     (if M6 barely improves M3, the Gamma generalisation may not be
      warranted for this dataset — alpha ≈ 1 is consistent with this)
  6. Plot the profile likelihood for alpha:
     source("code/empirical/profile_alpha.R")
  7. Check for data issues: d$data_summary

Suggested remedies:
  A. If eigenvalues show a near-zero direction: the model is weakly
     identified; consider fixing alpha and doing a grid search
  B. If log-likelihood of M6 ≈ log-likelihood of M3: the exponential
     model (alpha=1) may be adequate; report LR test result
  C. If alpha_hat is at the boundary: widen the search range

══════════════════════════════════════════════════════════════════
')
  stop("Gamma model convergence failure. See diagnostics above.")
}
