#' Log PMF of the Poisson / half-normal stochastic frontier (simulated)
#'
#' Approximates \eqn{\log P(Y = y)} for a Poisson stochastic frontier with
#' half-normal inefficiency
#' \deqn{Y \mid u \sim \mathrm{Poisson}(\exp(a \pm u)), \qquad u \sim |N(0, \sigma^2)|.}
#' No closed form is available; the marginal is integrated out via simulated
#' likelihood with deterministic Halton draws (Fé and Hofler, 2013).
#'
#' @param y           Non-negative integer outcome (scalar).
#' @param a           Log-frontier mean \eqn{x'\beta} (scalar).
#' @param sigma       Standard deviation of the underlying normal,
#'   \eqn{\sigma > 0}.
#' @param R           Number of Halton draws (default 200).
#' @param orientation \code{"production"} (default; inefficiency reduces
#'   output, sign \eqn{-}) or \code{"cost"} (inefficiency increases cost,
#'   sign \eqn{+}).
#'
#' @return Scalar log PMF, computed via log-sum-exp for numerical stability.
#'
#' @references
#' Fé, E. and Hofler, R. A. (2013). Count data stochastic frontier
#' models, with an application to the patents-R&D relationship.
#' \emph{Journal of Productivity Analysis} \strong{39}, 271--284.
#'
#' Halton, J. H. (1960). On the efficiency of certain quasi-random
#' sequences of points in evaluating multi-dimensional integrals.
#' \emph{Numerische Mathematik} \strong{2}, 84--90.
#'
#' @examples
#' pmf_poisson_halfnormal(y = 3, a = log(8), sigma = 0.7, R = 200)
#'
#' @importFrom stats glm fitted var coef optim
#' @export
pmf_poisson_halfnormal <- function(y, a, sigma, R = 200,
                                   orientation = c("production", "cost")) {

  orientation <- match.arg(orientation)
  sgn <- if (orientation == "production") -1 else 1

  # Deterministic Halton -> standard normal -> half-normal magnitudes.
  # Shift away from {0,1} to avoid Inf at qnorm endpoints.
  h <- (halton_seq(R) + 1e-6) / (1 + 2e-6)
  z <- qnorm(h)
  u <- abs(sigma * z)

  log_lambda <- a + sgn * u
  # log Poisson PMF at each draw: y*log_lambda - lambda - lgamma(y+1)
  log_p_r <- y * log_lambda - exp(log_lambda) - lgamma(y + 1)

  # log(mean(p_r)) = logsumexp(log_p_r) - log(R)
  m <- max(log_p_r)
  if (!is.finite(m)) return(-Inf)
  m + log(sum(exp(log_p_r - m))) - log(R)
}


#' Negative log-likelihood for the Poisson / half-normal frontier
#'
#' Wrapper over \code{\link{pmf_poisson_halfnormal}} suitable for
#' \code{\link[stats]{optim}}.
#'
#' @param params      Numeric vector \code{c(beta, log_sigma)}.  The
#'   half-normal scale \eqn{\sigma} enters in log-scale so unconstrained
#'   optimisation respects positivity.
#' @param y           Integer vector of outcomes.
#' @param X           Model matrix (n x k), including intercept if desired.
#' @param R           Number of Halton draws.
#' @param orientation \code{"production"} or \code{"cost"}.
#'
#' @return Scalar negative log-likelihood (to minimise with \code{optim}).
#'
#' @examples
#' set.seed(1L)
#' n <- 50L
#' X <- cbind(1, rnorm(n))
#' y <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5))))
#' # Evaluate at a candidate (beta1=1, beta2=0.5, log_sigma=-1):
#' log_lik_poisson_halfnormal(c(1, 0.5, -1), y, X, R = 50L)
#'
#' @export
log_lik_poisson_halfnormal <- function(params, y, X, R = 200,
                                       orientation = "production") {

  k     <- ncol(X)
  beta  <- params[seq_len(k)]
  sigma <- exp(params[k + 1L])

  a  <- drop(X %*% beta)
  n  <- length(y)

  ll <- vapply(
    seq_len(n),
    function(i) pmf_poisson_halfnormal(y[i], a[i], sigma, R = R,
                                       orientation = orientation),
    numeric(1L)
  )

  if (any(!is.finite(ll))) return(.Machine$double.xmax)

  -sum(ll)
}


