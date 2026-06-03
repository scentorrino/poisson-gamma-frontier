# =============================================================================
# cwa_application.R
#
# Empirical application of the Poisson stochastic *production* frontier to
# U.S. EPA Clean Water Act NPDES facility data, in the under-detection
# interpretation.
#
# DGP framing (production frontier, Section 2 of the paper):
#   Y_i^*  | x_i    ~ Poisson( exp(x_i' beta) )       (latent true NC count)
#   Y_i    | Y_i^*  ~ Binomial( Y_i^*, exp(-u_i) )    (Poisson thinning)
#   ==> Y_i | x_i, u_i ~ Poisson( exp(x_i' beta - u_i) ),  u_i >= 0
#
# Interpretation:
#   exp(x_i' beta)        = LATENT true non-compliance rate at facility i
#   u_i                   = under-detection intensity (>= 0)
#   E[exp(-u_i) | Y_i]    = posterior DETECTION RATE at facility i
#   beta                  = effect of facility characteristics on the true rate
#   delta (scaling model) = effect of monitoring/enforcement covariates on u
#                          (b_i = b * exp(-z_i' delta); see Section 3 of paper)
#
# Outcome:
#   y = CWA_QTRS_WITH_NC, the count of quarters (0-13) in any non-compliance
#       status (RNC, violation, or SNC) over the rolling 13-quarter DMR
#       window. Treated as observed non-compliance count, which is a lower
#       bound on the latent true count because each quarter's classification
#       depends on DMR review / inspector coverage.
#   The auxiliary column `snc_qtrs` (count of 'S' = SNC quarters) is also
#       in the panel for diagnostics and severity-threshold robustness checks.
#
# Sample:
#   CWA majors (NPDES_FLAG=Y, FAC_MAJOR_FLAG=Y, active permit), n=14,310.
#   See data/epa_echo/build_cwa_panel.py for the panel construction.
#
# Models fitted (production-orientation throughout):
#   M1  Poisson GLM                       (baseline; misspecified)
#   M2  Exp frontier  (alpha = 1)         (homogeneous)
#   M3  Gamma frontier (alpha free)       (homogeneous)
#   M4  Exp frontier  + scaling on Z      (heterogeneous detection)
#   M5  Gamma frontier + scaling on Z     (heterogeneous detection + alpha)
#
# Output (saved to results/cwa_fits.rds):
#   $data, $X, $y, $Z
#   $fit_pois, $fit_exp, $fit_gam, $fit_M4, $fit_M5
#   $scores_exp, $scores_gam       (homogeneous detection-rate posteriors)
#   $scores_M4, $scores_M5         (scaling detection-rate posteriors, b_i)
#   $lr_tests
#
# Per-model caches in results/cwa_fit_<name>.rds so re-runs are incremental.
#
# Usage:
#   Rscript code/empirical/cwa_application.R                # full sample
#   Rscript code/empirical/cwa_application.R --sample 2000  # 2k for testing
#   Rscript code/empirical/cwa_application.R --no-gamma     # skip M3, M5
#   Rscript code/empirical/cwa_application.R --no-scaling   # skip M4, M5
# =============================================================================

suppressPackageStartupMessages({
  library(countSFA)
  library(data.table)
})

# -----------------------------------------------------------------------------
# 0. Argument handling and paths
# -----------------------------------------------------------------------------
args     <- commandArgs(trailingOnly = TRUE)
n_sample <- {
  i <- match("--sample", args)
  if (!is.na(i) && length(args) >= i + 1L) as.integer(args[i + 1L]) else NA_integer_
}
do_gamma   <- !("--no-gamma"   %in% args)
do_scaling <- !("--no-scaling" %in% args)

PANEL_CSV <- "data/epa_echo/cwa_facility_panel.csv"
RES_DIR   <- "results"
dir.create(RES_DIR, showWarnings = FALSE, recursive = TRUE)

