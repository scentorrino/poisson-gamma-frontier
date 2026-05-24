#' Log PMF of the Poisson-Gamma stochastic frontier model
#'
#' Evaluates log P(Y = y) for a single observation under either the
#' production-frontier orientation (\eqn{Y \mid u \sim
#' \mathrm{Poisson}(\lambda e^{-u})}) or the cost-frontier orientation
#' (\eqn{Y \mid u \sim \mathrm{Poisson}(\lambda e^{+u})}).  In the production
#' case, \code{alpha = 1} uses the closed-form lower-incomplete-gamma
#' expression and \code{alpha != 1} uses the alternating-series
#' representation truncated at \code{K} terms with a signed log-sum-exp.
#' In the cost case, \code{alpha = 1} with \code{y - b > 0} uses the
#' closed-form upper-incomplete-gamma expression; otherwise the
#' one-dimensional integral representation is evaluated by adaptive
#' quadrature (no closed-form series exists in the cost orientation).
#'
#' @param y     Non-negative integer outcome (scalar).
#' @param a     Log-frontier mean x'beta = log(lambda) (scalar).
#' @param b     Rate of the Gamma inefficiency distribution, b > 0 (scalar).
#' @param alpha Shape of the Gamma inefficiency distribution, alpha > 0 (scalar).
#' @param K     Maximum number of series terms (default 100).  Production
#'   orientation only.
#' @param orientation \code{"production"} (default; inefficiency reduces
#'   output, sign \eqn{-}) or \code{"cost"} (inefficiency increases the
#'   conditional rate, sign \eqn{+}).
#'
#' @return Scalar log PMF.  Returns -Inf when the series sum or quadrature
#'   evaluator returns a non-positive value (a sign of numerical issues).
#'
#' @details
#'   Production, alpha = 1:
#'     log P = log(b) - b*a - lgamma(y+1) + lgamma(y+b)
#'             + pgamma(exp(a), shape=y+b, rate=1, log.p=TRUE)
#'
#'   Cost, alpha = 1, y > b:
#'     log P = log(b) + a*b - lgamma(y+1) + lgamma(y-b)
#'             + pgamma(exp(a), shape=y-b, rate=1,
#'                      lower.tail=FALSE, log.p=TRUE)
#'
#'   Cost, general alpha (or alpha = 1 with y <= b):
#'     The transformation \eqn{v = e^{a + u}} maps the marginalisation
#'     integral to
#'     \deqn{\int_{e^{a}}^{\infty} (\log v - a)^{\alpha - 1} v^{y - b - 1} e^{-v}\, dv,}
#'     which has only single-exponential damping and is integrated by
#'     \code{stats::integrate} with a stability shift.
#'
#' @references
#' Centorrino, S. and Perez Urdiales, M. (2026). Count Data Stochastic
#' Frontier Models with Gamma Inefficiency. Working paper.
#'
#' Greene, W. H. (1980). Maximum likelihood estimation of econometric
#' frontier functions. \emph{Journal of Econometrics} \strong{13}, 27--56.
#'
#' Greene, W. H. (1990). A gamma-distributed stochastic frontier model.
#' \emph{Journal of Econometrics} \strong{46}, 141--163.
#'
#' @examples
#' # Production-frontier exponential
#' pmf_poisson_gamma(y = 3, a = log(8), b = 1, alpha = 1)
#'
#' # Production-frontier Gamma with shape = 2
#' pmf_poisson_gamma(y = 3, a = log(8), b = 1, alpha = 2)
#'
#' # Cost-frontier exponential
#' pmf_poisson_gamma(y = 12, a = log(8), b = 3, alpha = 1,
#'                   orientation = "cost")
#'
#' # Cost-frontier Gamma with shape = 2
#' pmf_poisson_gamma(y = 12, a = log(8), b = 3, alpha = 2,
#'                   orientation = "cost")
#'
#' @importFrom stats pgamma dpois qnorm pnorm predict integrate
#' @export
pmf_poisson_gamma <- function(y, a, b, alpha, K = NULL,
                              orientation = c("production", "cost")) {

  orientation <- match.arg(orientation)

  # Auto-select series truncation when K is not supplied. The convergence
  # analysis in section 2 of the paper gives the alpha-aware rule
  #   K >= 3 e^a * max(1, 1/alpha),
  # because the polynomial tail-size suppression (y+b+K)^{-alpha} loses
  # leverage when alpha < 1 while the geometric factor e^a/(j+1) is
  # alpha-free. The same rule is applied in both orientations for API
  # symmetry; in cost orientation K is ignored by the quadrature path.
  if (is.null(K)) {
    alpha_eff <- if (!is.finite(alpha) || alpha <= 0) 1 else alpha
    scale     <- max(1, 1 / alpha_eff)
    K <- min(1000L, max(50L,
              as.integer(ceiling(3 * exp(a) * scale))))
  }

  if (orientation == "production") {
    return(.log_pmf_production(y, a, b, alpha, K = K))
  }
  .log_pmf_cost(y, a, b, alpha)
}