#' Fit the Poisson / half-normal stochastic frontier by simulated MLE
#'
#' Maximum simulated likelihood estimation of the Poisson stochastic frontier
#' model with half-normal inefficiency, following Fé and Hofler (2013).
#' Halton draws are deterministic given \code{R}, so estimates are
#' reproducible without manual seed handling.
#'
#' @param y           Integer vector of count outcomes.
#' @param X           Model matrix (n x k).  Include an intercept column if
#'   desired.
#' @param R           Number of Halton draws used to evaluate the simulated
#'   likelihood (default 200).
#' @param orientation \code{"production"} (default) or \code{"cost"}.
#' @param starts      Optional numeric vector of starting values
#'   \code{c(beta, log_sigma)}.  If \code{NULL}, derived from a Poisson GLM
#'   warm start plus an overdispersion-based moment match.
#'
#' @return An S3 object of class \code{c("poisson_halfnormal",
#'   "poisson_frontier")} with components matching
#'   \code{\link{fit_poisson_frontier}} where applicable, plus \code{sigma},
#'   \code{se_sigma}, \code{R}, and \code{orientation}.  The legacy fields
#'   \code{b}, \code{alpha}, \code{se_b}, \code{se_alpha} are filled with
#'   \code{NA} so utilities such as \code{\link{compare_models}} continue to
#'   work transparently.
#'
#' @references
#' Fé, E. and Hofler, R. A. (2013). Count data stochastic frontier
#' models, with an application to the patents-R&D relationship.
#' \emph{Journal of Productivity Analysis} \strong{39}, 271--284.
#'
#' Fé, E. and Hofler, R. A. (2020). sfcount: Command for count-data
#' stochastic frontiers and underreported and overreported counts.
#' \emph{Stata Journal} \strong{20}, 532--547.
#'
#' Centorrino, S. and Perez Urdiales, M. (2026). Count Data Stochastic
#' Frontier Models with Gamma Inefficiency. Working paper.
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n  <- 200L
#' X  <- cbind(1, rnorm(n))
#' u  <- abs(rnorm(n, sd = 0.5))
#' y  <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' fit <- fit_poisson_halfnormal(y, X, R = 100L)
#' c(sigma = fit$sigma, loglik = fit$loglik)
#' }
#'
#' @export
fit_poisson_halfnormal <- function(y, X, R = 200,
                                   orientation = "production",
                                   starts = NULL) {

  orientation <- match.arg(orientation, c("production", "cost"))
  k <- ncol(X)
  n <- length(y)

  # ---- Starting values from Poisson GLM + overdispersion moment match -----
  glm0   <- glm(y ~ X - 1, family = poisson())
  beta0  <- unname(coef(glm0))
  mu_hat <- fitted(glm0)
  excess <- pmax(var(y) - mean(y), 1e-2)
  b0     <- pmax(mean(mu_hat)^2 / excess, 0.5)
  # For half-normal: E[u^2] = sigma^2, so use the gamma heuristic to seed:
  # sigma_0 ~ sqrt(2 log(b0)) is rough; clamp to a sensible window.
  sigma0 <- pmin(pmax(sqrt(2 * log(b0 + 1)), 0.1), 2.0)

  par0 <- if (!is.null(starts)) starts else c(beta0, log(sigma0))

  obj <- function(p) log_lik_poisson_halfnormal(
    p, y, X, R = R, orientation = orientation
  )

  # L-BFGS-B with a bound on log_sigma keeps the optimiser away from the
  # degenerate sigma -> 0 (Poisson) and sigma -> Inf (improper) limits.
  lower_bd <- c(rep(-Inf, k), -4)
  upper_bd <- c(rep( Inf, k),  4)

  opt <- optim(par0, obj, method = "L-BFGS-B",
               lower = lower_bd, upper = upper_bd,
               hessian = TRUE,
               control = list(maxit = 2000, factr = 1e7))

  # Fallback to BFGS without bounds if L-BFGS-B failed to converge.
  if (opt$convergence != 0L) {
    opt_try <- tryCatch(
      optim(par0, obj, method = "BFGS", hessian = TRUE,
            control = list(maxit = 2000, reltol = 1e-9)),
      error = function(e) list(value = Inf, convergence = 99L)
    )
    if (is.finite(opt_try$value) && opt_try$value < opt$value) opt <- opt_try
  }

  if (opt$convergence != 0L) {
    warning(sprintf(
      "fit_poisson_halfnormal: optim did not converge (code %d). Estimates may be unreliable.",
      opt$convergence
    ))
  }

  # ---- Extract parameters --------------------------------------------------
  beta_hat  <- opt$par[seq_len(k)]
  sigma_hat <- exp(opt$par[k + 1L])

  # ---- Variance-covariance (Hessian inverse) -------------------------------
  vcov_raw <- tryCatch(
    solve(opt$hessian),
    error = function(e) {
      warning("fit_poisson_halfnormal: Hessian is singular; vcov set to NA.")
      matrix(NA_real_, nrow(opt$hessian), ncol(opt$hessian))
    }
  )

  npar    <- length(opt$par)
  se_raw  <- sqrt(pmax(diag(vcov_raw), 0))
  se_beta <- se_raw[seq_len(k)]
  # Delta method: SE(sigma) = sigma * SE(log_sigma)
  se_sigma <- sigma_hat * se_raw[k + 1L]

  xnames <- colnames(X)
  if (is.null(xnames)) xnames <- paste0("x", seq_len(k))
  names(beta_hat) <- xnames
  names(se_beta)  <- xnames

  ll  <- -opt$value
  aic <- -2 * ll + 2 * npar
  bic <- -2 * ll + log(n) * npar

  structure(
    list(
      coefficients = beta_hat,
      se           = se_beta,
      sigma        = sigma_hat,
      se_sigma     = se_sigma,
      # Legacy fields so compare_models / summary do not error:
      b            = NA_real_,
      se_b         = NA_real_,
      alpha        = NA_real_,
      se_alpha     = NA_real_,
      loglik       = ll,
      AIC          = aic,
      BIC          = bic,
      vcov         = vcov_raw,
      convergence  = opt$convergence,
      n            = n,
      k            = k,
      dist         = "halfnormal",
      npar         = npar,
      R            = R,
      orientation  = orientation
    ),
    class = c("poisson_halfnormal", "poisson_frontier")
  )
}


