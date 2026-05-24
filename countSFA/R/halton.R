#' Generate a Halton (van der Corput) low-discrepancy sequence
#'
#' Returns the first \code{n} elements of the van der Corput sequence in the
#' given prime base.  The values lie in \eqn{(0, 1)} and are deterministic
#' (no random seed required), making this a drop-in alternative to
#' \code{randtoolbox::halton} for the small dimensions used by maximum
#' simulated likelihood routines in this package.
#'
#' @param n    Number of points to generate.
#' @param base Integer prime base (default 2).  Use distinct primes for
#'   different simulation dimensions to avoid correlated draws.
#'
#' @return Numeric vector of length \code{n} with values in \eqn{(0, 1)}.
#'
#' @keywords internal
halton_seq <- function(n, base = 2L) {
  out <- numeric(n)
  for (i in seq_len(n)) {
    f <- 1
    r <- 0
    k <- i
    while (k > 0) {
      f <- f / base
      r <- r + f * (k %% base)
      k <- k %/% base
    }
    out[i] <- r
  }
  out
}