# ----------------------------------------------------------------------------
# Production-frontier PMF.
#
# alpha = 1: closed-form via the lower incomplete gamma function
#     (Proposition 3, corollary in section 2 of the paper).
# alpha != 1: adaptive quadrature on the integral
#     I = int_0^Inf u^{alpha-1} exp(-(y+b) u - exp(a - u)) du,
#   matching the cost-orientation strategy. The alternating series form is
#   retained for completeness as .log_pmf_production_series() but is no
#   longer the default: the leading geometric convergence is alpha-free, but
#   the polynomial tail-size factor (y+b+K)^{-alpha} loses leverage for
#   alpha << 1, so any finite K leaves a non-negligible truncation tail in
#   the sub-exponential regime that the optimiser actually visits during
#   profile-likelihood evaluation.
# ----------------------------------------------------------------------------
.log_pmf_production <- function(y, a, b, alpha, K = 100) {

  # alpha = 1: closed-form via lower incomplete gamma
  if (abs(alpha - 1) < 1e-10) {
    return(
      log(b) - b * a - lgamma(y + 1) + lgamma(y + b) +
        pgamma(exp(a), shape = y + b, rate = 1, log.p = TRUE)
    )
  }

  # alpha != 1: quadrature path (robust at any alpha).
  .log_pmf_production_quad(y, a, b, alpha)
}

.log_pmf_production_quad <- function(y, a, b, alpha) {

  # Production-frontier quadrature on
  #   I(y, a, b, alpha) = int_0^Inf u^(alpha-1) exp(-(y+b) u - exp(a-u)) du.
  # Mirrors the cost-orientation quadrature: finite upper bound, log-space
  # stability shift via a coarse grid, and explicit overflow guard. The
  # integrand has an integrable singularity at u = 0 for alpha < 1, a sharp
  # cutoff at u ~ a from the exp(-exp(a - u)) factor, and exponential decay
  # at rate (y + b) past its mode.

  # Overflow guard matching the cost path
  if (!is.finite(a) || a > 500) return(-Inf)

  log_integrand <- function(u) {
    (alpha - 1) * log(u) - (y + b) * u - exp(a - u)
  }

  # Approximate mode: peak of exp(a - u) cutoff is at u ~ a - log(y + b);
  # peak of the Gamma kernel u^(alpha-1) exp(-(y+b) u) is at
  # (alpha-1)/(y+b) (or 0 for alpha <= 1). The integrand peak lies near
  # the max of the two.
  ybp     <- max(y + b, 1)
  u_mode_a <- a - log(ybp)
  u_mode_g <- max(0, (alpha - 1) / ybp)
  u_mode   <- max(u_mode_a, u_mode_g, 0.01)

  # SD-based upper bound: exponential decay past mode at rate (y + b).
  # The 50-unit floor mirrors the cost path's envelope so a thin peak is
  # not truncated when (y + b) is large.
  u_sd <- sqrt(max(alpha, 1)) / ybp
  u_hi <- max(u_mode + 20 * u_sd, u_mode + 50, 50)

  # Stability shift via coarse log-integrand evaluation on a 200-point grid
  # (matches the cost path; finds log_max robustly even when the analytic
  # mode estimate is off).
  u_grid   <- seq(1e-6, u_hi, length.out = 200L)
  log_vals <- log_integrand(u_grid)
  log_vals[!is.finite(log_vals)] <- -Inf
  log_max  <- max(log_vals)
  if (!is.finite(log_max)) return(-Inf)

  # Adaptive integration on [0, u_hi]. We deliberately do NOT pass
  # upper = Inf: integrate()'s infinite-bound substitution maps Inf to a
  # finite range and can miss the narrow integrand peak when it sits far
  # from 0 (large a). u_hi is set 20 standard deviations past the
  # approximate mode, so the truncated right tail is well below precision.
  I <- tryCatch(
    stats::integrate(function(u) exp(log_integrand(u) - log_max),
                     lower = 0, upper = u_hi,
                     rel.tol = 1e-8, abs.tol = 0,
                     subdivisions = 500L)$value,
    error = function(e) NA_real_
  )

  if (is.na(I) || I <= 0) {
    warning("pmf_poisson_gamma (production): quadrature failed; returning -Inf.")
    return(-Inf)
  }

  log_I  <- log(I) + log_max
  result <- alpha * log(b) + a * y - lgamma(y + 1) - lgamma(alpha) + log_I
  if (!is.finite(result)) return(-Inf)
  result
}

