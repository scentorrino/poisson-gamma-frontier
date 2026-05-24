# profile_alpha.R — run interactively to diagnose M6 non-convergence
# Usage: source("code/empirical/profile_alpha.R")
library(countSFA)
library(ggplot2)
emp <- readRDS("results/empirical_fits.rds")
y <- emp$y; X <- emp$X
p <- ncol(X)
fit_exp <- emp$fit_exp

alpha_grid <- seq(0.3, 6, length.out = 40)

profile_ll <- sapply(alpha_grid, function(al) {
  nll_fixed_alpha <- function(params, y, X, alpha_fixed) {
    beta  <- params[seq_len(p)]
    b     <- exp(params[p + 1L])
    if (!is.finite(b) || b < 1e-4 || b > 1e4) return(1e15)
    lp <- sapply(seq_along(y),
      function(i) pmf_poisson_gamma(y[i], drop(X[i,] %*% beta), b, alpha_fixed))
    -sum(lp)
  }
  opt <- tryCatch(
    optim(c(fit_exp$coefficients, log(fit_exp$b)), nll_fixed_alpha,
          y=y, X=X, alpha_fixed=al, method="L-BFGS-B",
          lower=c(rep(-10,p),-3), upper=c(rep(10,p),6),
          control=list(maxit=1000, factr=1e8)),
    error = function(e) list(value=Inf)
  )
  -opt$value
})

profile_df <- data.frame(
  alpha   = alpha_grid,
  loglik  = profile_ll,
  loglik_c = profile_ll - max(profile_ll, na.rm=TRUE)
)

p_plot <- ggplot(profile_df, aes(x=alpha, y=loglik_c)) +
  geom_line(colour="steelblue", linewidth=0.9) +
  geom_point(colour="steelblue", size=1.5) +
  geom_vline(xintercept=1, linetype="dashed", colour="firebrick") +
  geom_hline(yintercept=-qchisq(0.95,1)/2, linetype="dotted", colour="grey40") +
  labs(x=expression(alpha), y="Profile log-likelihood (centred)",
       title="Profile log-likelihood for alpha — patent data") +
  theme_bw(base_size=11)

ggsave("results/profile_alpha.png", p_plot, width=6, height=4, dpi=150)
cat("Profile plot saved to results/profile_alpha.png\n")
print(p_plot)
