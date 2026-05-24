Read CLAUDE.md. Create code/estimation_functions.R with the following functions.
This file is sourced by multiple .qmd sections so it must be self-contained.

Functions to implement:

1. pmf_poisson_gamma(y, a, b, alpha, K = 100)
   - Evaluates log P(Y=y) using the series, truncated at K terms
   - Checks convergence: warns if |last term| > 1e-10
   - Handles alpha=1 via the closed-form incomplete gamma (use pgamma())

2. log_lik_poisson_frontier(params, y, X, alpha = NULL)
   - If alpha is NULL, estimate it; otherwise treat as fixed
   - params = c(beta, log_b) or c(beta, log_b, log_alpha)
   - Returns negative log-likelihood (for use with optim)

3. fit_poisson_frontier(y, X, dist = "exponential", alpha = NULL, starts = NULL)
   - Calls optim(method = "BFGS") with numerical Hessian
   - Returns S3 object of class "poisson_frontier" with:
     $coefficients, $se, $loglik, $AIC, $BIC, $alpha, $b, $vcov

4. efficiency_scores(fit, y, X)
   - Computes E[exp(-u_i) | y_i] by numerical integration via integrate()
   - Returns data.frame with columns: i, eff_score, eff_lower, eff_upper

5. summary.poisson_frontier(fit)
   - Clean console output + returns a data.frame suitable for kable()

6. compare_models(fit_list, names)
   - Takes a named list of fitted models
   - Returns kable-ready data.frame: model name, log-lik, AIC, BIC, estimated params

Add roxygen2-style comments to each function.
At the bottom add a stopifnot()-based test block wrapped in if(interactive()){...}.