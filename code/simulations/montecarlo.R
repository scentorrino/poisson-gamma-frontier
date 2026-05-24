# =============================================================================
# montecarlo.R
# Monte Carlo validation of the Poisson stochastic frontier MLE.
# Sourced by 05-simulations.qmd (chunks set #| cache: true).
#
# All three experiments share a common backbone so the production, cost, and
# scaling validations are directly comparable:
#
#   x_i        = (1, z_i),  z_i ~ N(0, 1)
#   beta_true  = (1, 0.5)
#   u_i        ~ Gamma(alpha_true, b_i)                (rate parametrisation)
#   Y_i | u_i  ~ Poisson(exp(x_i' beta_true +- u_i))   (- production / + cost)
#
# Experiment 1 (Homogeneous production):
#   b_i = b_true; alpha_true in {1, 2}; b_true in {1, 2}; n in {500, 1000, 2500}
#   R = 1000.   Output: code/simulations/results.rds
#
# Experiment 2 (Homogeneous cost, same DGP, sign flipped):
#   Same grid as Experiment 1.  At cost b_true = 1 the marginal mean does not
#   exist and at b_true <= 2 the marginal variance does not exist
#   (Section 3 of the paper); estimation, the conditional log-likelihood, and
#   the efficiency score remain well-defined for every b > 0 (Section 3,
#   conditional-moment-existence argument).  Output: code/simulations/cost_results.rds
#
# Experiment 3 (Scaling model on b, production):
#   b_i = b_true * exp(-z__i' delta_true), with z__i = (z_1, z_2)
#   ~ N(0, 1) independent of z_i and of each other.   alpha_true = 1 fixed
#   at the exponential corollary.  b_true = 2 (a single anchor; the
#   determinants generate per-observation variation).  Four delta scenarios.
#   Output: code/simulations/scaling_results.rds
# =============================================================================

library(countSFA)
library(parallel)


# =============================================================================
# Shared design constants
# =============================================================================

beta_true <- c(1, 0.5)
n_vals    <- c(500L, 1000L, 2500L)
R         <- 1000L 
mc_cores  <- if (.Platform$OS.type == "windows") 1L else
             max(1L, detectCores() - 1L)


# =============================================================================
# Fast efficiency-score evaluator
# Closed-form for alpha = 1; trapezoid integration for alpha != 1.
# Computes only the posterior mean E[exp(-u)|y] (no CI, for speed).
# Handles both orientations.
# =============================================================================

