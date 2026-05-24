#' Negative log-likelihood for the Poisson-Gamma frontier (for use with optim)
#'
#' @param params Numeric vector.  The block layout is
#'   \code{c(beta, log_b, [log_alpha], [delta])}, where each optional block
#'   is included only when applicable:
#'   \itemize{
#'     \item \code{log_alpha} is present when \code{alpha} is \code{NULL}
#'       (Gamma fit with shape estimated).
#'     \item \code{delta} (length \code{ncol(Z)}) is present when \code{Z}
#'       is non-\code{NULL} (scaling model for inefficiency determinants).
#'   }
#'   Parameters \code{b}, \code{alpha} enter on the log scale so that
#'   unconstrained optimisation respects positivity.
#' @param y     Integer vector of outcomes.
#' @param X     Model matrix (n x k), including intercept if desired.
#' @param alpha Fixed value for the Gamma shape parameter, or \code{NULL}
#'   to estimate it freely.
#' @param K     Series truncation (passed to \code{pmf_poisson_gamma}).
#' @param orientation \code{"production"} (default) or \code{"cost"}.
#' @param Z     Optional numeric matrix (n x m) of inefficiency determinants
#'   for the scaling model \eqn{b_i = b \exp(-z_i' \delta)}.  If \code{NULL}
#'   (default) the homogeneous model is used: \eqn{b_i \equiv b}.  When
#'   supplied, an extra \code{delta} block of length \code{ncol(Z)} must
#'   follow \code{log_b} (or \code{log_alpha} when present) in \code{params}.
#'
#' @return Scalar negative log-likelihood (to minimise with \code{optim}).
#'
#' @examples
#' set.seed(1L)
#' n <- 50L
#' X <- cbind(1, rnorm(n))
#' y <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5))))
#' # Homogeneous exponential frontier:
#' log_lik_poisson_frontier(c(1, 0.5, 0), y, X, alpha = 1)
#'
#' # Scaling-model exponential frontier with one determinant:
#' Z <- cbind(rnorm(n))
#' log_lik_poisson_frontier(c(1, 0.5, 0, 0.1), y, X, alpha = 1, Z = Z)
#'
#' @export
log_lik_poisson_frontier <- function(params, y, X, alpha = NULL, K = NULL,
                                     orientation = c("production", "cost"),
                                     Z = NULL) {

  orientation <- match.arg(orientation)
  k    <- ncol(X)
  beta <- params[seq_len(k)]
  b    <- exp(params[k + 1L])

  if (is.null(alpha)) {
    alpha_val <- exp(params[k + 2L])
    next_idx  <- k + 3L
  } else {
    alpha_val <- alpha
    next_idx  <- k + 2L
  }

  # Scaling block: b_i = b * exp(-z_i' delta).
  if (!is.null(Z)) {
    if (!is.matrix(Z)) Z <- as.matrix(Z)
    m     <- ncol(Z)
    delta <- params[next_idx:(next_idx + m - 1L)]
    b_i   <- b * exp(-drop(Z %*% delta))
    if (any(!is.finite(b_i)) || any(b_i <= 0)) return(1e10)
  } else {
    b_i <- rep(b, length(y))
  }

  a  <- drop(X %*% beta)
  n  <- length(y)

  # Auto-select series truncation when not supplied. The convergence
  # analysis in section 2 of the paper shows that demanding |t_K| < eps
  # for the alternating series of @eq-pmf-gamma requires
  #   K >= 3 * exp(a) * max(1, 1/alpha),
  # because the polynomial tail-size suppression (y+b+K)^{-alpha} loses
  # its leverage in the sub-exponential regime alpha < 1, while the
  # geometric e^a/(j+1) factor that drives convergence is alpha-free.
  # The same rule is applied in both orientations for API symmetry; in
  # cost orientation K is ignored by the quadrature path.
  if (is.null(K)) {
    alpha_eff <- if (is.null(alpha_val) || !is.finite(alpha_val) ||
                     alpha_val <= 0) 1 else alpha_val
    scale     <- max(1, 1 / alpha_eff)
    K <- min(1000L, max(50L,
              as.integer(ceiling(3 * exp(max(a)) * scale))))
  }

  ll <- vapply(
    seq_len(n),
    function(i) pmf_poisson_gamma(y[i], a[i], b_i[i], alpha_val, K = K,
                                  orientation = orientation),
    numeric(1L)
  )

  # Per-observation clipping: clamp the log-PMF to [-1e6, 0] before
  # summing. log P(Y=y) <= 0 holds for any valid probability mass, so
  # any positive value is series-truncation noise (clamped to 0) and any
  # -Inf is a singular series whose partial sum went non-positive
  # (clamped to -1e6). This presents L-BFGS-B with a smooth bounded
  # surface instead of a 1e10 cliff: optim can navigate out of regions
  # where one or two observations are numerically pathological without
  # the whole likelihood collapsing. A genuinely bad parameter
  # vector still produces a very negative log-likelihood because many
  # observations get clamped to -1e6 each, so the optimiser is pushed
  # away from it.
  ll <- pmin(pmax(ll, -1e6), 0)
  -sum(ll)
}
