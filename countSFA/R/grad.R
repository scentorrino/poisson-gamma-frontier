#' Analytic gradient of the Poisson-Gamma frontier negative log-likelihood
#'
#' Closed-form score of \code{\link{log_lik_poisson_frontier}} for the
#' \emph{production} orientation, obtained by differentiating the marginal
#' log-PMF under the integral sign.  Writing the marginal as
#' \deqn{\log P_i = \alpha \log b_i + a_i y_i - \log y_i! - \log\Gamma(\alpha)
#'   + \log I_i, \qquad
#'   I_i = \int_0^\infty u^{\alpha-1} e^{-(y_i + b_i) u - e^{a_i - u}}\,du,}
#' and letting \eqn{\langle h\rangle_i = I_i^{-1}\int_0^\infty h(u)\,
#' u^{\alpha-1} e^{-(y_i+b_i)u - e^{a_i-u}}\,du} denote the posterior average
#' under the (normalised) marginalisation kernel, the score blocks are
#' \deqn{\partial_\beta \ell = X'(y - m), \quad m_i = \langle e^{a_i-u}\rangle_i
#'   = \lambda_i\,E[e^{-u}\mid y_i],}
#' \deqn{\partial_{\log b} \ell = \sum_i \big(\alpha - b_i\langle u\rangle_i\big),
#'   \qquad
#'   \partial_{\delta} \ell = -Z'\big(\alpha - b_i\langle u\rangle_i\big),}
#' \deqn{\partial_{\log\alpha} \ell = \alpha \sum_i \big(\log b_i - \psi(\alpha)
#'   + \langle \log u\rangle_i\big),}
#' where \eqn{\psi} is the digamma function.  The three posterior moments
#' \eqn{m_i}, \eqn{\langle u\rangle_i}, \eqn{\langle\log u\rangle_i} are
#' obtained from a single log-max-stabilised quadrature pass per observation,
#' over the same window used by the PMF evaluator in \code{pmf.R}, so the
#' gradient is numerically consistent with the objective.
#'
#' The parameter layout matches \code{\link{log_lik_poisson_frontier}}
#' exactly: \code{c(beta, log_b, [log_alpha], [delta])}, where
#' \code{log_alpha} is present iff \code{alpha} is \code{NULL} (shape
#' estimated) and the \code{delta} block (length \code{ncol(Z)}) is present
#' iff \code{Z} is supplied.  The returned vector is the gradient of the
#' \emph{negative} log-likelihood (i.e. of the quantity \code{optim}
#' minimises), in that same order.
#'
#' Both orientations are supported.  The cost orientation has the identical
#' score structure with the kernel \eqn{u^{\alpha-1} e^{(y-b)u - e^{a+u}}} and
#' the conditional-rate moment \eqn{m_i = \langle e^{a_i+u}\rangle_i =
#' \lambda_i\,E[e^{u}\mid y_i]} (inefficiency raises the rate in the cost
#' frontier); the log-b and log-alpha blocks are unchanged.
#'
#' @inheritParams log_lik_poisson_frontier
#'
#' @return Numeric gradient vector of the negative log-likelihood, matching
#'   the length and order of \code{params}.
#'
#' @seealso \code{\link{log_lik_poisson_frontier}}
#'
#' @importFrom stats integrate
#' @export
grad_loglik_poisson_frontier <- function(params, y, X, alpha = NULL, K = NULL,
                                         orientation = c("production", "cost"),
                                         Z = NULL) {

  orientation <- match.arg(orientation)
  moment_fun  <- if (orientation == "production")
    .grad_moments_production else .grad_moments_cost

  k    <- ncol(X)
  beta <- params[seq_len(k)]
  b    <- exp(params[k + 1L])

  if (is.null(alpha)) {
    alpha_val      <- exp(params[k + 2L])
    estimate_alpha <- TRUE
    next_idx       <- k + 3L
  } else {
    alpha_val      <- alpha
    estimate_alpha <- FALSE
    next_idx       <- k + 2L
  }

  has_Z <- !is.null(Z)
  if (has_Z) {
    if (!is.matrix(Z)) Z <- as.matrix(Z)
    mZ    <- ncol(Z)
    delta <- params[next_idx:(next_idx + mZ - 1L)]
    b_i   <- b * exp(-drop(Z %*% delta))
  } else {
    mZ  <- 0L
    b_i <- rep(b, length(y))
  }

  # Mirror the objective's invalid-rate guard (log_lik returns a flat 1e10
  # there, whose gradient is zero).
  if (any(!is.finite(b_i)) || any(b_i <= 0)) {
    return(numeric(length(params)))
  }

  a <- drop(X %*% beta)
  n <- length(y)

  m_vec     <- numeric(n)
  Eu_vec    <- numeric(n)
  Elogu_vec <- numeric(n)

  for (i in seq_len(n)) {
    mo <- moment_fun(y[i], a[i], b_i[i], alpha_val)
    if (!isTRUE(mo$ok)) {
      # Pathological observation: the objective clamps its log-PMF to a flat
      # region (see log_lik.R), so its true score contribution is ~0. Set the
      # moments to the values that zero out each block, keeping optim stable.
      m_vec[i]     <- y[i]                                  # (y - m) -> 0
      Eu_vec[i]    <- alpha_val / b_i[i]                    # (alpha - b*Eu) -> 0
      Elogu_vec[i] <- digamma(alpha_val) - log(b_i[i])      # log-alpha term -> 0
      next
    }
    m_vec[i]     <- mo$m
    Eu_vec[i]    <- mo$Eu
    Elogu_vec[i] <- mo$Elogu
  }

  # ---- Score blocks (d loglik / d theta) -----------------------------------
  s_beta <- drop(crossprod(X, y - m_vec))            # length k
  sb_i   <- alpha_val - b_i * Eu_vec                 # per-obs log-b / delta term
  s_logb <- sum(sb_i)

  grad_ll <- c(s_beta, s_logb)

  if (estimate_alpha) {
    s_logalpha <- alpha_val *
      sum(log(b_i) - digamma(alpha_val) + Elogu_vec)
    grad_ll <- c(grad_ll, s_logalpha)
  }

  if (has_Z) {
    s_delta <- -drop(crossprod(Z, sb_i))             # length mZ
    grad_ll <- c(grad_ll, s_delta)
  }

  # optim minimises the NEGATIVE log-likelihood.
  -grad_ll
}


