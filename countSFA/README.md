# countSFA

Count-data stochastic frontier models for R.

`countSFA` implements maximum likelihood estimation of Poisson
stochastic frontier models for non-negative integer outcomes such as
patent counts, hospital admissions, and accident reports. It supports
three parametric families for the one-sided inefficiency term:

- **Exponential** — closed-form marginal probability mass function via
  the lower incomplete gamma function;
- **Gamma** — marginal PMF expressible as an absolutely convergent
  alternating series with an automatically chosen truncation depth;
- **Half-normal** — the Fé & Hofler (2013) benchmark, evaluated by
  maximum simulated likelihood with antithetic Halton draws.

Both production-frontier and cost-frontier orientations are supported.
The package also provides posterior technical efficiency scores and
model-comparison utilities (likelihood-ratio and Vuong tests).

## Installation

```r
# install.packages("remotes")
remotes::install_github("scentorrino/countSFA")
```

## Quick start

```r
library(countSFA)
data(patents)

X <- model.matrix(
  ~ log_rd + log_k + science_sector + factor(year),
  data = patents
)
y <- patents$patents

fit <- fit_poisson_frontier(y, X, dist = "exponential")
summary(fit)

scores <- efficiency_scores(fit, y, X)
head(scores)
```

See `vignette("empirical-application", package = "countSFA")` for a
full walkthrough using the Hausman, Hall, and Griliches (1984)
patents-R&D panel.

## Citation

The methodology is described in:

> Centorrino, S. and Perez Urdiales, M. (2026). *Count Data
> Stochastic Frontier Models with Gamma Inefficiency*. Working paper.

`citation("countSFA")` returns the canonical reference.

## License

MIT.
