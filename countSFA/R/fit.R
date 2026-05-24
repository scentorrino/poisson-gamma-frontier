#' Fit the Poisson stochastic frontier model by maximum likelihood
#'
#' @param y      Integer vector of count outcomes.
#' @param X      Model matrix (n x k).  Include an intercept column if
#'   desired.
#' @param dist   Character; \code{"exponential"} (fixes alpha = 1) or
#'   \code{"gamma"} (estimates alpha).
#' @param alpha  Optional fixed value for the Gamma shape parameter.  Only
#'   used when \code{dist = "gamma"} and the user wants to profile over alpha
#'   rather than estimate it.  Ignored when \code{dist = "exponential"}.
#' @param starts Optional numeric vector of starting values (on the log-b,
#'   log-alpha scale).  If \code{NULL}, starting values are derived from a
#'   Poisson GLM.
#' @param K      Series truncation for the Gamma PMF.  If \code{NULL}
#'   (default), \code{K} is selected automatically from the Poisson GLM
#'   warm-start as \eqn{K = \min(1000,\, \max(50,\, \lceil 3 \max_i
#'   \hat\lambda_i \rceil))}, where \eqn{\hat\lambda_i} are the GLM
#'   fitted values.  This rule ensures the alternating series in
#'   \code{\link{pmf_poisson_gamma}} is past its peak term \eqn{k^* \approx
#'   e^{a_i}} for every observation.  A scalar value can be passed to
#'   override.  Production orientation only.
#' @param orientation \code{"production"} (default) or \code{"cost"}.
#'   Selects the conditional sign of the inefficiency term.  Cost-frontier
#'   PMF and efficiency-score evaluation rely on adaptive quadrature for
#'   \code{alpha != 1}; estimation is correspondingly slower.
#' @param Z Optional numeric matrix (n x m) of inefficiency determinants
#'   for the scaling model \eqn{b_i = b \exp(-z_i' \delta)}.  When supplied,
#'   the fit estimates the additional \code{delta} block of length
#'   \code{ncol(Z)}.  If \code{NULL} (default) the homogeneous model is
#'   estimated.
#' @param starts_delta Optional numeric vector of starting values for the
#'   scaling coefficients \code{delta}.  Length must equal \code{ncol(Z)}.
#'   Ignored when \code{Z} is \code{NULL}.  Defaults to a zero vector.
#'
#' @return An S3 object of class \code{"poisson_frontier"} with components:
#' \describe{
#'   \item{\code{coefficients}}{Named numeric vector of frontier coefficients
#'     beta (natural scale).}
#'   \item{\code{se}}{Standard errors for beta (delta method).}
#'   \item{\code{b}}{Estimated rate parameter b (natural scale).}
#'   \item{\code{se_b}}{Standard error of b (delta method).}
#'   \item{\code{alpha}}{Gamma shape parameter (fixed or estimated).}
#'   \item{\code{se_alpha}}{Standard error of alpha; \code{NA} if fixed.}
#'   \item{\code{delta}}{Scaling-model coefficients on \code{Z} (length
#'     \code{ncol(Z)}; empty numeric vector when \code{Z} is \code{NULL}).}
#'   \item{\code{se_delta}}{Standard errors for \code{delta} (delta method);
#'     empty when \code{Z} is \code{NULL}.}
#'   \item{\code{Z}}{The supplied determinant matrix, stored on the fit so
#'     that \code{\link{efficiency_scores}} can recover the per-observation
#'     rate \eqn{b_i = b \exp(-z_i' \delta)}.  \code{NULL} when the
#'     homogeneous model was fitted.}
#'   \item{\code{loglik}}{Maximised log-likelihood.}
#'   \item{\code{AIC}}{Akaike information criterion.}
#'   \item{\code{BIC}}{Bayesian information criterion.}
#'   \item{\code{vcov}}{Variance-covariance matrix on the (log-b, log-alpha,
#'     delta) scale (from the numerical Hessian).}
#'   \item{\code{convergence}}{Return code from \code{optim} (0 = success).}
#'   \item{\code{n}}{Sample size.}
#'   \item{\code{dist}}{Distribution string.}
#'   \item{\code{K}}{Series truncation actually used (the auto-selected
#'     value, or the user-supplied value).}
#' }
#'
#' @references
#' Centorrino, S. and Perez Urdiales, M. (2026). Count Data Stochastic
#' Frontier Models with Gamma Inefficiency. Working paper.
#'
#' Aigner, D., Lovell, C. A. K. and Schmidt, P. (1977). Formulation and
#' estimation of stochastic frontier production function models.
#' \emph{Journal of Econometrics} \strong{6}, 21--37.
#'
#' Meeusen, W. and van den Broeck, J. (1977). Efficiency estimation from
#' Cobb-Douglas production functions with composed error.
#' \emph{International Economic Review} \strong{18}, 435--444.
#'
#' Greene, W. H. (1980). Maximum likelihood estimation of econometric
#' frontier functions. \emph{Journal of Econometrics} \strong{13}, 27--56.
#'
#' Greene, W. H. (1990). A gamma-distributed stochastic frontier model.
#' \emph{Journal of Econometrics} \strong{46}, 141--163.
#'
#' Greene, W. H. (2003). Simulated likelihood estimation of the
#' normal-gamma stochastic frontier function. \emph{Journal of
#' Productivity Analysis} \strong{19}, 179--190.
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n  <- 200L
#' X  <- cbind(1, rnorm(n))
#' u  <- rexp(n, rate = 2)
#' y  <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' fit <- fit_poisson_frontier(y, X, dist = "exponential")
#' fit$coefficients
#' c(b = fit$b, loglik = fit$loglik)
#'
#' # Scaling-model fit: b_i = b * exp(-z_i' delta).
#' Z       <- cbind(z1 = rnorm(n))
#' fit_z   <- fit_poisson_frontier(y, X, dist = "exponential", Z = Z)
#' fit_z$delta
#' fit_z$se_delta
#' }
#'
#' @importFrom stats glm fitted var coef optim poisson
#' @export
fit_poisson_frontier <- function(y, X, dist = "exponential",
                                 alpha = NULL, starts = NULL, K = NULL,
                                 orientation = c("production", "cost"),
                                 Z = NULL, starts_delta = NULL) {

  dist        <- match.arg(dist, c("exponential", "gamma"))
  orientation <- match.arg(orientation)
  k           <- ncol(X)
  n           <- length(y)

  # ---- Input validation (m8) ----------------------------------------------
  if (any(is.na(y)) || any(y < 0) || any(y != floor(y))) {
    stop("fit_poisson_frontier: y must contain non-negative integers (no NA).")
  }

  # ---- Scaling-model block -------------------------------------------------
  has_Z <- !is.null(Z)
  if (has_Z) {
    if (!is.matrix(Z)) Z <- as.matrix(Z)
    if (nrow(Z) != n)
      stop("fit_poisson_frontier: nrow(Z) must equal length(y).")
    m <- ncol(Z)
    if (is.null(starts_delta)) {
      delta0 <- rep(0, m)
    } else {
      if (length(starts_delta) != m)
        stop("fit_poisson_frontier: length(starts_delta) must equal ncol(Z).")
      delta0 <- starts_delta
    }
    znames <- colnames(Z)
    if (is.null(znames)) znames <- paste0("z", seq_len(m))
  } else {
    m      <- 0L
    delta0 <- numeric(0L)
    znames <- character(0L)
  }

  # ---- Starting values --------------------------------------------------
  # Poisson GLM is used for the SE-based bound construction below; for the
  # actual starting POINT we use the method-of-moments estimator mom_starts(),
  # which solves the 2-parameter system in (alpha, b) using the OLS residuals
  # on log(Y + 0.5) and corrects the intercept by alpha/b. The Poisson GLM
  # mean is also used to autoset the series truncation K.
  glm0   <- glm(y ~ X - 1, family = poisson())
  beta0  <- unname(coef(glm0))
  mu_hat <- fitted(glm0)

  # Method-of-moments starter for the homogeneous case (no scaling block).
  # When Z is supplied the scaling-model warm-start in countSFA needs only
  # (alpha, b) baseline values, so we still call mom_starts() but the
  # caller will use only its (alpha, b) outputs.
  mom <- mom_starts(y, X, orientation = orientation)

  if (has_Z) {
    # Scaling-model fits use a Poisson-GLM warm-start for beta (the OLS
    # bias correction would clash with the per-observation b_i variation
    # introduced by the determinants) and the MoM (alpha, b) as baseline.
    beta_start <- beta0
  } else {
    beta_start <- mom$beta
  }
  b0    <- mom$b
  alpha0_warm <- mom$alpha

  # ---- Auto-pick series truncation K from Poisson GLM ---------------------
  # The alternating series for the Gamma PMF has ratio |term_{k+1}/term_k|
  # = exp(a_i) / (k+1) and peaks at k* ≈ exp(a_i) = lambda_i, after which
  # it decays super-exponentially. Setting K = 3 * max(lambda_hat) puts the
  # truncation safely past the peak for every observation. The Poisson GLM
  # gives consistent estimates of the slope coefficients (the inefficiency
  # only shifts the intercept), so max(mu_hat) tracks max(lambda_i) up to a
  # multiplicative constant. Floor 50 protects small-lambda datasets;
  # ceiling 1000 caps compute when a single huge fitted value would
  # otherwise blow K up.
  if (is.null(K)) {
    K <- min(10000L, max(50L, as.integer(ceiling(3 * max(mu_hat)))))
  }

  fixed_alpha <- (dist == "exponential") || !is.null(alpha)
  alpha_val   <- if (dist == "exponential") 1.0 else if (!is.null(alpha)) alpha else NULL

  # Bounds on the scaling block: |z' delta| < ~3 is enough to span
  # 2-3 orders of magnitude in b_i.  Widen via starts_delta scale if needed.
  delta_lower <- if (has_Z) rep(-3, m) else numeric(0L)
  delta_upper <- if (has_Z) rep( 3, m) else numeric(0L)

  # Bound beta in optim to (beta_pois +- 6 * SE(beta_pois)) where SE is taken
  # from the Poisson GLM. This is scale-invariant: tighter when the regressor
  # has high variance or n is large, looser when the data carry little
  # information. The Poisson GLM is consistent for the slopes and has a
  # bounded-bias intercept under Gamma inefficiency, so 6 SEs covers any
  # plausible MLE while keeping the alternating series in
  # pmf_poisson_gamma() inside its reliable region.
  beta0_se <- sqrt(pmax(diag(vcov(glm0)), 0))
  # Box width: max of (6 SE) and (3 absolute). The SE term is scale-invariant
  # (it tightens with informative data and loosens with weak data). The
  # 3-unit floor covers the intercept bias of the Poisson GLM under unmodelled
  # inefficiency, which is approximately |alpha * log(b / (b +- 1))| and can
  # exceed 6 SE at moderate-to-large n even for plausible (alpha, b).
  beta0_box  <- pmax(6 * beta0_se, 3)
  beta_lower <- beta0 - beta0_box
  beta_upper <- beta0 + beta0_box

  if (fixed_alpha) {
    par0 <- if (!is.null(starts)) starts else c(beta_start, log(b0), delta0)
    obj  <- function(p) log_lik_poisson_frontier(p, y, X, alpha = alpha_val,
                                                 K = K,
                                                 orientation = orientation,
                                                 Z = Z)

    # Always use L-BFGS-B with log_b bound to [-8, 8] and beta bounded to
    # beta_pois +- 5 (m5 + beta-bound for series-truncation safety).
    lower_bd <- c(beta_lower, -8, delta_lower)
    upper_bd <- c(beta_upper,  8, delta_upper)
    opt <- optim(par0, obj, method = "L-BFGS-B",
                 lower = lower_bd, upper = upper_bd, hessian = TRUE,
                 control = list(maxit = 2000, factr = 1e7))

  } else {
    obj <- function(p) log_lik_poisson_frontier(p, y, X, alpha = NULL,
                                                K = K,
                                                orientation = orientation,
                                                Z = Z)

    # Warm-start strategy: fit exponential first (including delta when
    # Z is supplied), then hand off to Gamma at log_alpha = 0.
    if (is.null(starts)) {
      exp_obj <- function(p) log_lik_poisson_frontier(p, y, X, alpha = 1,
                                                      K = K,
                                                      orientation = orientation,
                                                      Z = Z)
      if (has_Z) {
        exp_lower <- c(beta_lower, -8, delta_lower)
        exp_upper <- c(beta_upper,  8, delta_upper)
        exp_fit <- tryCatch(
          optim(c(beta_start, log(b0), delta0), exp_obj, method = "L-BFGS-B",
                lower = exp_lower, upper = exp_upper,
                control = list(maxit = 1000, factr = 1e7)),
          error = function(e) list(par = c(beta_start, log(b0), delta0),
                                   value = Inf)
        )
        # Insert log_alpha at the MoM-implied value between log_b and delta.
        par0 <- c(exp_fit$par[seq_len(k + 1L)], log(alpha0_warm),
                  exp_fit$par[(k + 2L):(k + 1L + m)])
      } else {
        # L-BFGS-B with log_b bound to [-8, 8] for the warm-start exponential
        # fit, matching the main Gamma optimisation bounds (m5).
        exp_lower <- c(beta_lower, -8)
        exp_upper <- c(beta_upper,  8)
        exp_fit <- tryCatch(
          optim(c(beta_start, log(b0)), exp_obj, method = "L-BFGS-B",
                lower = exp_lower, upper = exp_upper,
                control = list(maxit = 1000, factr = 1e7)),
          error = function(e) list(par = c(beta_start, log(b0)), value = Inf)
        )
        par0 <- c(exp_fit$par, log(alpha0_warm))
      }
    } else {
      par0 <- starts
    }

    # L-BFGS-B bounds. log_b in [-8, 8]; log_alpha in [-2, 4]; delta in [-3, 3].
    lower_bd <- c(beta_lower, -8, -2, delta_lower)
    upper_bd <- c(beta_upper,  8,  4, delta_upper)

    # Multi-start over a log_alpha grid (mean-invariant: at each candidate
    # log_alpha we set log_b_try = log_b_warm + log_alpha so that the implied
    # E[u] = alpha/b at the start matches the exponential warm-start's
    # E[u] = 1/b_warm). The default start (log_alpha = 0) is included; the
    # other points span the alpha range of practical interest. All starts
    # are attempted unconditionally and the lowest-NLL converged fit is
    # retained: this prevents the optimiser from accepting a poor local
    # optimum on a single warm-start chain.
    log_b_warm <- par0[k + 1L]
    delta_warm <- if (has_Z) par0[(k + 3L):(k + 2L + m)] else numeric(0L)
    # Multi-start grid for log_alpha: fixed coverage points
    # {-1, 0, 0.5, 1, 2} plus the MoM-implied log(alpha) when it is
    # outside this range.  Deduplicate to avoid redundant fits.
    starts_grid <- c(0, -1, 0.5, 1, 2)
    if (is.finite(alpha0_warm) && alpha0_warm > 0) {
      la_mom <- log(alpha0_warm)
      if (min(abs(starts_grid - la_mom)) > 0.1) starts_grid <- c(starts_grid, la_mom)
    }
    opt <- list(value = Inf, convergence = 99L)
    for (log_alpha_start in starts_grid) {
      log_b_try <- log_b_warm + log_alpha_start
      par_try   <- c(par0[seq_len(k)], log_b_try, log_alpha_start, delta_warm)
      opt_try <- tryCatch(
        optim(par_try, obj, method = "L-BFGS-B",
              lower = lower_bd, upper = upper_bd,
              hessian = TRUE,
              control = list(maxit = 2000, factr = 1e7)),
        error = function(e) list(value = Inf, convergence = 99L)
      )
      if (opt_try$value < opt$value) opt <- opt_try
    }
  }

  if (opt$convergence != 0L) {
    warning(sprintf(
      "fit_poisson_frontier: optim did not converge (code %d). Estimates may be unreliable.",
      opt$convergence
    ))
  }

  # ---- Extract parameters --------------------------------------------------
  beta_hat <- opt$par[seq_len(k)]
  b_hat    <- exp(opt$par[k + 1L])

  if (!fixed_alpha) {
    alpha_hat <- exp(opt$par[k + 2L])
    next_idx  <- k + 3L
  } else {
    alpha_hat <- alpha_val
    next_idx  <- k + 2L
  }

  if (has_Z) {
    delta_hat <- opt$par[next_idx:(next_idx + m - 1L)]
  } else {
    delta_hat <- numeric(0L)
  }

  # ---- Variance-covariance (Hessian inverse) --------------------------------
  # Reciprocal condition number (m6); a value below 1e-10 indicates that the
  # Hessian is near-singular and the inversion below, while numerically
  # successful, will return extreme entries that yield unreliable SEs.
  hess_rcond <- tryCatch(rcond(opt$hessian), error = function(e) NA_real_)
  if (!is.na(hess_rcond) && hess_rcond < 1e-10) {
    warning(sprintf(
      "fit_poisson_frontier: Hessian is near-singular (rcond = %.2e); standard errors may be unreliable.",
      hess_rcond
    ))
  }
  vcov_raw <- tryCatch(
    solve(opt$hessian),
    error = function(e) {
      warning("fit_poisson_frontier: Hessian is singular; vcov set to NA.")
      matrix(NA_real_, nrow(opt$hessian), ncol(opt$hessian))
    }
  )

  npar <- length(opt$par)
  se_raw <- sqrt(pmax(diag(vcov_raw), 0))

  # Delta method SE for b: SE(b) = b * SE(log_b)
  se_beta  <- se_raw[seq_len(k)]
  se_b     <- b_hat * se_raw[k + 1L]

  if (!fixed_alpha) {
    se_alpha <- alpha_hat * se_raw[k + 2L]
  } else {
    se_alpha <- NA_real_
  }

  if (has_Z) {
    se_delta <- se_raw[next_idx:(next_idx + m - 1L)]
    names(delta_hat) <- znames
    names(se_delta)  <- znames
  } else {
    se_delta <- numeric(0L)
  }

  # Name the coefficient vector
  xnames <- colnames(X)
  if (is.null(xnames)) xnames <- paste0("x", seq_len(k))
  names(beta_hat) <- xnames
  names(se_beta)  <- xnames

  # ---- Information criteria ------------------------------------------------
  ll   <- -opt$value
  aic  <- -2 * ll + 2 * npar
  bic  <- -2 * ll + log(n) * npar

  # ---- Assemble S3 object --------------------------------------------------
  structure(
    list(
      coefficients = beta_hat,
      se           = se_beta,
      b            = b_hat,
      se_b         = se_b,
      alpha        = alpha_hat,
      se_alpha     = se_alpha,
      delta        = delta_hat,
      se_delta     = se_delta,
      Z            = Z,
      loglik       = ll,
      AIC          = aic,
      BIC          = bic,
      vcov         = vcov_raw,
      convergence  = opt$convergence,
      n            = n,
      k            = k,
      dist         = dist,
      orientation  = orientation,
      npar         = npar,
      K            = K
    ),
    class = "poisson_frontier"
  )
}