# ----------------------------------------------------------------------------
# Production posterior moments under the marginalisation kernel
#   g(u) = u^(alpha-1) exp(-(y+b) u - exp(a-u)),  u > 0.
#
# Returns, on success, the three moments needed for the score:
#   Eu    = <u>            (drives the log-b and delta blocks)
#   Elogu = <log u>        (drives the log-alpha block)
#   m     = <e^{a-u}>      (drives the beta block; equals e^a * <e^{-u}>)
#
# We integrate in t = log u.  The change of variable u = e^t maps the
# marginalisation kernel u^{alpha-1} e^{-(y+b)u - e^{a-u}} du to the SMOOTH,
# BOUNDED density
#   h(t) = exp( alpha t - (y+b) e^t - e^{a - e^t} ),   t in (-Inf, Inf),
# which decays super-exponentially at both ends and has NO u^{alpha-1}
# singularity at u = 0.  This is essential for the <log u> moment: in t-space
# it is simply <t>, with no log singularity to defeat stats::integrate
# (the u-space integrand log(u) u^{alpha-1} is integrable but flagged
# "probably divergent" by the adaptive routine for alpha < 1, small rate).
# The log-max shift cancels in every ratio H_c / H_0.
# ----------------------------------------------------------------------------
.grad_moments_production <- function(yi, ai, bi, alpha) {

  # Overflow guard matching the PMF path.
  if (!is.finite(ai) || ai > 500) return(list(ok = FALSE))

  log_h <- function(t) {
    et <- exp(t)
    alpha * t - (yi + bi) * et - exp(ai - et)
  }

  # t-window.  The right edge follows the u-space support [~0, u_hi] used by
  # the PMF evaluator (the right tail decays double-exponentially via
  # e^{-(y+b)e^t}, so this is ample).  The LEFT edge needs care: as t -> -Inf
  # the kernel decays only like e^{alpha t}, so for small alpha the <log u> =
  # <t> moment has a slowly-vanishing left tail.  Cutting it too early biases
  # <t> by O(|t_a| e^{alpha (t_a - t*)}).  We therefore place t_lo about
  # 70/alpha log-units of decay below the mode and then trim to the region
  # within 65 log-units of the peak, so the discarded tail (weighted by |t|)
  # is below 1e-20.
  ybp    <- max(yi + bi, 1)
  u_mode <- max(ai - log(ybp), 0.01)
  u_hi   <- max(u_mode + 20 * sqrt(max(alpha, 1)) / ybp, u_mode + 50, 50)
  t_hi   <- log(u_hi)
  t_lo   <- log(u_mode) - 70 / max(alpha, 0.1) - 10

  t_grid   <- seq(t_lo, t_hi, length.out = 1200L)
  log_vals <- log_h(t_grid)
  log_vals[!is.finite(log_vals)] <- -Inf
  log_max  <- max(log_vals)
  if (!is.finite(log_max)) return(list(ok = FALSE))

  keep <- which(log_vals > log_max - 65)
  t_a  <- t_grid[max(1L, min(keep) - 1L)]
  t_b  <- t_grid[min(1200L, max(keep) + 1L)]

  base <- function(t) exp(log_h(t) - log_max)         # smooth, bounded bump

  intg <- function(f) tryCatch(
    stats::integrate(f, lower = t_a, upper = t_b,
                     rel.tol = 1e-9, abs.tol = 0,
                     subdivisions = 500L)$value,
    error = function(e) NA_real_
  )

  H0 <- intg(function(t) base(t))
  if (is.na(H0) || H0 <= 0) return(list(ok = FALSE))

  Ht <- intg(function(t) t * base(t))                 # <log u> = <t>
  Hu <- intg(function(t) exp(t) * base(t))            # <u>     = <e^t>
  He <- intg(function(t) exp(-exp(t)) * base(t))      # <e^{-u}>= <e^{-e^t}>

  if (anyNA(c(Ht, Hu, He))) return(list(ok = FALSE))

  list(
    ok    = TRUE,
    Eu    = Hu / H0,
    Elogu = Ht / H0,
    m     = exp(ai) * (He / H0)                        # <e^{a-u}> = e^a <e^{-u}>
  )
}