.log_pmf_production_series <- function(y, a, b, alpha, K = 100) {

  # General alpha: alternating series
  # log |term_k| = k*a - lgamma(k+1) - alpha*log(y+b+k)
  kk            <- 0:K
  log_abs_terms <- kk * a - lgamma(kk + 1) - alpha * log(y + b + kk)
  last_log_abs  <- log_abs_terms[K + 1L]

  pos <- (kk %% 2L == 0L)
  neg <- !pos

  lse <- function(lv) {
    m <- max(lv)
    if (!is.finite(m)) return(-Inf)
    m + log(sum(exp(lv - m)))
  }

  lse_pos <- lse(log_abs_terms[pos])
  lse_neg <- lse(log_abs_terms[neg])

  if (!is.finite(lse_pos) || lse_pos <= lse_neg) {
    warning("pmf_poisson_gamma: series sum is non-positive; returning -Inf.")
    return(-Inf)
  }

  log_sum <- lse_pos + log1p(-exp(lse_neg - lse_pos))

  last_abs <- if (is.finite(last_log_abs)) exp(last_log_abs) else 0
  total    <- if (is.finite(log_sum)) exp(log_sum) else 0
  if (is.finite(last_abs) && is.finite(total) && abs(total) > 0 &&
      abs(last_abs) > 1e-6 * abs(total)) {
    warning(sprintf(
      "pmf_poisson_gamma: series may not have converged at K=%d; |last/total|=%.2e",
      K, abs(last_abs / total)
    ))
  }

  result <- alpha * log(b) + y * a - lgamma(y + 1) + log_sum
  if (!is.finite(result)) return(-Inf)
  result
}

