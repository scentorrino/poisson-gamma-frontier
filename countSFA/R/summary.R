#' Summary method for Poisson frontier model fits
#'
#' Prints a formatted coefficient table and model statistics to the console,
#' and invisibly returns a \code{data.frame} suitable for
#' \code{\link[knitr]{kable}}.  When the fit includes a scaling model on
#' the inefficiency rate (\code{fit$delta} of positive length), one
#' additional row per determinant is appended to the table with label
#' \code{delta.<zname>}; the header also reports the scaling-model
#' dimension.
#'
#' @param object A \code{"poisson_frontier"} object.
#' @param digits Number of digits for rounding in the printed table (default 4).
#' @param ...    Currently ignored.
#'
#' @return Invisibly, a \code{data.frame} with columns \code{Parameter},
#'   \code{Estimate}, \code{Std.Error}, \code{z.value}, \code{p.value}.
#'
#' @examples
#' \donttest{
#' set.seed(1L)
#' n <- 200L
#' X <- cbind(1, rnorm(n))
#' u <- rexp(n, rate = 2)
#' y <- rpois(n, lambda = exp(drop(X %*% c(1, 0.5)) - u))
#' fit <- fit_poisson_frontier(y, X, dist = "exponential")
#' summary(fit)
#' }
#'
#' @importFrom stats pnorm
#' @export
summary.poisson_frontier <- function(object, digits = 4, ...) {

  fit <- object

  # ---- Build coefficient table ---------------------------------------------
  params <- c(fit$coefficients, b = fit$b)
  ses    <- c(fit$se,           b = fit$se_b)

  if (!is.na(fit$se_alpha)) {
    params <- c(params, alpha = fit$alpha)
    ses    <- c(ses,    alpha = fit$se_alpha)
  }

  # Append the scaling-model block when present.  Names already on $delta
  # are prefixed with "delta." to keep the table unambiguous in case any
  # z-name collides with a beta-name (e.g. shared regressor).
  has_delta <- !is.null(fit$delta) && length(fit$delta) > 0L
  if (has_delta) {
    delta_names <- names(fit$delta)
    if (is.null(delta_names))
      delta_names <- paste0("z", seq_along(fit$delta))
    delta_lbl   <- paste0("delta.", delta_names)
    delta_vec   <- setNames(fit$delta,    delta_lbl)
    delta_se    <- setNames(fit$se_delta, delta_lbl)
    params <- c(params, delta_vec)
    ses    <- c(ses,    delta_se)
  }

  zval  <- params / ses
  pval  <- 2 * pnorm(-abs(zval))
  stars <- ifelse(pval < 0.001, "***",
           ifelse(pval < 0.01,  "**",
           ifelse(pval < 0.05,  "*",
           ifelse(pval < 0.1,   ".", ""))))

  tbl <- data.frame(
    Parameter = names(params),
    Estimate  = round(params,  digits),
    Std.Error = round(ses,     digits),
    z.value   = round(zval,    digits),
    p.value   = round(pval,    digits),
    Sig       = stars,
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  # ---- Console output ------------------------------------------------------
  dist_label <- if (fit$dist == "exponential") "Exponential (alpha=1)"
                else sprintf("Gamma (alpha=%.4f)", fit$alpha)
  scaling_label <- if (has_delta)
    sprintf("yes (b_i = b*exp(-z_i'delta), m=%d)", length(fit$delta))
    else "no (homogeneous)"

  cat("\n=== Poisson Stochastic Frontier Model ===\n")
  cat(sprintf("Inefficiency distribution : %s\n", dist_label))
  cat(sprintf("Scaling model on b        : %s\n", scaling_label))
  cat(sprintf("Observations              : %d\n", fit$n))
  cat(sprintf("Parameters estimated      : %d\n", fit$npar))
  cat(sprintf("Log-likelihood            : %.4f\n", fit$loglik))
  cat(sprintf("AIC                       : %.4f\n", fit$AIC))
  cat(sprintf("BIC                       : %.4f\n\n", fit$BIC))

  print(tbl[, c("Parameter", "Estimate", "Std.Error", "z.value", "p.value", "Sig")],
        row.names = FALSE)
  cat("---\nSignif. codes: *** <0.001  ** <0.01  * <0.05  . <0.1\n\n")

  if (fit$convergence != 0L)
    warning(sprintf("optim convergence code = %d", fit$convergence),
            call. = FALSE)

  invisible(tbl)
}
