# Project: Poisson Stochastic Frontier with Gamma Inefficiency

## What this paper does
This paper proposes and estimates a count-data stochastic frontier model where:
- Output Y | u ~ Poisson(exp(x'β - u))
- Inefficiency u ~ Gamma(α, b)
- The marginal PMF is:
    P(Y=y) = (b^α * exp(ay)) / y! * Σ_k [(-1)^k exp(ka)] / [k! (y+b+k)^α]
- The α=1 (exponential) special case yields:
    P(Y=y) = (b*exp(-ab)/y!) * γ(y+b, exp(a))

## Key contributions
1. Closed-form marginal PMF via incomplete gamma / convergent series
2. Exponential and Gamma inefficiency generalizations of Fé & Hofler (2013)
3. MLE estimation, Monte Carlo validation, empirical application

## Closest prior work
- Fé & Hofler (2013): Poisson + half-normal inefficiency (JProdAnal)
- Hofler & Scrogin (2008): count data frontier, Beta-Binomial
- Meeusen & van den Broeck (1977): exponential inefficiency in continuous SFA

## Toolchain — QUARTO MANUSCRIPT
- All prose and code live together in .qmd files (one per section)
- R is the computation language throughout
- Figures: ggplot2, rendered inline by knitr chunks
- Tables: knitr::kable() + kableExtra for PDF-quality tables
- Math: standard LaTeX inside $...$ and $$...$$, or equation environments
- Cross-references: use @fig-xxx, @tbl-xxx, @eq-xxx, @sec-xxx (Quarto syntax)
- Citations: [@feHofler2013] style from references.bib
- Caching: all heavy chunks must set #| cache: true
- Shared R code: source("code/estimation_functions.R") at top of each .qmd that needs it
- Build command: quarto render (produces PDF + HTML simultaneously)
- NEVER write raw .tex files — all content goes in .qmd files

## Section files
- index.qmd          → title, abstract, keywords (no code chunks)
- 01-introduction.qmd
- 02-model.qmd       → setup, marginal PMF and efficiency score under Gamma inefficiency (both production and cost orientations); exponential α=1 case as a closed-form corollary
- 03-gamma-generalization.qmd → moments, existence regions for unconditional/conditional moments, and the scaling model for inefficiency determinants (filename retained for stability; content is no longer "the Gamma extension" since §2 already covers it)
- 04-estimation.qmd
- 05-simulations.qmd  → sources and runs montecarlo.R
- 06-empirical.qmd    → sources application.R
- 07-conclusion.qmd

## Theory section ordering convention
When writing or revising theory: present the general Gamma case first as the
main proposition (both production and cost orientations) and treat the
exponential α=1 case as a closed-form corollary. Do NOT split the exponential
and Gamma cases into separate sections.

## Code files (pure R, sourced by .qmd files)
- code/estimation_functions.R  → log-likelihoods, fitting wrapper, efficiency scores
- code/simulations/montecarlo.R
- code/empirical/application.R