# ----------------------------------------------------------------------------
# Cost posterior moments under the marginalisation kernel
#   g(u) = u^(alpha-1) exp((y-b) u - exp(a+u)),  u > 0.
#
# Returns the three score moments:
#   Eu    = <u>            (log-b and delta blocks)
#   Elogu = <log u>        (log-alpha block)
#   m     = <e^{a+u}>      (beta block; the posterior mean conditional rate
#                           E[mu|y] in the cost frontier, where mu = e^{a+u})
#
# As in the production case we integrate in t = log u, mapping the kernel to
#   h(t) = exp( alpha t + (y-b) e^t - e^{a + e^t} ),   t in (-Inf, Inf),
# smooth and singularity-free.  The cost kernel damps DOUBLE-exponentially on
# the right (e^{-e^{a+u}}), so its support is a thin sliver just past the mode
# u* ~ log(y-b) - a; the left tail again decays only like e^{alpha t}.  The
# beta moment m = <e^{a+u}> is computed with its OWN log-max shift Lm_max
# (separate from the kernel's log_max): e^{a+u} is O(y-b) at the kernel mode
# but e^a * e^{e^t} overflows if naively factored, so we keep a+e^t inside the
# exponent and form m = exp(Lm_max - log_max) * Hm / H0.
# ----------------------------------------------------------------------------
.grad_moments_cost <- function(yi, ai, bi, alpha) {

  if (!is.finite(ai) || ai > 500) return(list(ok = FALSE))

  log_h <- function(t) {
    et  <- exp(t)
    val <- alpha * t + (yi - bi) * et - exp(ai + et)
    val[!is.finite(val)] <- -Inf                      # overflow in e^{a+e^t}
    val
  }

  # Mode of u: for y > b the e^{(y-b)u} growth balances the e^{-e^{a+u}} cutoff
  # at e^{a+u} ~ y-b, i.e. u* ~ log(y-b) - a; otherwise mass sits near 0.
  ybd    <- yi - bi
  u_mode <- if (ybd > 0) max(log(ybd) - ai, 0.01) else 0.01
  t_mode <- log(u_mode)
  t_lo   <- t_mode - 70 / max(alpha, 0.1) - 10
  # Right edge: a few units of u past the mode (double-exp cutoff is sharp),
  # capped so a + e^t stays well below the overflow threshold (~709).
  u_hi   <- min(u_mode + 25, 700 - ai)
  t_hi   <- log(max(u_hi, u_mode + 1))

  t_grid   <- seq(t_lo, t_hi, length.out = 1200L)
  log_vals <- log_h(t_grid)
  log_vals[!is.finite(log_vals)] <- -Inf
  log_max  <- max(log_vals)
  if (!is.finite(log_max)) return(list(ok = FALSE))

  keep <- which(log_vals > log_max - 65)
  if (!length(keep)) return(list(ok = FALSE))
  t_a  <- t_grid[max(1L, min(keep) - 1L)]
  t_b  <- t_grid[min(1200L, max(keep) + 1L)]

  base <- function(t) exp(log_h(t) - log_max)         # smooth, bounded bump

  # Separate stabilisation for the m = <e^{a+u}> integrand, whose log-values
  # are L_m(t) = (a + e^t) + log_h(t).
  log_m_vals <- (ai + exp(t_grid)) + log_vals
  log_m_vals[!is.finite(log_m_vals)] <- -Inf
  Lm_max <- max(log_m_vals)

  intg <- function(f, lo, hi) tryCatch(
    stats::integrate(f, lower = lo, upper = hi,
                     rel.tol = 1e-9, abs.tol = 0,
                     subdivisions = 500L)$value,
    error = function(e) NA_real_
  )

  H0 <- intg(function(t) base(t), t_a, t_b)
  if (is.na(H0) || H0 <= 0) return(list(ok = FALSE))

  Ht <- intg(function(t) t * base(t), t_a, t_b)        # <log u> = <t>
  Hu <- intg(function(t) exp(t) * base(t), t_a, t_b)   # <u>     = <e^t>
  Hm <- if (is.finite(Lm_max))
    intg(function(t) exp((ai + exp(t)) + log_h(t) - Lm_max), t_a, t_b)
  else NA_real_

  if (anyNA(c(Ht, Hu, Hm))) return(list(ok = FALSE))

  list(
    ok    = TRUE,
    Eu    = Hu / H0,
    Elogu = Ht / H0,
    m     = exp(Lm_max - log_max) * (Hm / H0)          # <e^{a+u}>
  )
}