OUT_RDS    <- file.path(RES_DIR, "cwa_fits.rds")
CACHE_POIS <- file.path(RES_DIR, "cwa_fit_pois.rds")
CACHE_EXP  <- file.path(RES_DIR, "cwa_fit_exp.rds")
CACHE_GAM  <- file.path(RES_DIR, "cwa_fit_gam.rds")
CACHE_M4   <- file.path(RES_DIR, "cwa_fit_M4.rds")
CACHE_M5   <- file.path(RES_DIR, "cwa_fit_M5.rds")
CACHE_SCEX <- file.path(RES_DIR, "cwa_scores_exp.rds")
CACHE_SCGM <- file.path(RES_DIR, "cwa_scores_gam.rds")
CACHE_SCM4 <- file.path(RES_DIR, "cwa_scores_M4.rds")
CACHE_SCM5 <- file.path(RES_DIR, "cwa_scores_M5.rds")

cat("\n", strrep("=", 70), "\n", sep = "")
cat("CWA production-frontier application (HPV under-detection framing)\n")
cat(sprintf("  Sample size  : %s\n",
            if (is.na(n_sample)) "FULL (~14k CWA majors)"
            else sprintf("%d (subsample for testing)", n_sample)))
cat(sprintf("  Fit Gamma?   : %s\n", if (do_gamma)   "yes" else "no"))
cat(sprintf("  Fit scaling? : %s\n", if (do_scaling) "yes" else "no"))
cat(strrep("=", 70), "\n\n", sep = "")


# -----------------------------------------------------------------------------
# 1. Helpers
# -----------------------------------------------------------------------------

# 50-state-to-EPA-region mapping (EPA reports 10 regions).
EPA_REGION <- c(
  CT = 1, ME = 1, MA = 1, NH = 1, RI = 1, VT = 1,
  NJ = 2, NY = 2, PR = 2, VI = 2,
  DE = 3, DC = 3, MD = 3, PA = 3, VA = 3, WV = 3,
  AL = 4, FL = 4, GA = 4, KY = 4, MS = 4, NC = 4, SC = 4, TN = 4,
  IL = 5, IN = 5, MI = 5, MN = 5, OH = 5, WI = 5,
  AR = 6, LA = 6, NM = 6, OK = 6, TX = 6,
  IA = 7, KS = 7, MO = 7, NE = 7,
  CO = 8, MT = 8, ND = 8, SD = 8, UT = 8, WY = 8,
  AZ = 9, CA = 9, HI = 9, NV = 9, AS = 9, GU = 9, MP = 9,
  AK = 10, ID = 10, OR = 10, WA = 10
)

# Load-or-compute cache wrapper.
cached <- function(path, expr) {
  if (file.exists(path)) {
    cat(sprintf("  (cached) loading %s\n", path))
    return(readRDS(path))
  }
  result <- eval(expr, envir = parent.frame())
  saveRDS(result, path)
  cat(sprintf("  (cached) wrote   %s\n", path))
  result
}


# -----------------------------------------------------------------------------
# 2. Load and clean panel
# -----------------------------------------------------------------------------

cat("[1/6] Loading panel...\n")
if (!file.exists(PANEL_CSV)) {
  stop("Missing ", PANEL_CSV,
       " — regenerate by running data/epa_echo/build_cwa_panel.py")
}
dat <- fread(PANEL_CSV, na.strings = c("", "NA"))
cat(sprintf("  Panel rows: %s\n", format(nrow(dat), big.mark = ",")))

# Drop the handful with no state-region match (EPA_REGION lookup NA).
dat[, region := EPA_REGION[FAC_STATE]]
n_pre <- nrow(dat)
dat <- dat[!is.na(region)]
cat(sprintf("  Dropped %s rows with unknown state\n",
            format(n_pre - nrow(dat), big.mark = ",")))
# Drop locations with 0 or missing population density 
dat <- dat[!is.na(dat$FAC_POP_DEN) & dat$FAC_POP_DEN > 0,]

# Factor encodings
dat[, region  := factor(region, levels = 1:10)]

# Bundle small sectors to keep the X matrix well-conditioned. The categories
# created by build_cwa_panel.py already concentrate >95% of rows in the eight
# largest 2-digit NAICS sectors; the remaining "other" / "unknown" buckets
# soak up the rest.
dat <- dat[!(dat$sector2 == "unknown" | dat$sector2 == "other"), ]
dat[, sector2 := factor(sector2)]
dat[, sector2 := relevel(sector2, ref = "22")]   # water/wastewater as baseline

