#' Posterior efficiency scores E[exp(-u_i) | y_i]
#'
#' For \code{alpha = 1} in either orientation a closed-form expression is
#' used (Proposition 2 in production; the upper-incomplete-gamma analogue
#' in cost when \code{y_i > b + 2}).  Otherwise the posterior mean and
#' second moment are computed by direct numerical integration using
#' \code{\link[stats]{integrate}}.
#'
#' When the supplied fit was estimated with a scaling model on the rate
#' (\code{fit$delta} of positive length), the per-observation rate
#' \eqn{b_i = b \exp(-z_i' \delta)} is used in every closed-form or
#' quadrature path; otherwise the scalar \code{fit$b} is broadcast across
#' observations.
#'
#' The posterior 95\% interval is constructed as
#' \eqn{\hat{TE}_i \pm 1.96 \, \sqrt{\mathrm{E}[e^{-2u}|y_i] - \hat{TE}_i^2}},
#' clipped to [0, 1].
#'
#' @param fit A \code{"poisson_frontier"} object returned by
#'   \code{\link{fit_poisson_frontier}}.  The orientation
#'   (\code{"production"} or \code{"cost"}) stored on the fit is honoured.
#' @param y   Integer vector of outcomes (must match what was passed to
#'   \code{fit_poisson_frontier}).
#' @param X   Model matrix used when fitting.
#'
#' @return A \code{data.frame} with columns:
#' \describe{
#'   \item{\code{i}}{Observation index.}
#'   \item{\code{eff_score}}{Posterior mean efficiency \eqn{\hat{TE}_i \in (0,1)}.}
#'   \item{\code{eff_lower}}{Lower bound of approximate 95\% posterior interval.}
#'   \item{\code{eff_upper}}{Upper bound of approximate 95\% posterior interval.}
#' }
#'
#' @references
#' Centorrino, S. and Perez Urdiales, M. (2026). Count Data Stochastic
#' Frontier Models with Gamma Inefficiency. Working paper.
#'
#' Jondrow, J., Lovell, C. A. K., Materov, I. S. and Schmidt, P. (1982).
#' On the estimation of technical inefficiency in the stochastic frontier
#' production function model. \emph{Journal of Econometrics} \strong{19},
#' 233--238.
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n  <- 200L
#' X  <- cbind(1, rnorm(n))
#' u  <- rexp(n, rate = 2)
#' y  <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' fit <- fit_poisson_frontier(y, X, dist = "exponential")
#' head(efficiency_scores(fit, y, X))
#' }
#'
#' @importFrom stats pgamma integrate qnorm
#' @export
efficiency_scores <- function(fit, y, X) {

  stopifnot(inherits(fit, "poisson_frontier"))

  orientation <- if (!is.null(fit$orientation)) fit$orientation else "production"

  b     <- fit$b
  alpha <- fit$alpha
  beta  <- fit$coefficients
  a     <- drop(X %*% beta)
  n     <- length(y)

  # Per-observation b under the scaling model: b_i = b * exp(-z_i' delta).
  # Falls back to scalar b when the fit was homogeneous (delta length 0).
  if (length(fit$delta) > 0L) {
    if (is.null(fit$Z))
      stop("efficiency_scores: fit$delta is non-empty but fit$Z is missing.")
    b_i <- b * exp(-drop(fit$Z %*% fit$delta))
  } else {
    b_i <- rep(b, n)
  }

  eff_score <- numeric(n)
  eff_lower <- numeric(n)
  eff_upper <- numeric(n)

  for (i in seq_len(n)) {
    yi <- y[i]
    ai <- a[i]

    bi <- b_i[i]
    moments <- if (orientation == "production") {
      .te_moments_production(yi, ai, bi, alpha)
    } else {
      .te_moments_cost(yi, ai, bi, alpha)
    }

    e1 <- moments$e1
    e2 <- moments$e2

    if (is.na(e1)) {
      warning(sprintf("efficiency_scores: integration failed for obs %d; score set to NA.", i))
      eff_score[i] <- NA_real_
      eff_lower[i] <- NA_real_
      eff_upper[i] <- NA_real_
      next
    }

    # u >= 0 implies E[exp(-u) | y] in (0, 1]; numerical excursions just
    # outside that interval (most plausible near the alpha = 1 boundary in
    # the cost orientation, where the closed-form / quadrature dispatch
    # changes) are clipped silently up to 1e-6, and warned-and-clipped past
    # that.  Negative excursions cannot occur from a positive integrand.
    if (e1 > 1) {
      if (e1 > 1 + 1e-6) {
        warning(sprintf(
          "efficiency_scores: e1 = %.6f > 1 for obs %d; clipping to 1.",
          e1, i
        ))
      }
      e1 <- 1
    }
    eff_score[i] <- e1
    post_var     <- pmax(e2 - e1^2, 0)
    post_sd      <- sqrt(post_var)
    eff_lower[i] <- pmax(e1 - 1.96 * post_sd, 0)
    eff_upper[i] <- pmin(e1 + 1.96 * post_sd, 1)
  }

  data.frame(
    i         = seq_len(n),
    eff_score = eff_score,
    eff_lower = eff_lower,
    eff_upper = eff_upper
  )
}