te_scores_mc <- function(y, a, b, alpha,
                         orientation = c("production", "cost"),
                         n_grid = 120L) {

  orientation <- match.arg(orientation)

  # ---- alpha = 1: closed-form path -----------------------------------------
  if (abs(alpha - 1) < 1e-10) {

    if (orientation == "production") {
      # lower-incomplete-gamma ratio (Proposition 2)
      log_r <- lgamma(y + b + 1) +
        pgamma(exp(a), shape = y + b + 1, rate = 1, log.p = TRUE) -
        lgamma(y + b) -
        pgamma(exp(a), shape = y + b,     rate = 1, log.p = TRUE)
      return(exp(-a + log_r))
    }

    # cost: upper-incomplete-gamma ratio when y - b - 1 > 0; otherwise
    # quadrature (the closed-form's pgamma path requires positive shape).
    ok_closed <- (y - b - 1) > 0
    out       <- rep(NA_real_, length(y))
    if (any(ok_closed)) {
      yi <- y[ok_closed]
      log_r <- lgamma(yi - b - 1) +
        pgamma(exp(a[ok_closed]), shape = yi - b - 1, rate = 1,
               lower.tail = FALSE, log.p = TRUE) -
        lgamma(yi - b) -
        pgamma(exp(a[ok_closed]), shape = yi - b, rate = 1,
               lower.tail = FALSE, log.p = TRUE)
      out[ok_closed] <- exp(a[ok_closed] + log_r)
    }
    if (any(!ok_closed)) {
      # Fall through to the integration branch below for these.
      idx <- which(!ok_closed)
      out[idx] <- te_scores_mc(y[idx], a[idx], b, alpha = 1.0000001,
                               orientation = "cost", n_grid = n_grid)
    }
    return(out)
  }

  # ---- General alpha (and cost-alpha=1 fallback): trapezoid ---------------
  if (orientation == "production") {
    mapply(function(yi, ai) {
      u_mode <- max(ai - log(max(yi + b, 1)), 1e-4)
      width  <- 8 / sqrt(yi + b + 1)
      ug     <- seq(max(u_mode - width, 1e-6), u_mode + 3 * width,
                    length.out = n_grid)
      lk     <- -exp(ai - ug) - (yi + b) * ug +
        (alpha - 1) * log(ug)
      lk     <- lk - max(lk)
      h      <- exp(lk)
      wts    <- diff(ug)
      h_mid  <- (h[-n_grid] + h[-1]) / 2
      eu_mid <- (exp(-ug[-n_grid]) + exp(-ug[-1])) / 2
      sum(h_mid * eu_mid * wts) / sum(h_mid * wts)
    }, y, a)
  } else {
    # cost orientation: posterior kernel in u is
    #   h(u) propto exp(-(b - y) u - exp(a + u)) * u^{alpha - 1}
    # mode is near u* = a - log(max(b - y, 1)) when b > y, else near 0.
    mapply(function(yi, ai) {
      shape_v <- max(b - yi, 1)
      u_mode  <- max(ai - log(shape_v), 1e-4)
      width   <- 8 / sqrt(shape_v + 1)
      ug      <- seq(max(u_mode - width, 1e-6), u_mode + 3 * width,
                     length.out = n_grid)
      lk      <- -(b - yi) * ug - exp(ai + ug) + (alpha - 1) * log(ug)
      lk      <- lk - max(lk)
      h       <- exp(lk)
      wts     <- diff(ug)
      h_mid   <- (h[-n_grid] + h[-1]) / 2
      eu_mid  <- (exp(-ug[-n_grid]) + exp(-ug[-1])) / 2
      sum(h_mid * eu_mid * wts) / sum(h_mid * wts)
    }, y, a)
  }
}


# =============================================================================
# Single-replication worker (homogeneous frontier, either orientation)
# =============================================================================