# Optional sub-sample for fast iteration
if (!is.na(n_sample) && nrow(dat) > n_sample) {
  set.seed(42L)
  dat <- dat[sample(.N, n_sample)]
  cat(sprintf("  --sample: drew %s rows for testing\n",
              format(nrow(dat), big.mark = ",")))
}
# Drop now-empty factor levels (subsampling can vacate some).
dat[, region  := droplevels(region)]
dat[, sector2 := droplevels(sector2)]

y <- as.integer(dat$y)

cat("\n[2/6] Outcome summary (observed non-compliance quarters):\n")
cat(sprintf("  n         : %d\n", length(y)))
cat(sprintf("  Mean      : %.3f\n", mean(y)))
cat(sprintf("  Variance  : %.3f\n", var(y)))
cat(sprintf("  Var/Mean  : %.2f\n", var(y) / mean(y)))
cat(sprintf("  Min/Med/Max: %d / %g / %d\n",
            min(y), median(y), max(y)))
cat(sprintf("  Quantiles 50/75/90/95/99: %s\n",
            paste(quantile(y, c(.5, .75, .9, .95, .99)), collapse = " / ")))
cat(sprintf("  Zero share: %.1f%%\n", 100 * mean(y == 0)))


# -----------------------------------------------------------------------------
# 3. Design matrices
# -----------------------------------------------------------------------------

cat("\n[3/6] Building design matrices...\n")

# Pre-compute log-transformed regressors. log1p stabilises the right tail of
# count and dollar variables and keeps zero as a meaningful baseline.
dat[, log_insp        := log1p(FAC_INSPECTION_COUNT)]
dat[, log_days_insp   := log1p(FAC_DAYS_LAST_INSPECTION / 365)]
dat[, log_informal    := log1p(FAC_INFORMAL_COUNT)]
dat[, log_formal      := log1p(FAC_FORMAL_ACTION_COUNT)]
dat[, log_penalty_amt := log1p(FAC_LAST_PENALTY_AMT)]
dat[, log_total_pen   := log1p(FAC_TOTAL_PENALTIES)]
dat[, log_pop_den     := log(FAC_POP_DEN)]

# ---- Frontier X: drivers of the LATENT true HPV rate ----------------------
# These are facility characteristics that determine the underlying propensity
# to generate SNC-eligible violations, independent of detection.
#   sector2          - 2-digit NAICS bucket (water/wastewater is baseline)
#   region           - EPA region (1-10); state heterogeneity in regulatory
#                      baselines and water-quality conditions
#   log_insp         - log(1+ total inspections); scale/risk proxy. Inspectors
#                      target larger / higher-risk facilities, so this loads
#                      on the true rate. Caveat: also correlated with detection
#                      effort; identification of (beta_insp, delta_*) discussed
#                      in Section 6 of the paper.
#   FAC_PERCENT_MINORITY, log_pop_den - location/EJ context
#   FAC_INDIAN_CNTRY_FLG_Y, FAC_IMP_WATER_FLG_Y - regulatory context flags
#   AIR_FLAG_Y, RCRA_FLAG_Y, TRI_FLAG_Y, GHG_FLAG_Y - co-regulation indicators
#                      (proxy for facility complexity / multimedia footprint)
form_x <- ~ sector2 + 
            region +
            log_insp +
            FAC_PERCENT_MINORITY + log_pop_den +
            FAC_INDIAN_CNTRY_FLG_Y + FAC_IMP_WATER_FLG_Y +
            AIR_FLAG_Y + RCRA_FLAG_Y + TRI_FLAG_Y + GHG_FLAG_Y
X <- model.matrix(form_x, data = dat)
cat(sprintf("  X dim: %d x %d  (frontier covariates)\n", nrow(X), ncol(X)))

