---
description: Revise the theory sections of the Poisson stochastic frontier paper to incorporate results on moment existence, MLE validity, inefficiency determinants via the scaling model, and the goods/bads symmetry.
argument-hint: [section file to revise, e.g. "02-model.qmd" or "all"]
---

Read CLAUDE.md carefully to understand the model setup, notation conventions, and
the section structure of the paper.

Then read every .qmd file in the project, paying particular attention to:
- The section where the marginal PMF is derived
- Any discussion of the Gamma distribution for inefficiency
- Any existing comparison with Fé & Hofler (2013)
- The conclusion and future work sections

Also read references.bib to confirm which keys exist for Fé & Hofler (2013),
Wang & Schmidt (2002), and Caudill & Ford (1993). If any are missing, add them.

---

## YOUR TASK

Revise the paper to incorporate the following theoretical developments.
Each point below specifies what to add, where to add it, and the mathematical
content to include. Write in the style of the surrounding prose — no bullet
lists in the main text, numbered equations with {#eq-labelname}, cross-references
via @eq-, @sec-, [@key].

---

### POINT 1 — The Fe & Hofler moment problem and MLE validity

**Where:** In the section discussing the Gamma inefficiency distribution,
immediately after the PMF formula is presented.

**What to add:**

Add a paragraph (and a short remark environment if the paper uses them)
acknowledging that Fé & Hofler (2013, fn. 7) identify a genuine moment problem
for Gamma inefficiency. The structure of the argument must be:

Step 1 — State their result precisely.
For the economic bads parameterisation $\lambda_i = \exp(x_i'\beta + u_i)$
with $u_i \sim \text{Gamma}(\alpha, b)$, the r-th moment of
$m_i = \exp(u_i)$ exists only if $b > r$. In particular
$\mathbb{E}(\exp(u_i))$ — which governs inefficiency scores — exists only
if $b > 1$, and the variance of $Y_i$ requires $b > 2$.

Step 2 — Clarify that this is a statement about moments of Y, not about
the PMF itself. The PMF:

$$P(Y_i = y) = \frac{b\,e^{a_i b}}{y!} \cdot \Gamma(y - b,\; e^{a_i})$$

always converges for any $b > 0$ because the super-exponential decay of
$e^{-t}$ in the upper incomplete gamma function dominates the polynomial
term $t^{y-b-1}$ regardless of the sign of $y - b - 1$. Cite this as a
key distinction: existence of the PMF and existence of its moments are
separate questions.

Step 3 — State the MLE validity result. Because the PMF is well-defined
for all $b > 0$, the log-likelihood $\ell(\theta) = \sum_i \log P(Y_i = y_i)$
is well-defined and can be maximised. Standard regularity conditions
(smoothness of the log-likelihood, compactness of the parameter space)
are sufficient for consistency and asymptotic normality of the MLE
regardless of whether moments of $Y_i$ exist. This is analogous to MLE
for the Cauchy location model, where the mean does not exist but the MLE
is $\sqrt{n}$-consistent.

Step 4 — State when inefficiency scores exist. The posterior mean efficiency
score $\mathbb{E}[\exp(-u_i) \mid y_i, x_i]$ (goods case) always exists
for any $b > 0$ because it involves $\exp(-u_i)$, i.e. the MGF of the
Gamma evaluated at $t = -1$, which is $\left(\frac{b}{b+1}\right)^\alpha$
and is finite for all $\alpha, b > 0$ with no restrictions. Contrast this
with the bads case score $\mathbb{E}[\exp(+u_i) \mid y_i, x_i]$, which
requires $b > 1$. Add an explicit display equation for both:

$$\mathbb{E}[e^{-u} ] = \left(\frac{b}{b+1}\right)^\alpha, \quad \text{(goods, always finite)}$$

$$\mathbb{E}[e^{+u}] = \left(\frac{b}{b-1}\right)^\alpha, \quad b > 1 \text{ required (bads)}$$

Note that a practitioner can check post-estimation whether $\hat{b} > 1$;
if not, the bads-case score does not exist, and simulation-based approximation
of the posterior mean is required instead.

---

### POINT 2 — The economic goods / bads symmetry as a new result

**Where:** In the section presenting the exponential (α = 1) model, as a
separate subsection or numbered remark, before the Gamma generalisation.

**What to add:**

This paper's model covers both economic goods and economic bads in closed
form — a property Fé & Hofler (2013) do not achieve simultaneously.
Present the two cases side by side with a display table or two-column
equation block:

Goods case ($\lambda_i = \exp(a_i - u_i)$, u reduces output):
$$P(Y_i = y) = \frac{b\,e^{-a_i b}}{y!} \cdot \gamma(y + b,\; e^{a_i})$$

Bads case ($\lambda_i = \exp(a_i + u_i)$, u inflates output):
$$P(Y_i = y) = \frac{b\,e^{a_i b}}{y!} \cdot \Gamma(y - b,\; e^{a_i})$$

where $\gamma(\cdot,\cdot)$ and $\Gamma(\cdot,\cdot)$ are the lower and
upper incomplete gamma functions respectively. Emphasise the symmetry:
the sign of $a_i b$ flips, and lower and upper incomplete gamma exchange.
Both are available in standard software (R: `pgamma(..., lower=TRUE/FALSE)`,
Python: `scipy.special.gammainc` / `gammaincc`).

Explain the derivation in one paragraph: in the bads case, substitute
$t = e^{a_i} e^u$ in the integral $\int_0^\infty \exp((y-b)u - e^{a_i}e^u)du$,
giving $e^{-a_i(y-b)} \int_{e^{a_i}}^\infty t^{y-b-1} e^{-t} dt$, which
is the upper incomplete gamma by definition. The goods case uses the same
substitution with $t = e^{a_i} e^{-u}$, running from 0 to $e^{a_i}$,
giving the lower incomplete gamma.

---

### POINT 3 — Inefficiency determinants via the scaling model

**Where:** Add a new subsection titled "Inefficiency Determinants" (or
"The Scaling Model") after the core model derivation and before the
estimation section. Label it {#sec-scaling}.

**What to add:**

Paragraph 1 — Motivation. The homogeneous model assumes all firms draw
from the same inefficiency distribution, implying a common mean
$\mathbb{E}(u_i) = 1/b$. In practice, systematic firm-level factors
(size, age, ownership, industry) may shift the level of inefficiency.
The scaling model of Caudill and Ford (1993) and Wang and Schmidt (2002)
accommodates this by writing:

$$u_i = h(z_i, \delta) \cdot u^*, \quad u^* \sim \text{Exp}(b)$$

so that $u_i \sim \text{Exp}(b_i)$ with $b_i = b / h(z_i, \delta)$,
where $z_i$ is a vector of inefficiency determinants and $\delta$ is a
parameter vector to be estimated jointly with $\beta$.

Paragraph 2 — Closed form survives. Because the PMF depends on $b$ only
through the scalar $b_i > 0$, the closed-form expressions in @eq-goods-pmf
and @eq-bads-pmf hold observation-by-observation with $b$ replaced by
$b_i$. The log-likelihood becomes:

$$\ell(\beta, b, \delta) = \sum_{i=1}^n \left[
  \log b_i - b_i a_i + \log \gamma(y_i + b_i,\; e^{a_i}) - \log y_i!
\right]$$

(goods case). No approximation or simulation is required. This is a
significant computational advantage over scaling models for continuous
output SFMs, where simulation is typically required.

Paragraph 3 — Choice of scaling function. The standard choice is
$h(z_i, \delta) = \exp(z_i'\delta)$, giving $b_i = b \cdot \exp(-z_i'\delta)$.
This guarantees $b_i > 0$ for all values of $\delta$, makes the mean
inefficiency $\mathbb{E}(u_i) = \exp(z_i'\delta)/b$ log-linear in the
determinants, and ensures $b_i \to \infty$ (full efficiency) when
$z_i'\delta \to -\infty$. Include the display equation:

$$b_i = b \cdot \exp(-z_i'\delta), \quad \mathbb{E}(u_i) = \frac{\exp(z_i'\delta)}{b}$$

Paragraph 4 — Efficiency scores under scaling. The posterior mean
efficiency score inherits the same analytic form:

$$\mathbb{E}[e^{-u_i} \mid y_i, x_i, z_i] = e^{-a_i} \cdot
\frac{\gamma(y_i + b_i + 1,\; e^{a_i})}{\gamma(y_i + b_i,\; e^{a_i})}$$

Derive this in one sentence: the posterior kernel is proportional to
$\exp(-(y_i + b_i + 1)u_i - e^{a_i - u_i})$, which integrates to
$\gamma(y_i + b_i + 1, e^{a_i})$ by the same substitution used to derive
the PMF. The $z_i$ variables enter only through $b_i$.

Paragraph 5 — Testing. The null hypothesis of no inefficiency determinants
is $H_0: \delta = 0$, testable via a likelihood ratio test comparing the
scaled and homogeneous models. The homogeneous model is nested within the
scaling model. Under $H_0$ the test statistic is asymptotically $\chi^2$
with $\dim(\delta)$ degrees of freedom.

Paragraph 6 — Identification caveat. If the same variable appears in both
$x_i$ and $z_i$, identification of $\beta$ and $\delta$ relies on the
nonlinear way $b_i$ enters the PMF, which is a functional form restriction.
A cleaner design separates inputs ($x_i$: R&D, capital) from inefficiency
drivers ($z_i$: firm age, ownership type, industry indicators), so that
identification is driven by exclusion rather than functional form alone.

---

### POINT 4 — Extension of scaling to the Gamma model

**Where:** At the end of the Gamma generalisation section, as a short
paragraph.

**What to add:**

The scaling model extends immediately to the Gamma($\alpha$, $b$) case:
set $b_i = b \cdot \exp(-z_i'\delta)$ and $\alpha$ fixed, or allow
$\alpha$ to vary via a second scaling function. The closed-form PMF in
terms of the lower incomplete gamma (goods case) is preserved with $b$
replaced by $b_i$. For the bads case, the PMF remains well-defined for
all $b_i > 0$ (by the convergence argument in @sec-moments), but the
closed form in terms of the upper incomplete gamma is preserved only for
$\alpha = 1$; for general $\alpha$ numerical integration is required.
The scaling model therefore provides a partial resolution of the
Fé & Hofler moment problem in the bads case: since $b_i$ is firm-specific
and continuously distributed, the knife-edge condition $b_i = \alpha$
occurs with probability zero in the population, but the broader condition
$b_i > 1$ for score existence must still be checked post-estimation.

---

### POINT 5 — Update the conclusion

**Where:** Conclusion section.

**What to add (2–3 sentences):**

Note the three advances over Fé & Hofler (2013) that the paper delivers:
(i) closed-form PMFs for both economic goods and bads via the
lower/upper incomplete gamma duality; (ii) a full clarification of the
moment-existence question — the likelihood is always well-defined, but
inefficiency scores in the bads case require $b > 1$, which can be tested
post-estimation; and (iii) the scaling model for inefficiency determinants,
which preserves the closed form and yields an analytic efficiency score
formula, avoiding simulation.

---

### POINT 6 — Add or update references.bib

Ensure the following BibTeX entries exist. If any are missing, add them:

- Fé & Hofler (2013): Journal of Productivity Analysis, 39, 271–284
- Caudill, Ford & Gropper (1995) or Caudill & Ford (1993): the original
  scaling model paper (check which year is more appropriate given your
  existing citations)
- Wang & Schmidt (2002): "One-step and two-step estimation of the effects
  of exogenous variables on technical efficiency levels", Journal of
  Productivity Analysis, 18, 129–144

---

## FORMATTING REQUIREMENTS

- All new equations must have {#eq-labelname} labels
- Cross-reference all new equations in the prose using @eq-
- New subsection (Point 3) must have {#sec-scaling} label
- All citations in [@key] format
- No bullet lists in main prose — write in paragraphs
- Callout block for the key practical takeaway from Point 1:

  ::: {.callout-note}
  ## Practical implication
  The log-likelihood is well-defined for all $b > 0$ in both goods and
  bads cases. Researchers should check $\hat{b} > 1$ post-estimation
  before reporting bads-case inefficiency scores; if this fails, use
  simulation to approximate the posterior mean.
  :::

- After all edits, run `quarto check` and report any unresolved
  cross-references or missing citation keys.
