#' Compare a list of fitted Poisson frontier models
#'
#' @param fit_list A named list of \code{"poisson_frontier"} objects.
#' @param names    Optional character vector of model labels; defaults to
#'   \code{names(fit_list)}.
#'
#' @return A \code{data.frame} (kable-ready) with columns:
#' \describe{
#'   \item{\code{Model}}{Model label.}
#'   \item{\code{Distribution}}{Inefficiency distribution string.}
#'   \item{\code{alpha}}{Estimated or fixed shape parameter.}
#'   \item{\code{b}}{Estimated rate parameter.}
#'   \item{\code{Npar}}{Number of free parameters.}
#'   \item{\code{LogLik}}{Maximised log-likelihood.}
#'   \item{\code{AIC}}{Akaike information criterion.}
#'   \item{\code{BIC}}{Bayesian information criterion.}
#'   \item{\code{Converged}}{Logical; TRUE if optim returned code 0.}
#' }
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n  <- 200L
#' X  <- cbind(1, rnorm(n))
#' u  <- rexp(n, rate = 2)
#' y  <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' f1 <- fit_poisson_frontier(y, X, dist = "exponential")
#' compare_models(list(Exponential = f1))
#' }
#'
#' @export
compare_models <- function(fit_list, names = NULL) {

  if (!is.null(names)) {
    stopifnot(length(names) == length(fit_list))
  } else {
    names <- names(fit_list)
    if (is.null(names)) names <- paste0("Model", seq_along(fit_list))
  }

  rows <- lapply(seq_along(fit_list), function(j) {
    fit <- fit_list[[j]]
    stopifnot(inherits(fit, "poisson_frontier"))
    data.frame(
      Model        = names[j],
      Distribution = fit$dist,
      alpha        = round(fit$alpha, 4),
      b            = round(fit$b,     4),
      Npar         = fit$npar,
      LogLik       = round(fit$loglik, 4),
      AIC          = round(fit$AIC,    4),
      BIC          = round(fit$BIC,    4),
      Converged    = (fit$convergence == 0L),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}