# ---- Scaling Z: drivers of UNDER-DETECTION u --------------------------------
# Scaling model: b_i = b * exp(-z_i' delta).  Positive delta_j increases b_i,
# which DECREASES E[u_i] = alpha / b_i, i.e. shrinks the under-detection wedge.
# So positive delta_j on a monitoring/enforcement covariate means "more of z_j
# improves detection" - that's the substantively expected sign.
#
#   log_days_insp   - log(1+ years since last inspection); HIGHER => worse
#                     detection => expected delta < 0
#   log_formal      - log(1+ formal enforcement actions); HIGHER => stronger
#                     enforcement signal => expected delta > 0
#   log_total_pen   - log(1+ cumulative penalty dollars); HIGHER => stronger
#                     enforcement => expected delta > 0
#   FAC_PERCENT_MINORITY - EJ context; the literature documents systematic
#                     under-monitoring of high-minority communities, so
#                     expected delta < 0. Dual-use (also in X); identification
#                     comes from the multiplicative structure of the
#                     conditional Gamma rather than from an exclusion.
Z <- cbind(
  log_days_insp        = dat$log_days_insp,
  log_formal           = dat$log_formal,
  log_total_pen        = dat$log_total_pen,
  FAC_PERCENT_MINORITY = dat$FAC_PERCENT_MINORITY
)
Z[!is.finite(Z)] <- 0
cat(sprintf("  Z dim: %d x %d  (scaling-model determinants)\n",
            nrow(Z), ncol(Z)))


# -----------------------------------------------------------------------------
# 4. Fit cascade of models
# -----------------------------------------------------------------------------

cat("\n[4/6] Fitting models...\n")

# --- M1: Poisson GLM baseline ----------------------------------------------
fit_pois <- cached(CACHE_POIS, quote({
  cat("  M1 Poisson GLM ...\n")
  glm(y ~ X - 1, family = poisson())
}))

# --- M2: Exp production frontier (homogeneous) -----------------------------
# Two-step estimator. Under the homogeneous DGP the conditional mean is
# log-linear in x'beta with the inefficiency contribution absorbed by the
# intercept, so the Poisson QMLE delivers consistent slope estimates. The
# frontier likelihood then recovers (beta_0, log_b). The full (k+1)-dim
# Hessian is evaluated at the converged point via optimHess.
fit_exp_manual <- function(y, X, beta_pois, K = NULL, orientation = "cost") {
  k <- ncol(X)

  nll_2d <- function(par2) {
    v <- suppressWarnings(
      log_lik_poisson_frontier(par2, y, X, alpha = 1, K = K,
                               orientation = orientation)
    )
    if (!is.finite(v) || v >= .Machine$double.xmax * 0.5) return(1e8)
    v
  }
  start2 <- c(beta_pois, log(2.5))
  lower2 <- c(rep(-30, k), -2)
  upper2 <- c(rep( 30, k),  6)

  cat(sprintf("    starting NLL = %.2f\n", nll_2d(start2)))
  opt <- tryCatch(
    optim(start2, nll_2d, method = "L-BFGS-B",
          lower = lower2, upper = upper2,
          control = list(maxit = 2000, factr = 1e8, trace = 1, REPORT = 5)),
    error = function(e) {
      cat("    optim error:", conditionMessage(e), "\n"); NULL
    }
  )
  if (is.null(opt) || !is.finite(opt$value) || opt$value >= 1e7) return(NULL)

  beta_hat  <- opt$par[1:k]
  log_b_hat <- opt$par[k + 1L]
  full_par  <- c(beta_hat, log_b_hat)

  nll_full <- function(par) {
    v <- suppressWarnings(
      log_lik_poisson_frontier(par, y, X, alpha = 1, K = K,
                               orientation = orientation)
    )
    if (!is.finite(v) || v >= .Machine$double.xmax * 0.5) return(1e8)
    v
  }
  H <- tryCatch(optimHess(full_par, nll_full),
                error = function(e) {
                  cat("    optimHess failed:", conditionMessage(e), "\n")
                  matrix(NA_real_, k + 1L, k + 1L)
                })
  vcov_raw <- tryCatch(solve(H),
                       error = function(e) {
                         cat("    Hessian singular\n")
                         matrix(NA_real_, k + 1L, k + 1L)
                       })
  se_raw <- sqrt(pmax(diag(vcov_raw), 0))
  b_hat  <- exp(log_b_hat)
  list(par          = full_par,
       coefficients = setNames(beta_hat, colnames(X)),
       se           = se_raw[seq_len(k)],
       b            = b_hat,
       se_b         = b_hat * se_raw[k + 1L],
       alpha        = 1,
       se_alpha     = NA_real_,
       loglik       = -opt$value,
       AIC          = 2 * (k + 1L) + 2 * opt$value,
       BIC          = log(length(y)) * (k + 1L) + 2 * opt$value,
       vcov         = vcov_raw,
       hessian      = H,
       convergence  = opt$convergence,
       n            = length(y),
       k            = k,
       dist         = "exponential",
       orientation  =  orientation,
       npar         = k + 1L,
       K            = K)
}

