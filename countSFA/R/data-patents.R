#' Patents and R&D panel of Hausman, Hall, and Griliches (1984)
#'
#' Annual counts of U.S. patent applications (eventually granted) for 346
#' manufacturing firms over five years, together with research and
#' development (R&D) expenditure, capital stock, and a science-sector
#' indicator. This is the canonical benchmark dataset for count-data
#' econometrics, used in Hausman, Hall and Griliches (1984), Hall,
#' Griliches and Hausman (1986), Cameron and Trivedi (2005, Chapter~23),
#' and many subsequent papers.
#'
#' @format A \code{data.frame} with 1730 rows (346 firms × 5 years) and
#'   15 columns:
#' \describe{
#'   \item{\code{firm}}{Integer firm identifier (CUSIP).}
#'   \item{\code{year}}{Integer 1--5 (calendar years 1968--1972).}
#'   \item{\code{patents}}{Annual count of patent applications eventually
#'     granted to firm \eqn{i} in year \eqn{t}. Range 0--515.}
#'   \item{\code{patents_l1}--\code{patents_l4}}{Patent counts lagged
#'     1--4 years (pre-sample lags supplied for year~1).}
#'   \item{\code{log_rd}}{Log of real R&D expenditure (1972 USD).}
#'   \item{\code{log_rd_l1}--\code{log_rd_l4}}{Log R&D lagged 1--4 years.}
#'   \item{\code{log_k}}{Log of firm capital stock.}
#'   \item{\code{science_sector}}{0/1 indicator: 1 for firms in the
#'     science sector (chemistry, electronics, scientific instruments).}
#'   \item{\code{industry}}{Integer 2-digit industry code.}
#' }
#'
#' @source Hausman, J. A., Hall, B. H., and Griliches, Z. (1984).
#'   Econometric models for count data with an application to the
#'   patents-R&D relationship. \emph{Econometrica} \strong{52}, 909--938.
#'
#'   The CSV form distributed with the manuscript follows the legacy
#'   column naming convention of the standard \emph{patents} dataset; the
#'   \code{countSFA::patents} version above adopts descriptive column
#'   names (e.g.\ \code{patents} for the count, \code{log_rd} for log
#'   R&D expenditure) to avoid the historical confusion in which the
#'   \code{logr*} columns of the CSV actually contain integer counts and
#'   the \code{pat*} columns contain log R&D values.
#'
#' @examples
#' data(patents, package = "countSFA")
#' summary(patents$patents)
#' table(patents$year)
#' @docType data
#' @keywords datasets
#' @name patents
"patents"
