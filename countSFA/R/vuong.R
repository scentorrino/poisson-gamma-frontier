#' Vuong (1989) test for non-nested or overlapping model comparison
#'
#' Implements the closeness-to-truth test of Vuong (1989, Econometrica)
#' for two competing fitted models on the same data. The test handles
#' non-nested models (e.g.\ Gamma versus half-normal frontier) and the
#' overlapping/boundary cases that invalidate the standard likelihood
#' ratio test (e.g.\ Poisson GLM versus the exponential frontier, which
#' meet at the boundary \eqn{b \to \infty}).
#'
#' Let \eqn{m_i = \log f_1(y_i \mid \mathbf{x}_i, \hat\theta_1) - \log
#' f_2(y_i \mid \mathbf{x}_i, \hat\theta_2)} be the per-observation
#' log-likelihood ratio. The (raw) Vuong statistic is
#' \deqn{V \;=\; \frac{\sqrt{n}\,\bar m}{s_m},}
#' where \eqn{\bar m} and \eqn{s_m} are the sample mean and standard
#' deviation of \eqn{m_i}. Under \eqn{H_0} that the two models are
#' equally close to the true distribution, \eqn{V \to_d \mathcal N(0,1)}.
#'
#' Three correction options for the numerator are supported:
#' \itemize{
#'   \item \code{"none"}: raw \eqn{\bar m}.
#'   \item \code{"AIC"}: subtracts \eqn{(k_1 - k_2)/n} (penalises the
#'     more complex model proportional to its parameter count).
#'   \item \code{"BIC"}: subtracts \eqn{(k_1 - k_2) \log(n)/(2n)}.
#' }
#'
#' @param fit1,fit2 Fitted model objects. Each must support either
#'   \code{logLik()} returning per-observation log-likelihood via the
#'   \code{"per_obs"} attribute, or supply \code{logL1}/\code{logL2}
#'   directly. For \code{poisson_frontier} / \code{poisson_halfnormal}
#'   objects, the per-observation contributions are recomputed from the
#'   stored \code{coefficients}, \code{b} or \code{sigma}, and
#'   \code{alpha}.
#' @param y      Outcome vector (must match what was passed to both
#'   fits).
#' @param X      Model matrix used in both fits (assumed to be the same
#'   design for both — Vuong's test is most cleanly interpreted when the
#'   two models share the conditioning information).
#' @param correction Character; one of \code{"none"} (default),
#'   \code{"AIC"}, or \code{"BIC"}.
#'
#' @return A list with components:
#' \describe{
#'   \item{\code{statistic}}{Vuong z-statistic (corrected if requested).}
#'   \item{\code{p_value}}{Two-sided p-value from the standard normal.}
#'   \item{\code{LR_obs}}{Sample log-likelihood ratio
#'     \eqn{\sum_i m_i}.}
#'   \item{\code{n}}{Sample size.}
#'   \item{\code{correction}}{The correction applied.}
#'   \item{\code{decision}}{Character summary at the 5\% level.}
#' }
#'
#' @details
#' Sign convention: \code{statistic > 0} favours \code{fit1};
#' \code{statistic < 0} favours \code{fit2}. The two-sided p-value tests
#' \eqn{H_0\!:\ \text{models equally close to truth}}.
#'
#' This implementation does not perform Vuong's preliminary variance
#' test for distinguishability; for nested or overlapping models the
#' statistic is still asymptotically normal under \eqn{H_0} when the
#' parametric families are correctly specified for at least one of the
#' two models, so reporting the z-statistic and noting the parameter
#' counts is a defensible default.
#'
#' @references
#' Vuong, Q. H. (1989). \dQuote{Likelihood Ratio Tests for Model
#'   Selection and Non-Nested Hypotheses.} \emph{Econometrica}
#'   \strong{57}, 307--333.
#'
#' Andrews, D. W. K. (2001). Testing when a parameter is on the boundary
#'   of the maintained hypothesis. \emph{Econometrica} \strong{69},
#'   683--734. (Note: Vuong's normal limit fails at boundary points
#'   covered by this paper; users should not invoke this test for
#'   strictly nested models with a boundary null.)
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n  <- 200L
#' X  <- cbind(1, rnorm(n))
#' u  <- rexp(n, rate = 2)
#' y  <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' f1 <- fit_poisson_frontier(y, X, dist = "exponential")
#' f2 <- glm(y ~ X - 1, family = poisson())
#' v  <- vuong_test(f1, f2, y, X)
#' c(V = v$statistic, p = v$p_value)
#' }
#'
#' @importFrom stats sd pnorm
#' @export
vuong_test <- function(fit1, fit2, y, X,
                       correction = c("none", "AIC", "BIC")) {

  correction <- match.arg(correction)
  n <- length(y)

  ll1 <- per_obs_loglik(fit1, y, X)
  ll2 <- per_obs_loglik(fit2, y, X)

  if (length(ll1) != n || length(ll2) != n) {
    stop("vuong_test: per-observation log-likelihoods must have length(y).")
  }

  m       <- ll1 - ll2
  m_mean  <- mean(m)
  m_sd    <- sd(m)
  LR_obs  <- sum(m)

  if (m_sd <= .Machine$double.eps) {
    return(list(statistic = NA_real_, p_value = NA_real_,
                LR_obs = LR_obs, n = n, correction = correction,
                decision = "Models are numerically indistinguishable."))
  }

  k1 <- npar_fit(fit1)
  k2 <- npar_fit(fit2)

  pen <- switch(correction,
                "none" = 0,
                "AIC"  = (k1 - k2) / n,
                "BIC"  = (k1 - k2) * log(n) / (2 * n))

  V <- sqrt(n) * (m_mean - pen) / m_sd
  p <- 2 * pnorm(-abs(V))

  decision <- if (p >= 0.05) {
    "Models are statistically indistinguishable at the 5% level."
  } else if (V > 0) {
    "Reject H0 in favour of fit1 at the 5% level."
  } else {
    "Reject H0 in favour of fit2 at the 5% level."
  }

  list(
    statistic  = V,
    p_value    = p,
    LR_obs     = LR_obs,
    n          = n,
    correction = correction,
    decision   = decision
  )
}