fit_exp <- cached(CACHE_EXP, quote({
  cat("  M2 Exp production frontier (two-step from Poisson GLM, L-BFGS-B) ...\n")
  t0 <- proc.time()
  res <- fit_exp_manual(y, X, beta_pois = coef(fit_pois))
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  if (!is.null(res)) class(res) <- "poisson_frontier"
  res
}))

# --- M3: Gamma production frontier (homogeneous) ---------------------------
fit_gamma_manual <- function(y, X, beta_start, K = NULL, log_b_warm, orientation = "cost") {
  k <- ncol(X)

  nll_3d <- function(par3) {
    suppressWarnings(
      log_lik_poisson_frontier(par3, y, X, alpha = NULL,
                               orientation = orientation, K = K)
    )
  }
  start3 <- c(beta_start, log_b_warm, 1)
  lower3 <- c(rep(-30, k), -5, -2)
  upper3 <- c(rep(30, k), 5, 2)
  cat(sprintf("    starting NLL = %.2f\n", nll_3d(start3)))
  opt <- tryCatch(
    optim(start3, nll_3d, method = "L-BFGS-B",
          lower = lower3, upper = upper3,
          control = list(maxit = 2000, factr = 1e8, trace = 1, REPORT = 5)),
    error = function(e) {
      cat("    optim error:", conditionMessage(e), "\n"); NULL
    }
  )
  if (is.null(opt) || !is.finite(opt$value) || opt$value >= 1e7) return(NULL)

  beta_hat      <- opt$par[1:k]
  log_b_hat     <- opt$par[k + 1L]
  log_alpha_hat <- opt$par[k + 2L]
  full_par      <- c(beta_hat, log_b_hat, log_alpha_hat)

  nll_full <- function(par) {
    v <- suppressWarnings(
      log_lik_poisson_frontier(par, y, X, alpha = NULL, K = K,
                               orientation =  orientation)
    )
    if (!is.finite(v) || v >= .Machine$double.xmax * 0.5) return(1e8)
    v
  }
  H <- tryCatch(optimHess(full_par, nll_full),
                error = function(e) {
                  cat("    optimHess failed:", conditionMessage(e), "\n")
                  matrix(NA_real_, k + 2L, k + 2L)
                })
  vcov_raw <- tryCatch(solve(H),
                       error = function(e) {
                         cat("    Hessian singular\n")
                         matrix(NA_real_, k + 2L, k + 2L)
                       })
  se_raw    <- sqrt(pmax(diag(vcov_raw), 0))
  b_hat     <- exp(log_b_hat)
  alpha_hat <- exp(log_alpha_hat)
  list(par          = full_par,
       coefficients = setNames(beta_hat, colnames(X)),
       se           = se_raw[seq_len(k)],
       b            = b_hat,
       se_b         = b_hat * se_raw[k + 1L],
       alpha        = alpha_hat,
       se_alpha     = alpha_hat * se_raw[k + 2L],
       loglik       = -opt$value,
       AIC          = 2 * (k + 2L) + 2 * opt$value,
       BIC          = log(length(y)) * (k + 2L) + 2 * opt$value,
       vcov         = vcov_raw,
       hessian      = H,
       convergence  = opt$convergence,
       n            = length(y),
       k            = k,
       dist         = "gamma",
       orientation  = orientation,
       npar         = k + 2L,
       K            = K)
}

fit_gam <- if (do_gamma) cached(CACHE_GAM, quote({
  cat("  M3 Gamma production frontier (two-step from M2, L-BFGS-B) ...\n")
  if (is.null(fit_exp)) {
    cat("    skipped — M2 fit unavailable for warm start\n"); NULL
  } else {
    t0 <- proc.time()
    res <- fit_gamma_manual(y, X,
                            beta_start = fit_exp$par[1:ncol(X)],
                            log_b_warm = log(fit_exp$b))
    cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
    if (!is.null(res)) class(res) <- "poisson_frontier"
    res
  }
})) else NULL