# ----------------------------------------------------------------------------
# Cost-frontier PMF.
#
# The marginal PMF (Proposition 3, cost branch) is
#   P(Y = y) = b^alpha * e^{a y} / (y! * Gamma(alpha)) *
#              int_0^Inf u^(alpha - 1) exp((y - b) u - exp(a + u)) du.
#
# Substituting v = exp(a + u) gives equivalently
#   P(Y = y) = b^alpha * e^{a y} * e^{a(b - y)} / (y! * Gamma(alpha)) *
#              int_{exp(a)}^Inf (log v - a)^(alpha - 1) v^(y - b - 1) e^{-v} dv,
# whose damping is single-exponential (e^{-v}) rather than double-exponential,
# and which therefore admits stable adaptive quadrature.
#
# At alpha = 1 with y - b > 0 we use the closed form
#   P(Y = y) = b * e^{a b} / y! * Gamma(y - b, e^a),
# computed via pgamma's regularised upper-tail path.
# ----------------------------------------------------------------------------
.log_pmf_cost <- function(y, a, b, alpha) {

  # alpha = 1, y > b: closed-form upper incomplete gamma
  if (abs(alpha - 1) < 1e-10 && (y - b) > 0) {
    log_upper <- lgamma(y - b) +
      pgamma(exp(a), shape = y - b, rate = 1,
             lower.tail = FALSE, log.p = TRUE)
    return(log(b) + a * b - lgamma(y + 1) + log_upper)
  }

  # General path: quadrature in v = exp(a + u).  Guard against optimisation
  # excursions where a is so large that exp(a) overflows: the integrand is
  # already negligible there, so return -Inf cleanly.
  if (!is.finite(a) || a > 500) return(-Inf)
  ea <- exp(a)
  if (!is.finite(ea)) return(-Inf)

  log_integrand <- function(v) {
    lv_diff <- pmax(log(v) - a, .Machine$double.xmin)
    (alpha - 1) * log(lv_diff) + (y - b - 1) * log(v) - v
  }

  # Approximate joint mode of (log(v) - a)^(alpha-1) v^(y-b-1) e^{-v}. The
  # alpha = 1 mode is at v = max(ea + 1, y - b - 1); for alpha != 1 we apply
  # one Newton step toward the true FOC root only when the Gamma mode is
  # interior to (ea, infty) so the (log v - a)^{alpha-1} factor is smooth
  # there (m9). The 20*v_sd envelope already absorbs the residual error.
  v_mode <- max(ea + 1, y - b - 1)
  if (abs(alpha - 1) > 1e-10 && (y - b - 1) > ea) {
    lvd <- log(v_mode) - a
    if (lvd > 0) {
      num <- (alpha - 1) / lvd                            # ~ f(v_mode)
      den <- (alpha - 1) / (lvd * lvd * v_mode) + 1       # ~ -f'(v_mode)
      if (is.finite(num) && is.finite(den) && den > 0) {
        dv <- num / den
        dv <- max(min(dv, v_mode / 2), -v_mode / 2)
        v_mode <- max(v_mode + dv, ea + 1e-3)
      }
    }
  }
  v_sd <- sqrt(max(y - b, 1) + alpha)
  v_hi <- v_mode + max(20 * v_sd, 50)

  # Stability shift: subtract the largest log-integrand value on a coarse grid
  v_grid   <- seq(ea, v_hi, length.out = 200L)
  log_vals <- log_integrand(v_grid)
  log_vals[!is.finite(log_vals)] <- -Inf
  log_max  <- max(log_vals)
  if (!is.finite(log_max)) return(-Inf)

  # Integrate over [ea, v_hi].  We deliberately do NOT pass upper = Inf:
  # integrate()'s infinite-bound substitution maps Inf to a finite range,
  # which destroys narrow integrand peaks that lie far inside the domain
  # (e.g. y >> b, where the peak is at v ~ y-b-1 and is missed by the
  # substituted nodes).  v_hi is set 20 standard deviations past the
  # approximate mode, so the truncated tail is well below precision.
  I <- tryCatch(
    integrate(function(v) exp(log_integrand(v) - log_max),
              lower = ea, upper = v_hi,
              rel.tol = 1e-8, abs.tol = 0,
              subdivisions = 500L)$value,
    error = function(e) NA_real_
  )

  if (is.na(I) || I <= 0) {
    warning("pmf_poisson_gamma (cost): quadrature failed; returning -Inf.")
    return(-Inf)
  }

  log_I_v <- log(I) + log_max
  log_I_u <- a * (b - y) + log_I_v

  result <- alpha * log(b) + y * a - lgamma(y + 1) - lgamma(alpha) + log_I_u
  if (!is.finite(result)) return(-Inf)
  result
}