run_one_rep <- function(seed, n, alpha_true, b_true,
                        orientation = c("production", "cost")) {

  orientation <- match.arg(orientation)
  sign_u      <- if (orientation == "production") -1 else +1

  set.seed(seed)

  # --- Generate data -------------------------------------------------------
  z    <- rnorm(n)
  X    <- cbind(1, z)
  u    <- rgamma(n, shape = alpha_true, rate = b_true)
  lam  <- exp(drop(X %*% beta_true) + sign_u * u)
  y    <- rpois(n, lam)
  te_true <- exp(-u)               # one-sided "effort": same in both
                                    # orientations as we report exp(-u)

  # --- Poisson GLM ---------------------------------------------------------
  glm_fit   <- suppressWarnings(glm(y ~ z, family = poisson()))
  beta_pois <- coef(glm_fit)
  se_pois   <- sqrt(diag(vcov(glm_fit)))

  # --- Exp frontier --------------------------------------------------------
  exp_fit <- tryCatch(
    suppressWarnings(fit_poisson_frontier(y, X, dist = "exponential",
                                          orientation = orientation)),
    error = function(e) NULL
  )
  if (!is.null(exp_fit)) {
    a_exp    <- drop(X %*% exp_fit$coefficients)
    te_exp   <- te_scores_mc(y, a_exp, exp_fit$b, alpha = 1,
                             orientation = orientation)
    mae_exp  <- mean(abs(te_exp - te_true), na.rm = TRUE)
    conv_exp <- exp_fit$convergence
  } else {
    exp_fit  <- list(coefficients = c(NA, NA), se = c(NA, NA),
                     b = NA, se_b = NA, convergence = 99L)
    mae_exp  <- NA_real_
    conv_exp <- 99L
  }

  # --- Gamma frontier ------------------------------------------------------
  gam_fit <- tryCatch(
    suppressWarnings(fit_poisson_frontier(y, X, dist = "gamma",
                                          orientation = orientation)),
    error = function(e) NULL
  )
  if (!is.null(gam_fit)) {
    a_gam    <- drop(X %*% gam_fit$coefficients)
    te_gam   <- te_scores_mc(y, a_gam, gam_fit$b, gam_fit$alpha,
                             orientation = orientation)
    mae_gam  <- mean(abs(te_gam - te_true), na.rm = TRUE)
    conv_gam <- gam_fit$convergence
  } else {
    gam_fit  <- list(coefficients = c(NA, NA), se = c(NA, NA),
                     b = NA, se_b = NA,
                     alpha = NA, se_alpha = NA, convergence = 99L)
    mae_gam  <- NA_real_
    conv_gam <- 99L
  }

  data.frame(
    # Poisson GLM
    b1_pois  = unname(beta_pois[1]),
    b2_pois  = unname(beta_pois[2]),
    se1_pois = unname(se_pois[1]),
    se2_pois = unname(se_pois[2]),

    # Exp frontier
    b1_exp   = unname(exp_fit$coefficients[1]),
    b2_exp   = unname(exp_fit$coefficients[2]),
    b_exp    = exp_fit$b,
    se1_exp  = unname(exp_fit$se[1]),
    se2_exp  = unname(exp_fit$se[2]),
    seb_exp  = exp_fit$se_b,
    conv_exp = conv_exp,
    mae_exp  = mae_exp,

    # Gamma frontier
    b1_gam   = unname(gam_fit$coefficients[1]),
    b2_gam   = unname(gam_fit$coefficients[2]),
    b_gam    = gam_fit$b,
    al_gam   = gam_fit$alpha,
    se1_gam  = unname(gam_fit$se[1]),
    se2_gam  = unname(gam_fit$se[2]),
    seb_gam  = gam_fit$se_b,
    seal_gam = if (!is.na(gam_fit$se_alpha)) gam_fit$se_alpha else NA_real_,
    conv_gam = conv_gam,
    mae_gam  = mae_gam,

    stringsAsFactors = FALSE
  )
}


# =============================================================================
# Summary builder: one call per (orientation, DGP), filling bias/RMSE/coverage
# =============================================================================

compute_stats <- function(est, se, true_val) {
  ok        <- is.finite(est) & is.finite(se)
  bias      <- mean(est[ok] - true_val, na.rm = TRUE)
  rmse      <- sqrt(mean((est[ok] - true_val)^2, na.rm = TRUE))
  ci_lo     <- est[ok] - 1.96 * se[ok]
  ci_hi     <- est[ok] + 1.96 * se[ok]
  coverage  <- mean(ci_lo <= true_val & true_val <= ci_hi, na.rm = TRUE)
  conv_rate <- mean(ok)
  data.frame(bias = bias, rmse = rmse, coverage = coverage,
             conv_rate = conv_rate)
}