# ----------------------------------------------------------------------------
# Production-frontier per-observation moments.
# ----------------------------------------------------------------------------
.te_moments_production <- function(yi, ai, b, alpha) {

  if (abs(alpha - 1) < 1e-10) {
    # Closed-form (Proposition 2)
    log_pgamma_base <- lgamma(yi + b) +
      pgamma(exp(ai), shape = yi + b, rate = 1, log.p = TRUE)

    log_r1 <- lgamma(yi + b + 1) +
      pgamma(exp(ai), shape = yi + b + 1, rate = 1, log.p = TRUE) -
      log_pgamma_base
    e1 <- exp(-ai + log_r1)

    log_r2 <- lgamma(yi + b + 2) +
      pgamma(exp(ai), shape = yi + b + 2, rate = 1, log.p = TRUE) -
      log_pgamma_base
    e2 <- exp(-2 * ai + log_r2)

    return(list(e1 = e1, e2 = e2))
  }

  # General alpha: production-frontier posterior kernel in u, evaluated
  # without the constant y*a factor (which would otherwise overflow at
  # large y*a) and with log-max stabilisation (M1), mirroring the cost path.
  #
  #   h(u) propto exp(-lambda e^{-u} - (y+b) u) u^{alpha-1}
  log_kern <- function(u) {
    u <- pmax(u, 1e-300)
    -exp(ai - u) - (yi + b) * u + (alpha - 1) * log(u)
  }

  # alpha = 1 mode as starting point; one Newton step toward the true FOC
  # root for alpha != 1 (m3): lambda e^{-u} = (y + b) - (alpha - 1) / u.
  u_mode <- pmax(ai - log(pmax(yi + b, 1)), 1e-4)
  if (abs(alpha - 1) > 1e-10) {
    num <- (alpha - 1) / u_mode                          # ~ f(u_mode)
    den <- (yi + b) + (alpha - 1) / (u_mode * u_mode)    # ~ -f'(u_mode)
    if (is.finite(num) && is.finite(den) && den > 0) {
      du <- num / den
      du <- max(min(du, u_mode / 2), -u_mode / 2)
      u_mode <- pmax(u_mode + du, 1e-4)
    }
  }
  width <- 10 / sqrt(yi + b + 1)
  u_lo  <- pmax(u_mode - width, 1e-6)
  u_hi  <- u_mode + 3 * width

  # Stability shift: subtract max(log_kern) on a coarse grid before
  # exponentiating. The shift cancels in the ratios I_c / I_0.
  u_grid   <- seq(u_lo, u_hi, length.out = 200L)
  log_vals <- log_kern(u_grid)
  log_vals[!is.finite(log_vals)] <- -Inf
  log_max  <- max(log_vals)
  if (!is.finite(log_max)) return(list(e1 = NA_real_, e2 = NA_real_))

  Ic <- function(c_pow) {
    tryCatch(
      integrate(function(u) exp(log_kern(u) - c_pow * u - log_max),
                lower = u_lo, upper = u_hi,
                rel.tol = 1e-7, abs.tol = 0,
                subdivisions = 500L)$value,
      error = function(e) NA_real_
    )
  }

  I0 <- Ic(0)
  I1 <- Ic(1)
  I2 <- Ic(2)

  if (is.na(I0) || I0 <= 0) return(list(e1 = NA_real_, e2 = NA_real_))
  list(e1 = I1 / I0, e2 = I2 / I0)
}

