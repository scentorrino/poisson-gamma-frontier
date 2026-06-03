# Notation Warden Audit — Poisson Stochastic Frontier with Gamma Inefficiency

## Section 1: Notation Table

| Symbol | Type | Definition | First defined (file:line) | Used in |
|---|---|---|---|---|
| $Y_i$ | random variable (count) | non-negative integer output for unit $i$ | 02-model.qmd:L11 | 01, 02, 03, 04, 05, 06, 08 |
| $i$ | index | unit index, $i=1,\dots,n$ | 02-model.qmd:L11 | all |
| $n$ | scalar | sample size | 02-model.qmd:L11 | all |
| $\mathbf{x}_i$ | vector (bold) | $k$-vector of observed inputs $\in\mathbb{R}^k$ | 02-model.qmd:L11 | 01, 02, 03, 04, 05, 06, 08 |
| $k$ | scalar | dimension of $\mathbf{x}_i$ | 02-model.qmd:L11 | 02, 04 |
| $\boldsymbol{\beta}$ | vector (bold) | frontier parameter vector | 01-introduction.qmd:L19; 02-model.qmd:L19 | 01–06 |
| $\lambda_i$, $\lambda(\mathbf{x}_i;\boldsymbol{\beta})$ | function/scalar | frontier mean ($>0$) | 02-model.qmd:L11 | 01–06, 08 |
| $u_i$ | random variable | technical inefficiency, $u_i\ge 0$ | 02-model.qmd:L16,L19 | 01–06, 08 |
| $\mp/\pm$ | sign convention | upper = production, lower = cost orientation | 02-model.qmd:L19 (legitimate dual orientation) | 01–06 |
| $a_i$, $a(\mathbf{x}_i;\boldsymbol{\beta})$ | scalar | log-frontier mean $=\log\lambda_i$ | 02-model.qmd:L22 | 02, 03, 04, 06, 08 |
| $\alpha$ | scalar | Gamma shape ($>0$) | 02-model.qmd:L35 | 01–06, 08 |
| $b$ | scalar | Gamma rate ($>0$) | 02-model.qmd:L35 | 01–06, 08 |
| $f(u;\alpha,b)$ | density | Gamma density (rate parameterisation) | 02-model.qmd:L39 | 02, 08 |
| $\Gamma(\alpha)$ | function | complete gamma function | 02-model.qmd:L39 | 02, 03, 08 |
| $\mathrm{E}[\cdot]$ | operator | expectation | 02-model.qmd:L42 | all |
| $\mathrm{Var}[\cdot]$ | operator | variance | 02-model.qmd:L44 | 02, 03, 04 |
| $\Pr(\cdot)$ | operator | probability | 02-model.qmd:L60 | 02, 04, 08 |
| $y$, $y_i$ | scalar | realised count value | 02-model.qmd:L55,L60 | 02–06, 08 |
| $j$ | index | series summation index | 02-model.qmd:L62 | 02, 08 |
| $\gamma(s,x)$ | function | lower incomplete gamma | 02-model.qmd:L94,L121 | 02, 03 |
| $\Gamma(s,x)$ | function | upper incomplete gamma | 02-model.qmd:L118,L121 | 02, 03 |
| $s$ | dummy argument | shape argument of incomplete gamma | 02-model.qmd:L94 | 02 |
| $x$ | dummy argument | limit argument of incomplete gamma (local) | 02-model.qmd:L94 | 02 |
| $t$ | substitution variable | change of variable $t=e^{a_i+u}$ | 02-model.qmd:L103 | 02, 04, 08 |
| $\widehat{\mathrm{TE}}_i$ | scalar | conditional technical efficiency score $\mathrm{E}[e^{-u_i}\mid Y_i=y_i,\mathbf{x}_i]$ | 02-model.qmd:L211 | 02, 04, 05, 06 |
| $v$ | substitution variable | $v=e^{a_i+u}$ | 04-estimation.qmd:L38 | 04, 05 |
| $r$ | scalar | exponent in conditional moment $\mathrm{E}[e^{ru_i}\mid\cdot]$ | used 03-gamma-generalization.qmd:L17; defined 03:L89 / 08:L146 | 03, 08 |
| $u^*$ | random variable | baseline inefficiency draw, $u^*\sim\mathrm{Gamma}(\alpha,b)$ | 03-gamma-generalization.qmd:L101 | 03 |
| $g(z_i,\delta)$ | function | scaling function | 03-gamma-generalization.qmd:L101 | 03 |
| $z_i$ / $\mathbf{z}_i$ | vector | observed inefficiency determinants | 03-gamma-generalization.qmd:L101 (non-bold) | 03, 05, 06 |
| $\delta$ / $\boldsymbol{\delta}$ | vector | scaling parameter vector | 03-gamma-generalization.qmd:L101 (non-bold) | 03, 05, 06 |
| $b_i$ | scalar | unit-specific rate $=b\exp(-z_i'\delta)$ | 03-gamma-generalization.qmd:L105,L111 | 03, 05, 06 |
| $\delta_j$ | scalar | $j$-th component of $\delta$ | 06-empirical.qmd:L149 | 03, 06 |
| $z_{ij}$ | scalar | $j$-th determinant for unit $i$ | 05-simulations.qmd:L608; 06-empirical.qmd:L424 | 05, 06 |
| $\ell(\cdot)$ | function | log-likelihood | 03-gamma-generalization.qmd:L121; 04-estimation.qmd:L15 | 03, 04, 05 |
| $H_0$ | hypothesis | null hypothesis | 03-gamma-generalization.qmd:L142 | 03, 04, 05, 06 |
| $\chi^2$ | distribution | chi-squared | 03-gamma-generalization.qmd:L142 | 03, 04, 05, 06 |
| $\boldsymbol{\theta}$ | vector (bold) | full parameter vector $(\boldsymbol{\beta}',b,\alpha)'$ | 04-estimation.qmd:L12 | 04 |
| $\boldsymbol{\vartheta}$ | vector (bold) | unconstrained reparametrisation | 04-estimation.qmd:L25 | 04 |
| $K$ | scalar | series truncation count ($=1{,}000$) | 04-estimation.qmd:L33 | 04 |
| $\hat{\boldsymbol{\beta}}_{\text{Pois}}$ | estimator | Poisson GLM MLE | 04-estimation.qmd:L49 | 04, 05 |
| $b_0$ | scalar | starting value / true rate | 04-estimation.qmd:L56 (starter); 05:L126 (true) | 04, 05 |
| $\hat\mu_i$ | scalar | Poisson fitted values | 04-estimation.qmd:L59 | 04 |
| $\varepsilon$ | scalar | small floor / small positive constant | 04-estimation.qmd:L56,L59; reused 08:L153 | 04, 08 |
| $\alpha_0$ | scalar | starting value / true shape | 04-estimation.qmd:L59 (starter); 05:L126 (true) | 04, 05 |
| $\widehat{\mathbf{H}}$, $\widehat{\mathbf{V}}$ | matrix (bold) | numerical Hessian / its inverse | 04-estimation.qmd:L83,L85 | 04 |
| $\mathbf{I}(\boldsymbol{\vartheta}_0)$ | matrix (bold) | Fisher information matrix | 04-estimation.qmd:L113 | 04 |
| $\widehat{\mathrm{SE}}(\cdot)$ | operator | standard error | 04-estimation.qmd:L91 | 04 |
| $\Lambda$ | statistic | likelihood-ratio statistic | 04-estimation.qmd:L125 | 04, 05 |
| $\tilde{u}_i$, $v_i^*$ | scalar | kernel-mode integration centres | 04-estimation.qmd:L173,L176 | 04 |
| $\widehat\sigma_i$ | scalar | posterior SD of efficiency score | 04-estimation.qmd:L179 | 04 |
| $h(u;y_i,a_i)$ | function | conditional density kernel | 04-estimation.qmd:L168 | 04 |
| $\boldsymbol{\beta}_0$ | vector (bold) | true frontier coefficients | 05-simulations.qmd:L126 | 05 |
| $x_i$ | scalar | scalar regressor in DGP | 05-simulations.qmd:L129 | 05 |
| $\bar{u}_0$ | scalar | mean inefficiency $\alpha_0/b_0$ | 05-simulations.qmd:L129 | 05 |
| $R$ | scalar | number of MC replications | 05-simulations.qmd:L129 | 05 |
| $b^*$ | scalar | pseudo-true rate (KL-minimising) | 05-simulations.qmd:L422 | 05 |
| $\boldsymbol{\delta}_0$ | vector (bold) | true scaling vector | 05-simulations.qmd:L600,L617 | 05 |
| $b_{1,0}$, $\beta_{1,\mathrm{Pois}}$ | scalar | intercept true value / Poisson estimate | 05-simulations.qmd:L271 | 05 |

## Section 2: Violations

**Collisions (-15 each):**

No genuine same-symbol-two-objects collisions. Several symbols are deliberately overloaded but disambiguated by context and explicitly defined in each role:
- $b_0$, $\alpha_0$ serve as both *starting values* (04-estimation.qmd:L56–L64) and *true DGP parameters* (05-simulations.qmd:L126). Each role is defined in its own section and they never co-occur, so this is acceptable, not a collision.
- $\Gamma$ is used for both the complete gamma function $\Gamma(\alpha)$ and the two-argument incomplete gamma $\Gamma(s,x)$; this is standard mathematical convention (arity disambiguates) and both are explicitly defined (02-model.qmd:L39, L121).
- The $\mp/\pm$ orientation sign is the sanctioned production/cost convention and is excluded per the task rules.

No violations beyond the borderline overloads noted above, none of which rise to a true collision.

**Undefined on first use (-5 each):**

1. **$r$ used before definition** — The conditional-moment exponent $r$ first appears in $\mathrm{E}[e^{r u_i}\mid y_i,\mathbf{x}_i]$ at **03-gamma-generalization.qmd:L17** (item (ii) of the section preview) with no inline definition. It is only characterised later, at 03-gamma-generalization.qmd:L89 ("finite if and only if $r<b+y_i$") and fully in the appendix (08-appendix.qmd:L146, "the set of $r$ for which..."). At its first appearance the reader does not know $r$ is a free real exponent. (-5)

2. **$\varepsilon$ reused without redefinition** — Defined as the Poisson-dispersion floor in 04-estimation.qmd:L56,L59. It reappears as a generic "$\varepsilon>0$" in the appendix tail argument at 08-appendix.qmd:L153 in a different role (an arbitrary small constant in a limit argument). The appendix usage is locally self-contained ("given $\varepsilon>0$ there exists $M$"), so it is effectively redefined inline; flagged as borderline. (-5)

(The substitution variables $t$, $v$, $s$, $x$, the kernel centres $\tilde u_i$, $v_i^*$, and the index $j$ are all introduced with inline definitions at or before first use and are clean.)

**Typography inconsistency (-2 each):**

1. **$\delta$ / $z_i$ bold vs non-bold across sections.** In §3 (the section that *introduces* the scaling model) the scaling parameter and determinant vector are written **non-bold** throughout: `\delta` and `z_i` (e.g. 03-gamma-generalization.qmd:L101, L105, L108, L111, L113, L121, L133, L139, L142–L143). In §5 and §6 the *same vectors* are written **bold**: `\boldsymbol{\delta}` and `\mathbf{z}_i` (e.g. 05-simulations.qmd:L600, L617, L630, L633; 06-empirical.qmd:L149, L154, L370, L424). The frontier vectors $\boldsymbol{\beta}$ and $\mathbf{x}_i$ are bold everywhere including §3, so $\delta$/$z_i$ are the lone vectors that switch weight between sections. This is the single most prominent typography defect. (-2 for $\delta$; -2 for $z_i$) = **-4**

2. **$\widehat{\mathrm{TE}}$ vs $\hat{\mathrm{TE}}$.** The efficiency score is written with `\widehat` in nearly all locations (02-model.qmd:L211,L280; 04-estimation.qmd:L153,L179,L180; 05-simulations.qmd:L440,L633; 06-empirical.qmd:L375,L506) but with the narrow `\hat` at **05-simulations.qmd:L140** (`\hat{\mathrm{TE}}_i`). Same object, inconsistent accent width. (-2)

3. **$g(z_i,\delta)$ written without `\delta` bold while elsewhere the scaling function's argument is the bold vector.** This is part of the same §3 non-bold pattern already counted under item 1; not double-counted.

## Score

Starting score: 100
- Collisions: 0 × (-15) = 0
- Undefined on first use: 2 × (-5) = -10
- Typography inconsistency: ($\delta$ -2) + ($z_i$ -2) + (TE accent -2) = -6

**Final score: 100 − 10 − 6 = 84**

**Gate: CLEARS the 80 threshold (84 ≥ 80).**

### Primary remediation priority (for the author, not applied here)
1. Unify $\delta$/$z_i$ to bold (`\boldsymbol{\delta}`, `\mathbf{z}_i`) in §3 to match §5/§6 — this is the dominant inconsistency and the cleanest single fix.
2. Add an inline definition of the exponent $r$ at its first appearance in 03-gamma-generalization.qmd:L17 (e.g. "for $r\in\mathbb{R}$").
3. Change `\hat{\mathrm{TE}}_i` to `\widehat{\mathrm{TE}}_i` at 05-simulations.qmd:L140.