#' Posterior efficiency scores for the Poisson / half-normal frontier
#'
#' Companion to \code{\link{efficiency_scores}} for fits returned by
#' \code{\link{fit_poisson_halfnormal}}.  Computes simulated posterior moments
#' \eqn{E[e^{-u_i}|y_i]} and \eqn{E[e^{-2u_i}|y_i]} via Halton draws of the
#' half-normal prior, weighted by the Poisson likelihood (importance
#' sampling).
#'
#' @param fit A \code{"poisson_halfnormal"} object.
#' @param y   Integer vector of outcomes.
#' @param X   Model matrix used at fit time.
#' @param R   Number of Halton draws (default 500).
#'
#' @return A \code{data.frame} with columns \code{i}, \code{eff_score},
#'   \code{eff_lower}, \code{eff_upper} (95\% interval, clipped to [0, 1]).
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n <- 100L
#' X <- cbind(1, rnorm(n))
#' u <- abs(rnorm(n, sd = 0.5))
#' y <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' fit <- fit_poisson_halfnormal(y, X, R = 100L)
#' head(efficiency_scores_halfnormal(fit, y, X, R = 200L))
#' }
#'
#' @export
efficiency_scores_halfnormal <- function(fit, y, X, R = 500) {

  stopifnot(inherits(fit, "poisson_halfnormal"))

  sigma <- fit$sigma
  beta  <- fit$coefficients
  a     <- drop(X %*% beta)
  n     <- length(y)
  sgn   <- if (fit$orientation == "production") -1 else 1

  # Pre-compute one set of half-normal draws (shared across observations).
  h <- (halton_seq(R) + 1e-6) / (1 + 2e-6)
  draws <- abs(sigma * qnorm(h))

  eff_score <- numeric(n)
  eff_lower <- numeric(n)
  eff_upper <- numeric(n)

  for (i in seq_len(n)) {
    yi <- y[i]
    ai <- a[i]
    log_lam <- ai + sgn * draws
    log_w   <- yi * log_lam - exp(log_lam) - lgamma(yi + 1)
    m       <- max(log_w)
    w       <- exp(log_w - m)
    sw      <- sum(w)
    if (!is.finite(sw) || sw <= 0) {
      e1 <- NA_real_; e2 <- NA_real_
    } else {
      e1 <- sum(w * exp(-draws))     / sw
      e2 <- sum(w * exp(-2 * draws)) / sw
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