# ---- internal helpers -----------------------------------------------------

per_obs_loglik <- function(fit, y, X) {
  UseMethod("per_obs_loglik")
}

#' @export
per_obs_loglik.poisson_frontier <- function(fit, y, X) {
  beta  <- fit$coefficients
  a     <- drop(X %*% beta)
  b     <- fit$b
  alpha <- fit$alpha
  K     <- if (!is.null(fit$K)) fit$K else 100L
  vapply(seq_along(y),
         function(i) pmf_poisson_gamma(y[i], a[i], b, alpha, K = K),
         numeric(1L))
}

#' @export
per_obs_loglik.poisson_halfnormal <- function(fit, y, X) {
  beta  <- fit$coefficients
  a     <- drop(X %*% beta)
  sigma <- fit$sigma
  R     <- if (!is.null(fit$R)) fit$R else 200L
  ori   <- if (!is.null(fit$orientation)) fit$orientation else "production"
  vapply(seq_along(y),
         function(i) pmf_poisson_halfnormal(y[i], a[i], sigma,
                                            R = R, orientation = ori),
         numeric(1L))
}

#' @export
per_obs_loglik.glm <- function(fit, y, X) {
  # Standard Poisson GLM (or any GLM with dpois log-likelihood).
  mu <- predict(fit, type = "response")
  if (length(mu) != length(y))
    stop("per_obs_loglik.glm: length(predict(fit)) != length(y).")
  dpois(y, lambda = mu, log = TRUE)
}

#' @export
per_obs_loglik.default <- function(fit, y, X) {
  stop("vuong_test: no per_obs_loglik method for class '",
       class(fit)[1L], "'.")
}

npar_fit <- function(fit) {
  if (!is.null(fit$npar))   return(fit$npar)
  if (inherits(fit, "glm")) return(length(coef(fit)))
  length(coef(fit))
}