build_summary <- function(mc_wide, dgp_grid) {
  rows <- list()
  for (g in seq_len(nrow(dgp_grid))) {
    a_t <- dgp_grid$alpha_true[g]
    b_t <- dgp_grid$b_true[g]
    n_g <- dgp_grid$n[g]
    sub <- mc_wide[mc_wide$alpha_true == a_t &
                     mc_wide$b_true   == b_t &
                     mc_wide$n        == n_g, ]
    if (nrow(sub) == 0L) next

    push <- function(model, param, est, se, true_val) {
      s <- compute_stats(est, se, true_val)
      rows[[length(rows) + 1L]] <<- data.frame(
        alpha_true = a_t, b_true = b_t, n = n_g,
        model = model, param = param, true_val = true_val,
        s, stringsAsFactors = FALSE
      )
    }
    add_te_mae <- function(model, mae_col, conv_col) {
      ok <- conv_col == 0L
      rows[[length(rows) + 1L]] <<- data.frame(
        alpha_true = a_t, b_true = b_t, n = n_g,
        model = model, param = "TE_MAE", true_val = 0,
        bias = mean(mae_col[ok], na.rm = TRUE),
        rmse = sd  (mae_col[ok], na.rm = TRUE),
        coverage = NA_real_,
        conv_rate = mean(ok),
        stringsAsFactors = FALSE
      )
    }

    # Poisson GLM: beta1, beta2
    push("Poisson", "beta1", sub$b1_pois, sub$se1_pois, 1)
    push("Poisson", "beta2", sub$b2_pois, sub$se2_pois, 0.5)

    # Exp frontier
    ok_e <- sub$conv_exp == 0L
    push("Exp", "beta1", sub$b1_exp[ok_e], sub$se1_exp[ok_e], 1)
    push("Exp", "beta2", sub$b2_exp[ok_e], sub$se2_exp[ok_e], 0.5)
    push("Exp", "b",     sub$b_exp [ok_e], sub$seb_exp[ok_e], b_t)
    add_te_mae("Exp", sub$mae_exp, sub$conv_exp)

    # Gamma frontier
    ok_g <- sub$conv_gam == 0L
    push("Gamma", "beta1", sub$b1_gam[ok_g],  sub$se1_gam[ok_g],  1)
    push("Gamma", "beta2", sub$b2_gam[ok_g],  sub$se2_gam[ok_g],  0.5)
    push("Gamma", "b",     sub$b_gam[ok_g],   sub$seb_gam[ok_g],  b_t)
    push("Gamma", "alpha", sub$al_gam[ok_g],  sub$seal_gam[ok_g], a_t)
    add_te_mae("Gamma", sub$mae_gam, sub$conv_gam)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}


# =============================================================================
# EXPERIMENT 1: Homogeneous production frontier
# =============================================================================

dgp_grid_prod <- expand.grid(
  alpha_true = c(1, 2),
  b_true     = c(1, 2),
  n          = n_vals,
  stringsAsFactors = FALSE
)


set.seed(42L)
seeds_prod <- matrix(sample.int(.Machine$integer.max,
                                nrow(dgp_grid_prod) * R),
                     nrow = nrow(dgp_grid_prod), ncol = R)

message(sprintf(
  "Experiment 1 (production): %d DGPs x %d reps = %d fits on %d cores.",
  nrow(dgp_grid_prod), R, nrow(dgp_grid_prod) * R, mc_cores
))

dgp_results_prod <- parallel::mclapply(seq_len(nrow(dgp_grid_prod)), function(g) {
  a_t <- dgp_grid_prod$alpha_true[g]
  b_t <- dgp_grid_prod$b_true[g]
  n_g <- dgp_grid_prod$n[g]
  message(sprintf("[prod %d/%d] alpha=%g b=%g n=%d", g,
                  nrow(dgp_grid_prod), a_t, b_t, n_g))
  rows <- vector("list", R)
  for (r in seq_len(R)) {
    if (r %% 100L == 0L)
      message(sprintf("  [prod DGP %d] rep %d/%d", g, r, R))
    rows[[r]] <- run_one_rep(seeds_prod[g, r], n_g, a_t, b_t, "production")
  }
  cbind(alpha_true = a_t, b_true = b_t, n = n_g,
        rep = seq_len(R), do.call(rbind, rows),
        stringsAsFactors = FALSE)
}, mc.cores = mc_cores)

mc_wide_prod    <- do.call(rbind, dgp_results_prod)
rownames(mc_wide_prod) <- NULL
mc_summary_prod <- build_summary(mc_wide_prod, dgp_grid_prod)

saveRDS(
  list(mc_wide    = mc_wide_prod,
       mc_summary = mc_summary_prod,
       dgp_grid   = dgp_grid_prod,
       R          = R,
       beta_true  = beta_true,
       orientation = "production"),
  file = "code/simulations/prod_results.rds"
)
message("Experiment 1 complete: code/simulations/prod_results.rds")

# =============================================================================
# EXPERIMENT 2: Homogeneous cost frontier (SAME DGP, sign flipped)
# =============================================================================
# At b_true = 1 the marginal mean does not exist (alpha * log(b/(b-1))
# diverges); at b_true <= 2 the marginal variance does not exist.  The
# conditional log-likelihood and the conditional efficiency score remain
# well-defined for every b > 0 (Section 3 of the paper).  We run the cost
# MC at the same (alpha, b, n) grid as production so the two experiments
# are directly comparable; results at b = 1 are reported with a footnote
# describing the moment-existence caveat.

dgp_grid_cost <- dgp_grid_prod   # identical grid

set.seed(20260503L)
seeds_cost <- matrix(sample.int(.Machine$integer.max,
                                nrow(dgp_grid_cost) * R),
                     nrow = nrow(dgp_grid_cost), ncol = R)

message(sprintf(
  "Experiment 2 (cost): %d DGPs x %d reps = %d fits on %d cores.",
  nrow(dgp_grid_cost), R, nrow(dgp_grid_cost) * R, mc_cores
))

dgp_results_cost <- parallel::mclapply(seq_len(nrow(dgp_grid_cost)), function(g) {
  a_t <- dgp_grid_cost$alpha_true[g]
  b_t <- dgp_grid_cost$b_true[g]
  n_g <- dgp_grid_cost$n[g]
  message(sprintf("[cost %d/%d] alpha=%g b=%g n=%d", g,
                  nrow(dgp_grid_cost), a_t, b_t, n_g))
  rows <- vector("list", R)
  for (r in seq_len(R)) {
    if (r %% 100L == 0L)
      message(sprintf("  [cost DGP %d] rep %d/%d", g, r, R))
    rows[[r]] <- run_one_rep(seeds_cost[g, r], n_g, a_t, b_t, "cost")
  }
  cbind(alpha_true = a_t, b_true = b_t, n = n_g,
        rep = seq_len(R), do.call(rbind, rows),
        stringsAsFactors = FALSE)
}, mc.cores = mc_cores)

mc_wide_cost    <- do.call(rbind, dgp_results_cost)
rownames(mc_wide_cost) <- NULL
mc_summary_cost <- build_summary(mc_wide_cost, dgp_grid_cost)

saveRDS(
  list(mc_wide    = mc_wide_cost,
       mc_summary = mc_summary_cost,
       dgp_grid   = dgp_grid_cost,
       R          = R,
       beta_true  = beta_true,
       orientation = "cost"),
  file = "code/simulations/cost_results.rds"
)
message("Experiment 2 complete: code/simulations/cost_results.rds")

# =============================================================================
# EXPERIMENT 3: Scaling model (alpha = 1)
# =============================================================================
# Harmonised with the homogeneous DGP:
#   x_i        = (1, x_i),  x_i ~ N(0, 1)
#   beta_true  = (1, 0.5)
#   z_i        = (z_{1i}, z_{2i}),  z_1 ~ N(0, 1) and z_2 ~ N(0, 1)
#                independent of z_i and of each other
#   b_i        = b_true * exp(-z_i' delta_true)
#   u_i        ~ Exp(b_i)     (alpha = 1, the exponential corollary)
#   Y_i | u_i  ~ Poisson(exp(x_i' beta_true +/- u_i))

beta_sc_true <- beta_true   # same as Experiments 1-2
b_sc_true    <- 2

delta_scenarios <- list(
  list(id = 1L, label = "Weak (0.3, 0.2)",        delta = c( 0.3,  0.2), orientation = "production"),
  list(id = 2L, label = "Strong (1.0, 0.5)",      delta = c( 1.0,  0.5), orientation = "production"),
  list(id = 3L, label = "Weak (0.3, 0.2)",        delta = c( 0.3,  0.2), orientation = "cost"),
  list(id = 4L, label = "Strong (1.0, 0.5)",      delta = c( 1.0,  0.5), orientation = "cost")
)

# ---- Single-replication worker for the scaling experiment -----------------
# Both the homogeneous and scaling fits are produced by countSFA's native
# fit_poisson_frontier(): the scaling model is selected by passing a Z matrix
# of inefficiency determinants; orientation flips between production and cost.
# Efficiency scores use countSFA::efficiency_scores(), which internally honours
# the Z slot of the fit object.

run_one_scaling <- function(seed, n, delta_true,
                            orientation = c("production", "cost")) {

  orientation <- match.arg(orientation)
  sign_u      <- if (orientation == "production") -1 else +1

  set.seed(seed)

  x_1     <- rnorm(n)                  # same backbone as Experiments 1-2
  z_1     <- rnorm(n)
  z_2     <- rnorm(n)
  X       <- cbind(1, x_1)
  Z       <- cbind(z_1, z_2)

  b_i_true <- b_sc_true * exp(-drop(Z %*% delta_true))
  u        <- rexp(n, rate = b_i_true)
  a_true   <- drop(X %*% beta_sc_true)
  y        <- rpois(n, exp(a_true + sign_u * u))
  te_true  <- exp(-u)

  k <- ncol(X); m <- ncol(Z)

  # ---- Homogeneous MLE (countSFA native) ----------------------------------
  fit_ho <- tryCatch(
    suppressWarnings(fit_poisson_frontier(y, X, dist = "exponential",
                                          orientation = orientation)),
    error = function(e) NULL
  )
  if (!is.null(fit_ho)) {
    beta_ho_h <- unname(fit_ho$coefficients)
    b_ho_h    <- fit_ho$b
    se_ho     <- unname(fit_ho$se)
    se_b_ho   <- fit_ho$se_b
    ll_ho     <- fit_ho$loglik
    conv_ho   <- fit_ho$convergence
    te_ho     <- tryCatch(efficiency_scores(fit_ho, y, X)$eff_score,
                          error = function(e) rep(NA_real_, n))
    mae_ho    <- mean(abs(te_ho - te_true), na.rm = TRUE)
  } else {
    beta_ho_h <- rep(NA_real_, k); b_ho_h <- NA_real_
    se_ho     <- rep(NA_real_, k); se_b_ho <- NA_real_
    ll_ho     <- NA_real_; conv_ho <- 99L
    te_ho     <- rep(NA_real_, n); mae_ho <- NA_real_
  }

  # ---- Scaling MLE (countSFA native, via Z argument) ----------------------
  fit_sc <- tryCatch(
    suppressWarnings(fit_poisson_frontier(y, X, dist = "exponential", Z = Z,
                                          orientation = orientation)),
    error = function(e) NULL
  )
  if (!is.null(fit_sc)) {
    beta_sc_h  <- unname(fit_sc$coefficients)
    b_sc_h     <- fit_sc$b
    delta_h    <- unname(fit_sc$delta)
    se_beta_sc <- unname(fit_sc$se)
    se_b_sc    <- fit_sc$se_b
    se_delta   <- unname(fit_sc$se_delta)
    ll_sc      <- fit_sc$loglik
    conv_sc    <- fit_sc$convergence
    te_sc      <- tryCatch(efficiency_scores(fit_sc, y, X)$eff_score,
                           error = function(e) rep(NA_real_, n))
    mae_sc     <- mean(abs(te_sc - te_true), na.rm = TRUE)
  } else {
    beta_sc_h  <- rep(NA_real_, k); b_sc_h <- NA_real_
    delta_h    <- rep(NA_real_, m); ll_sc <- NA_real_; conv_sc <- 99L
    se_beta_sc <- rep(NA_real_, k); se_b_sc <- NA_real_
    se_delta   <- rep(NA_real_, m); mae_sc <- NA_real_
  }

  # ---- Two-step (Wang & Schmidt 2002): homogeneous TE -> OLS on z ---------
  delta_ts <- rep(NA_real_, m)
  if (!is.null(fit_ho) && all(is.finite(te_ho)) && all(te_ho > 0)) {
    neg_u_hat <- -log(pmax(te_ho, 1e-10))
    ts_fit    <- tryCatch(lm(neg_u_hat ~ z_1 + z_2),
                          error = function(e) NULL)
    if (!is.null(ts_fit)) {
      cf       <- coef(ts_fit)
      delta_ts <- c(cf["z_1"], cf["z_2"])
    }
  }

  lr_stat <- if (is.finite(ll_sc) && is.finite(ll_ho))
    pmax(2 * (ll_sc - ll_ho), 0) else NA_real_

  data.frame(
    orientation = orientation,

    # Scaling MLE
    b1_sc=beta_sc_h[1], b2_sc=beta_sc_h[2],
    b_sc=b_sc_h, d1_sc=delta_h[1], d2_sc=delta_h[2],
    se_b1_sc=se_beta_sc[1], se_b2_sc=se_beta_sc[2],
    se_b_sc=se_b_sc, se_d1_sc=se_delta[1], se_d2_sc=se_delta[2],
    ll_sc=ll_sc, conv_sc=conv_sc, mae_sc=mae_sc,

    # Homogeneous MLE
    b1_ho=beta_ho_h[1], b2_ho=beta_ho_h[2],
    b_ho=b_ho_h,
    se_b1_ho=se_ho[1], se_b2_ho=se_ho[2],
    se_b_ho=se_b_ho, ll_ho=ll_ho, conv_ho=conv_ho, mae_ho=mae_ho,

    # Two-step
    d1_ts=delta_ts[1], d2_ts=delta_ts[2],

    lr_stat=lr_stat,
    stringsAsFactors=FALSE
  )
}


# ---- Scaling main loop ----------------------------------------------------
R_sc        <- R                       # match homogeneous experiments
mc_cores_sc <- mc_cores

set.seed(20250101L)
results_scaling <- list()
timing_sc       <- list()

for (sc in delta_scenarios) {
  sid  <- sc$id
  d_tr <- sc$delta
  sc_k <- paste0("scenario_", sid)
  sc_orientation <- sc$orientation
  results_scaling[[sc_k]] <- list()

  for (n_val in n_vals) {
    message(sprintf("Scenario %d (%s) | n = %d | starting...",
                    sid, sc_orientation, n_val))
    t0    <- proc.time()["elapsed"]
    seeds <- sample.int(.Machine$integer.max, R_sc)

    reps <- parallel::mclapply(seeds, function(s)
      tryCatch(run_one_scaling(s, n_val, d_tr, sc_orientation),
               error = function(e) NULL),
      mc.cores = mc_cores_sc
    )
    reps_df             <- do.call(rbind, Filter(Negate(is.null), reps))
    reps_df$scenario    <- sid
    reps_df$n           <- n_val
    results_scaling[[sc_k]][[as.character(n_val)]] <- reps_df

    elapsed <- proc.time()["elapsed"] - t0
    timing_sc[[paste0(sc_k, "_n", n_val)]] <- elapsed
    message(sprintf("Scenario %d (%s) | n = %d | done in %.1f sec.",
                    sid, sc_orientation, n_val, elapsed))
  }
}

saveRDS(
  list(results         = results_scaling,
       timing          = timing_sc,
       beta_true       = beta_sc_true,
       b_true          = b_sc_true,
       delta_scenarios = delta_scenarios,
       R               = R_sc),
  file = "code/simulations/scaling_results.rds"
)
message("Experiment 3 (scaling) complete: code/simulations/scaling_results.rds")
