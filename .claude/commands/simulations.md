Read CLAUDE.md and code/estimation_functions.R.

Write two things:

1. code/simulations/montecarlo.R — the simulation engine:
   - DGP: Y_i | u_i ~ Poisson(exp(x_i'β - u_i)), u_i ~ Gamma(α, b)
   - True params: β=(1, 0.5), α ∈ {1, 2}, b ∈ {1, 2}, n ∈ {100, 500, 1000}
   - R = 1000 replications, set.seed(42)
   - Estimate three models per replication: Poisson, Poisson-Exp-Frontier, Poisson-Gamma-Frontier
   - Compute bias, RMSE, coverage of 95% CI for all parameters
   - Compute MAE of efficiency scores vs truth
   - Save results list to code/simulations/results.rds
   - Use parallel::mclapply for speed; print progress every 100 reps

2. 05-simulations.qmd — the paper section:

   Structure:
   - Prose: DGP description, estimators compared, design rationale
   - R setup chunk: source functions, load results.rds (#| cache: true)
   - Table chunk (#| label: tbl-sim-bias): bias/RMSE table via kable + kableExtra
     with booktabs=TRUE, caption, grouped rows by sample size
   - Figure chunk (#| label: fig-sim-rmse): ggplot2 RMSE vs n, faceted by α
   - Figure chunk (#| label: fig-sim-coverage): coverage probability bar chart
   - Prose interpreting results, cross-referencing @tbl-sim-bias and @fig-sim-rmse

All figure chunks must include:
  #| fig-cap: "..."
  #| fig-width: 6
  #| fig-height: 4