# -----------------------------------------------------------------------------
# 5. Scaling-model extensions (M4 = Exp+Z, M5 = Gamma+Z)
# -----------------------------------------------------------------------------
# Scaling model (Section 3 of the paper):
#   b_i = b * exp(-z_i' delta),    so log b_i = log b - z_i' delta
# and the per-observation log-PMF is the Poisson-Gamma marginal evaluated at
# (a_i = x_i' beta, b_i, alpha) via pmf_poisson_gamma in the production
# orientation. Optimisation is full-information; the betas from M2/M3 serve
# as warm starts for M4/M5.

nll_scaling <- function(params, y, X, Z, alpha = NULL, K = NULL,
                        orientation = c("production", "cost")) {
  orientation <- match.arg(orientation)
  k <- ncol(X); m <- ncol(Z)
  beta  <- params[seq_len(k)]
  log_b <- params[k + 1L]
  has_alpha <- is.null(alpha)
  if (has_alpha) {
    log_alpha <- params[k + 2L]
    delta_idx <- (k + 3L):(k + 2L + m)
  } else {
    log_alpha <- log(alpha)
    delta_idx <- (k + 2L):(k + 1L + m)
  }
  delta <- params[delta_idx]
  a  <- drop(X %*% beta)
  bi <- exp(log_b - drop(Z %*% delta))
  if (any(!is.finite(bi))) return(1e8)
  al <- exp(log_alpha)
  ll <- vapply(seq_along(y),
               function(i) pmf_poisson_gamma(y[i], a[i], bi[i], al,
                                              K = K,
                                              orientation = orientation),
               numeric(1L))
  if (any(!is.finite(ll)) || -sum(ll) >= .Machine$double.xmax * 0.5)
    return(1e8)
  -sum(ll)
}

fit_scaling <- function(y, X, Z, dist, fit_warm,
                        orientation = "production", K = NULL) {
  k <- ncol(X); m <- ncol(Z)
  fixed_alpha <- (dist == "exponential")
  beta_warm   <- if (!is.null(fit_warm$coefficients)) fit_warm$coefficients
                 else fit_warm$beta
  delta_warm  <- if (!is.null(fit_warm$delta)) fit_warm$delta else rep(0, m)
  if (length(delta_warm) != m) delta_warm <- rep(0, m)

  if (fixed_alpha) {
    par0  <- c(beta_warm, log(fit_warm$b), delta_warm)
    lower <- c(rep(-30, k), -5,            rep(-3, m))
    upper <- c(rep( 30, k),  8,            rep( 3, m))
  } else {
    par0  <- c(beta_warm, log(fit_warm$b),
               log(if (!is.null(fit_warm$alpha)) fit_warm$alpha else 1),
               delta_warm)
    lower <- c(rep(-30, k), -5, -2, rep(-3, m))
    upper <- c(rep( 30, k),  8,  6, rep( 3, m))
  }
  alpha_arg <- if (fixed_alpha) 1 else NULL
  obj <- function(p) nll_scaling(p, y, X, Z, alpha = alpha_arg,
                                 K = K, orientation = orientation)
  opt <- tryCatch(
    optim(par0, obj, method = "L-BFGS-B",
          lower = lower, upper = upper, hessian = TRUE,
          control = list(maxit = 2000, factr = 1e7)),
    error = function(e) NULL
  )
  if (is.null(opt) || !is.finite(opt$value)) return(NULL)
  beta_hat <- opt$par[seq_len(k)]
  b_hat    <- exp(opt$par[k + 1L])
  if (fixed_alpha) {
    alpha_hat <- 1
    delta_hat <- opt$par[(k + 2L):(k + 1L + m)]
  } else {
    alpha_hat <- exp(opt$par[k + 2L])
    delta_hat <- opt$par[(k + 3L):(k + 2L + m)]
  }
  names(delta_hat) <- colnames(Z)
  vcov_raw <- tryCatch(solve(opt$hessian),
                       error = function(e) matrix(NA_real_,
                                                  nrow(opt$hessian),
                                                  ncol(opt$hessian)))
  list(par         = opt$par,
       beta        = setNames(beta_hat, colnames(X)),
       b           = b_hat,
       alpha       = alpha_hat,
       delta       = delta_hat,
       loglik      = -opt$value,
       convergence = opt$convergence,
       hessian     = opt$hessian,
       vcov        = vcov_raw,
       npar        = length(opt$par),
       AIC         = 2 * length(opt$par) + 2 * opt$value,
       dist        = dist,
       orientation = orientation,
       K           = K)
}