# ----------------------------------------------------------------------------
# Cost-frontier per-observation moments.
#
# Cost posterior kernel in u:
#   h(u) ∝ u^(alpha-1) exp((y-b)*u - exp(a+u)),  u > 0
# E[exp(-c u) | y] = J(c) / J(0) where
#   J(c) = int_0^Inf u^(alpha-1) exp((y - b - c)*u - exp(a+u)) du
#        = e^{-a(y-b-c)} int_{exp(a)}^Inf (log v - a)^(alpha-1) v^(y-b-c-1) e^{-v} dv
# (substitution v = exp(a + u)).  The v-form has single-exponential damping
# and is integrated by adaptive quadrature.
#
# At alpha = 1 with y - b > 2, both J(1) and J(2) reduce to upper incomplete
# gamma functions with positive shape, allowing a fully closed-form ratio.
# ----------------------------------------------------------------------------
.te_moments_cost <- function(yi, ai, b, alpha) {

  is_exp <- (abs(alpha - 1) < 1e-10)

  # Closed-form via upper incomplete gamma: e1 requires shape y-b-1 > 0
  # (m2 relaxes the prior y-b > 2 gate); e2 still requires y-b-2 > 0. We
  # try the closed form first and fall through to quadrature for whichever
  # moment has non-positive shape.
  log_upper <- function(s) {
    lgamma(s) + pgamma(exp(ai), shape = s, rate = 1,
                       lower.tail = FALSE, log.p = TRUE)
  }
  if (is_exp && (yi - b) > 2) {
    log_den <- log_upper(yi - b)
    e1 <- exp(    ai + log_upper(yi - b - 1) - log_den)
    e2 <- exp(2 * ai + log_upper(yi - b - 2) - log_den)
    return(list(e1 = e1, e2 = e2))
  }

  # General path: quadrature in v-space.  J(c) shares the same integrand
  # structure as the cost PMF, with shape (y - b - c - 1) on v.  Guard
  # against extreme a producing overflow.
  if (!is.finite(ai) || ai > 500) return(list(e1 = NA_real_, e2 = NA_real_))
  ea <- exp(ai)
  if (!is.finite(ea)) return(list(e1 = NA_real_, e2 = NA_real_))

  # Build a single integrand factory
  J <- function(c) {
    log_int <- function(v) {
      lv_diff <- pmax(log(v) - ai, .Machine$double.xmin)
      (alpha - 1) * log(lv_diff) + (yi - b - c - 1) * log(v) - v
    }

    # alpha = 1 mode of v^{y-b-c-1} e^{-v} is max(ea + 1, y-b-c-1). For
    # alpha != 1 apply one Newton step toward the joint mode of
    # (log v - a)^{alpha-1} v^{y-b-c-1} e^{-v} when the Gamma mode is
    # interior to (ea, infty) (m9).
    v_mode <- max(ea + 1, yi - b - c - 1)
    if (abs(alpha - 1) > 1e-10 && (yi - b - c - 1) > ea) {
      lvd <- log(v_mode) - ai
      if (lvd > 0) {
        num <- (alpha - 1) / lvd
        den <- (alpha - 1) / (lvd * lvd * v_mode) + 1
        if (is.finite(num) && is.finite(den) && den > 0) {
          dv <- num / den
          dv <- max(min(dv, v_mode / 2), -v_mode / 2)
          v_mode <- max(v_mode + dv, ea + 1e-3)
        }
      }
    }
    v_sd <- sqrt(max(yi - b - c, 1) + alpha)
    v_hi <- v_mode + max(20 * v_sd, 50)

    v_grid   <- seq(ea, v_hi, length.out = 200L)
    log_vals <- log_int(v_grid)
    log_vals[!is.finite(log_vals)] <- -Inf
    log_max  <- max(log_vals)
    if (!is.finite(log_max)) return(list(log_J = -Inf))

    # Integrate over [ea, v_hi]; do NOT use upper = Inf (integrate's
    # infinite-bound substitution destroys narrow peaks far inside the
    # domain - see .log_pmf_cost in pmf.R for the matching guard).
    I <- tryCatch(
      integrate(function(v) exp(log_int(v) - log_max),
                lower = ea, upper = v_hi,
                rel.tol = 1e-8, abs.tol = 0,
                subdivisions = 500L)$value,
      error = function(e) NA_real_
    )

    if (is.na(I) || I <= 0) return(list(log_J = NA_real_))
    list(log_J = log(I) + log_max)
  }

  # log J(c) plus the e^{-a(y-b-c)} prefactor cancels common terms when
  # computing E[e^{-c u}] = J(c) / J(0):
  # log E = -a(y-b-c) + log J_v(c) - [-a(y-b) + log J_v(0)] = a*c + log J_v(c) - log J_v(0)
  log_J0 <- J(0)$log_J
  log_J2 <- J(2)$log_J

  if (!is.finite(log_J0) || is.na(log_J0)) return(list(e1 = NA_real_, e2 = NA_real_))
  if (is.na(log_J2))                       return(list(e1 = NA_real_, e2 = NA_real_))

  # e1: closed form via upper incomplete gamma when shape y-b-1 > 0 and
  # alpha = 1 (m2); quadrature otherwise.
  if (is_exp && (yi - b) > 1) {
    e1 <- exp(ai + log_upper(yi - b - 1) - log_upper(yi - b))
  } else {
    log_J1 <- J(1)$log_J
    if (is.na(log_J1)) return(list(e1 = NA_real_, e2 = NA_real_))
    e1 <- exp(ai + log_J1 - log_J0)
  }
  e2 <- exp(2 * ai + log_J2 - log_J0)
  list(e1 = e1, e2 = e2)
}
