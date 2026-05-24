#' Method-of-moments starting values for the homogeneous Poisson-Gamma frontier
#'
#' Computes scale-aware starting values for $(\boldsymbol{\beta}, b, \alpha)$
#' from a Poisson GLM warm-start combined with the second and third
#' Pearson-corrected moments of $Y$.
#'
#' @details
#' The Poisson GLM gives consistent slope estimates under the Poisson-Gamma
#' DGP; its intercept is biased by $\alpha \log(\nu_1)$ with
#' $\nu_1 = (b / (b - s))^\alpha$ and $s = -1$ in production
#' / $s = +1$ in cost. The function recovers $(\alpha, b)$ from two
#' scale-invariant moment ratios. With residual $r_i = Y_i - \hat\mu_i$ and
#' the conditional Poisson-Gamma identities $E[Y(Y-1)\dots(Y-k+1) \mid x] =
#' \lambda^k \nu_k$, one shows that
#' \deqn{S_2 \;\equiv\; \mathrm{avg}\!\left(\frac{r_i^2 - \hat\mu_i}{\hat\mu_i^2}\right)
#'   \;\xrightarrow{p}\; R_2(b)^\alpha - 1,}
#' \deqn{S_3 \;\equiv\; \mathrm{avg}\!\left(\frac{r_i^3 - 3 r_i^2 + 2 Y_i}{\hat\mu_i^3}\right)
#'   \;\xrightarrow{p}\; R_3(b)^\alpha - 3 R_2(b)^\alpha + 2,}
#' where $R_2(b) = (b - s)^2 / [b (b - 2 s)]$ and
#' $R_3(b) = (b - s)^3 / [b^2 (b - 3 s)]$. The cross-product terms in $S_3$
#' cancel exactly — the formula above is not a large-$\lambda$
#' approximation. Hence $\mathrm{rhs}_3 \equiv \hat S_3 + 3 \hat S_2 + 1
#' \to R_3(b)^\alpha$, and
#' \deqn{T(b) \;\equiv\; \frac{\log R_3(b)}{\log R_2(b)}
#'   \;=\; \frac{\log \mathrm{rhs}_3}{\log(\hat S_2 + 1)}
#'   \;\equiv\; T_{\mathrm{sample}},}
#' which is $\alpha$-free and monotone in $b$ on each orientation's domain
#' ($b > 0$ for production, $b > 3$ for cost). \code{uniroot} solves
#' $T(b) = T_{\mathrm{sample}}$, then
#' $\hat\alpha = \log(\hat S_2 + 1) / \log R_2(\hat b)$.
#'
#' The Poisson-GLM intercept is finally bias-corrected by
#' $\hat\alpha \log(b/(b - s))$.
#'
#' Falls back to $\alpha = 1$, $b = 1$ (production) or $b = 2.5$ (cost)
#' when the moment system is under-determined (e.g.\ $\hat S_2$ has the
#' wrong sign, or $T_{\mathrm{sample}}$ lies outside the achievable range
#' of $T(b)$).
#'
#' @param y Non-negative integer outcome vector.
#' @param X Model matrix (n x k). The first column is treated as the
#'   intercept for the bias-correction step.
#' @param orientation Character: \code{"production"} (default) or
#'   \code{"cost"}.
#'
#' @return A list with components \code{beta}, \code{b}, \code{alpha},
#'   \code{success}.
#'
#' @examples
#' set.seed(1)
#' n <- 1000
#' z <- rnorm(n); X <- cbind(1, z)
#' u <- rgamma(n, shape = 2, rate = 1)
#' y <- rpois(n, exp(drop(X %*% c(1, 0.5)) - u))
#' mom_starts(y, X, orientation = "production")
#'
#' @importFrom stats glm poisson coef fitted uniroot
#' @export
mom_starts <- function(y, X, orientation = c("production", "cost")) {

  orientation <- match.arg(orientation)
  if (!is.matrix(X)) X <- as.matrix(X)
  k   <- ncol(X)
  sgn <- if (orientation == "production") -1 else +1

  fallback_b <- if (orientation == "cost") 2.5 else 1
  fallback   <- function(beta_vec) {
    if (k >= 1L) {
      denom_fb <- fallback_b - sgn
      if (denom_fb > 0) {
        beta_vec[1] <- beta_vec[1] - 1 * log(fallback_b / denom_fb)
      }
    }
    list(beta = beta_vec, b = fallback_b, alpha = 1, success = FALSE)
  }

  # ---- 1. Poisson GLM for the slope warm-start ---------------------------
  glm_fit  <- suppressWarnings(stats::glm(y ~ X - 1, family = stats::poisson()))
  beta_glm <- unname(stats::coef(glm_fit))
  mu_hat   <- stats::fitted(glm_fit)
  if (!all(is.finite(mu_hat)) || any(mu_hat <= 0)) return(fallback(beta_glm))

  # ---- 2. Sample moments ------------------------------------------------
  resid <- y - mu_hat
  S2 <- mean((resid^2 - mu_hat)               / mu_hat^2)
  S3 <- mean((resid^3 - 3 * resid^2 + 2 * y)  / mu_hat^3)
  if (!is.finite(S2) || S2 <= 1e-3) return(fallback(beta_glm))

  rhs3 <- S3 + 3 * S2 + 1            # -> R_3(b)^alpha in probability
  if (!is.finite(rhs3) || rhs3 <= 1) return(fallback(beta_glm))

  # ---- 3. Alpha-free root equation T(b) = T_sample ----------------------
  R2 <- if (orientation == "production") {
    function(b) (b + 1)^2 / (b * (b + 2))
  } else {
    function(b) (b - 1)^2 / (b * (b - 2))
  }
  R3 <- if (orientation == "production") {
    function(b) (b + 1)^3 / (b^2 * (b + 3))
  } else {
    function(b) (b - 1)^3 / (b^2 * (b - 3))
  }

  T_fun <- function(b) {
    lr2 <- log(R2(b)); lr3 <- log(R3(b))
    if (!is.finite(lr2) || lr2 <= 0 || !is.finite(lr3) || lr3 <= 0) {
      return(NA_real_)
    }
    lr3 / lr2
  }
  T_sample <- log(rhs3) / log(S2 + 1)

  b_lower <- if (orientation == "production") 0.05 else 3.05
  b_upper <- 1e3

  g <- function(b) {
    tv <- T_fun(b)
    if (is.na(tv)) return(NA_real_)
    tv - T_sample
  }
  g_lo <- g(b_lower); g_hi <- g(b_upper)
  if (is.na(g_lo) || is.na(g_hi) || sign(g_lo) == sign(g_hi)) {
    return(fallback(beta_glm))
  }

  sol <- tryCatch(stats::uniroot(g, c(b_lower, b_upper), tol = 1e-4),
                  error = function(e) NULL)
  if (is.null(sol)) return(fallback(beta_glm))

  b_hat     <- sol$root
  alpha_hat <- log(S2 + 1) / log(R2(b_hat))

  if (!is.finite(b_hat) || !is.finite(alpha_hat) ||
      b_hat <= 0 || alpha_hat <= 0) {
    return(fallback(beta_glm))
  }

  b_hat     <- pmin(pmax(b_hat,     0.1), 1e3)
  alpha_hat <- pmin(pmax(alpha_hat, 0.2), 50)

  # ---- 4. Intercept bias correction -------------------------------------
  if (k >= 1L) {
    denom <- b_hat - sgn   # b + 1 (production) or b - 1 (cost)
    if (denom > 0) {
      shift <- alpha_hat * log(b_hat / denom)
      beta_glm[1] <- beta_glm[1] - shift
    }
  }

  list(beta = beta_glm, b = b_hat, alpha = alpha_hat, success = TRUE)
}