fit_M4 <- if (do_scaling && !is.null(fit_exp)) cached(CACHE_M4, quote({
  cat("  M4 Exp + scaling on Z ...\n")
  t0 <- proc.time()
  res <- fit_scaling(y, X, Z, dist = "exponential", fit_warm = fit_exp,
                     orientation = "cost")
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  res
})) else NULL

fit_M5 <- if (do_gamma && do_scaling && !is.null(fit_M4)) cached(CACHE_M5, quote({
  cat("  M5 Gamma + scaling on Z ...\n")
  t0 <- proc.time()
  res <- fit_scaling(y, X, Z, dist = "gamma", fit_warm = fit_gam,
                     orientation = "cost")
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  res
})) else NULL


# -----------------------------------------------------------------------------
# 6. Likelihood-ratio tests + detection-rate posteriors
# -----------------------------------------------------------------------------

cat("\n[5/6] LR tests and information criteria...\n")

ll <- function(f) {
  if (is.null(f)) return(NA_real_)
  if (!is.null(f$loglik)) return(f$loglik)
  if (inherits(f, "glm")) return(as.numeric(logLik(f)))
  NA_real_
}

ll_M1 <- ll(fit_pois); ll_M2 <- ll(fit_exp); ll_M3 <- ll(fit_gam)
ll_M4 <- ll(fit_M4);   ll_M5 <- ll(fit_M5)

lr_test <- function(ll_alt, ll_null, df) {
  if (any(is.na(c(ll_alt, ll_null)))) return(list(stat = NA, pval = NA))
  s <- 2 * (ll_alt - ll_null)
  list(stat = s, pval = 1 - pchisq(max(s, 0), df = df))
}

lr_tests <- list(
  M3_vs_M2 = lr_test(ll_M3, ll_M2, df = 1L),
  M4_vs_M2 = lr_test(ll_M4, ll_M2, df = ncol(Z)),
  M5_vs_M3 = lr_test(ll_M5, ll_M3, df = ncol(Z)),
  M5_vs_M4 = lr_test(ll_M5, ll_M4, df = 1L)
)

cat("  Log-likelihoods:\n")
cat(sprintf("    M1 Poisson         : %s\n", format(round(ll_M1, 1), big.mark = ",")))
cat(sprintf("    M2 Exp frontier    : %s\n", format(round(ll_M2, 1), big.mark = ",")))
cat(sprintf("    M3 Gamma frontier  : %s\n", format(round(ll_M3, 1), big.mark = ",")))
cat(sprintf("    M4 Exp + scaling   : %s\n", format(round(ll_M4, 1), big.mark = ",")))
cat(sprintf("    M5 Gamma + scaling : %s\n", format(round(ll_M5, 1), big.mark = ",")))
cat("\n  LR tests:\n")
for (k in names(lr_tests)) {
  t <- lr_tests[[k]]
  cat(sprintf("    %-10s stat=%s  p=%s\n",
              k,
              if (is.na(t$stat)) "  NA" else sprintf("%6.2f", t$stat),
              if (is.na(t$pval)) "  NA" else sprintf("%.4f", t$pval)))
}

# Detection-rate posteriors: TE_i = E[exp(-u_i) | y_i] under each homogeneous
# fit. Under the under-detection framing these are interpreted as the
# fraction of latent HPV that is observed at facility i.
cat("\n[6/6] Computing detection-rate posteriors...\n")

scores_exp <- if (!is.null(fit_exp)) cached(CACHE_SCEX, quote({
  cat("  M2 detection-rate scores ...\n")
  t0 <- proc.time()
  s <- tryCatch(
    suppressWarnings(efficiency_scores(fit_exp, y, X)),
    error = function(e) { cat("    ERROR:", conditionMessage(e), "\n"); NULL }
  )
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  s
})) else NULL

