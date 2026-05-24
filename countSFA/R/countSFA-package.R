#' countSFA: Count-Data Stochastic Frontier Models
#'
#' Maximum likelihood estimation of Poisson stochastic frontier models for
#' count outcomes. The package implements three parametric families for
#' the one-sided inefficiency term:
#'
#' \itemize{
#'   \item \strong{Exponential}, with a closed-form marginal probability
#'     mass function via the lower incomplete gamma function.
#'   \item \strong{Gamma}, with a marginal PMF expressible as an
#'     absolutely convergent alternating series and an automatically
#'     chosen truncation depth.
#'   \item \strong{Half-normal}, evaluated by maximum simulated likelihood
#'     with antithetic Halton draws (Fé and Hofler, 2013).
#' }
#'
#' Both production-frontier and cost-frontier orientations are supported.
#' The package also provides posterior technical efficiency scores and
#' model-comparison utilities (likelihood-ratio and Vuong tests).
#'
#' @section Main functions:
#' \itemize{
#'   \item \code{\link{fit_poisson_frontier}} — fit the exponential or
#'     Gamma frontier by ML.
#'   \item \code{\link{fit_poisson_halfnormal}} — fit the half-normal
#'     frontier by maximum simulated likelihood.
#'   \item \code{\link{efficiency_scores}},
#'     \code{\link{efficiency_scores_halfnormal}} — posterior efficiency
#'     scores \eqn{\mathrm{E}[e^{-u_i}\mid y_i]}.
#'   \item \code{\link{vuong_test}} — Vuong (1989) test for non-nested
#'     model comparison.
#'   \item \code{\link{compare_models}} — kable-ready comparison of
#'     fitted models.
#' }
#'
#' @references
#' Centorrino, S. and Perez Urdiales, M. (2026). Count Data Stochastic
#' Frontier Models with Gamma Inefficiency. Working paper.
#'
#' Aigner, D., Lovell, C. A. K. and Schmidt, P. (1977). Formulation and
#' estimation of stochastic frontier production function models.
#' \emph{Journal of Econometrics} \strong{6}, 21--37.
#'
#' Meeusen, W. and van den Broeck, J. (1977). Efficiency estimation from
#' Cobb-Douglas production functions with composed error.
#' \emph{International Economic Review} \strong{18}, 435--444.
#'
#' Greene, W. H. (1980). Maximum likelihood estimation of econometric
#' frontier functions. \emph{Journal of Econometrics} \strong{13}, 27--56.
#'
#' Greene, W. H. (1990). A gamma-distributed stochastic frontier model.
#' \emph{Journal of Econometrics} \strong{46}, 141--163.
#'
#' Greene, W. H. (2003). Simulated likelihood estimation of the
#' normal-gamma stochastic frontier function. \emph{Journal of
#' Productivity Analysis} \strong{19}, 179--190.
#'
#' Fé, E. and Hofler, R. A. (2013). Count data stochastic frontier
#' models, with an application to the patents-R&D relationship.
#' \emph{Journal of Productivity Analysis} \strong{39}, 271--284.
#'
#' Fé, E. and Hofler, R. A. (2020). sfcount: Command for count-data
#' stochastic frontiers and underreported and overreported counts.
#' \emph{Stata Journal} \strong{20}, 532--547.
#'
#' Fé, E. (2019). Stochastic Frontier Models for Discrete Output
#' Variables. In: \emph{The Palgrave Handbook of Economic Performance
#' Analysis}, Palgrave Macmillan, 275--300.
#'
#' Vuong, Q. H. (1989). Likelihood ratio tests for model selection and
#' non-nested hypotheses. \emph{Econometrica} \strong{57}, 307--333.
#'
#' Andrews, D. W. K. (2001). Testing when a parameter is on the boundary
#' of the maintained hypothesis. \emph{Econometrica} \strong{69},
#' 683--734.
#'
#' @keywords internal
"_PACKAGE"