scores_gam <- if (do_gamma && !is.null(fit_gam)) cached(CACHE_SCGM, quote({
  cat("  M3 detection-rate scores ...\n")
  t0 <- proc.time()
  s <- tryCatch(
    suppressWarnings(efficiency_scores(fit_gam, y, X)),
    error = function(e) { cat("    ERROR:", conditionMessage(e), "\n"); NULL }
  )
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  s
})) else NULL

if (!is.null(scores_exp)) {
  s <- scores_exp$eff_score
  cat("\n  M2 detection-rate distribution (interpretation: fraction of latent HPV observed):\n")
  cat(sprintf("    Mean: %.3f  Median: %.3f  Min: %.3f  Max: %.3f\n",
              mean(s, na.rm = TRUE), median(s, na.rm = TRUE),
              min(s, na.rm = TRUE), max(s, na.rm = TRUE)))
}

# Scaling-model detection-rate posteriors. countSFA::efficiency_scores honours
# the per-observation rate b_i = b * exp(-z_i' delta) whenever fit$delta has
# positive length and fit$Z is present, so the scores reflect the heterogeneous
# detection wedge driven by the monitoring/enforcement covariates in Z. The
# fit_scaling() result stores beta under $beta and omits the class/$Z that
# efficiency_scores expects, so we adapt it to the poisson_frontier shape first.
as_pf_scaling <- function(fit, Z) {
  if (is.null(fit)) return(NULL)
  fit$coefficients <- if (!is.null(fit$beta)) fit$beta else fit$coefficients
  fit$Z <- Z
  class(fit) <- "poisson_frontier"
  fit
}

scores_M4 <- if (!is.null(fit_M4)) cached(CACHE_SCM4, quote({
  cat("  M4 detection-rate scores (heterogeneous b_i) ...\n")
  t0 <- proc.time()
  s <- tryCatch(
    suppressWarnings(efficiency_scores(as_pf_scaling(fit_M4, Z), y, X)),
    
    error = function(e) { cat("    ERROR:", conditionMessage(e), "\n"); NULL }
  )
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  s
})) else NULL

scores_M5 <- if (do_gamma && !is.null(fit_M5)) cached(CACHE_SCM5, quote({
  cat("  M5 detection-rate scores (heterogeneous b_i) ...\n")
  t0 <- proc.time()
  s <- tryCatch(
    suppressWarnings(efficiency_scores(as_pf_scaling(fit_M5, Z), y, X)),
    error = function(e) { cat("    ERROR:", conditionMessage(e), "\n"); NULL }
  )
  cat(sprintf("    elapsed: %.1f sec\n", (proc.time() - t0)["elapsed"]))
  s
})) else NULL

for (nm in c("M4", "M5")) {
  sc <- if (nm == "M4") scores_M4 else scores_M5
  if (!is.null(sc)) {
    s <- sc$eff_score
    cat(sprintf("\n  %s detection-rate distribution (heterogeneous detection wedge):\n", nm))
    cat(sprintf("    Mean: %.3f  Median: %.3f  Min: %.3f  Max: %.3f\n",
                mean(s, na.rm = TRUE), median(s, na.rm = TRUE),
                min(s, na.rm = TRUE), max(s, na.rm = TRUE)))
  }
}


# -----------------------------------------------------------------------------
# 7. Save
# -----------------------------------------------------------------------------

saveRDS(
  list(
    data        = dat,
    y           = y,
    X           = X,
    Z           = Z,
    fit_pois    = fit_pois,
    fit_exp     = fit_exp,
    fit_gam     = fit_gam,
    fit_M4      = fit_M4,
    fit_M5      = fit_M5,
    scores_exp  = scores_exp,
    scores_gam  = scores_gam,
    scores_M4   = scores_M4,
    scores_M5   = scores_M5,
    lr_tests    = lr_tests,
    n_sample    = n_sample,
    session     = sessionInfo()
  ),
  OUT_RDS
)

cat(sprintf("\nDone. All fits and scores saved to %s\n", OUT_RDS))
cat(sprintf("Per-fit caches in %s/cwa_fit_*.rds\n", RES_DIR))
