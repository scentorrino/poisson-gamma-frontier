# Theory Review: Poisson-Gamma Frontier Proofs (Appendix A)
**Date:** 2026-05-18
**Reviewer:** theorist-critic (dispatched via general-purpose)

## Phase 1: Claim Identification

### A.1 — Proof of @prp-pmf (marginal PMF)
- **Object type:** Closed-form marginal PMF; alternating series (production) and 1-D integral (cost).
- **Claim verbatim (production, 02-model.qmd:87-92):** "the marginal probability mass function of $Y_i$ takes... $\Pr(Y_i = y \mid \mathbf{x}_i,\, \alpha,\, b) = \frac{b^\alpha e^{a_i y}}{y!} \sum_{j=0}^{\infty} \frac{(-1)^j e^{j a_i}}{j! (y + b + j)^\alpha}$." Cost case at 02-model.qmd:101-106 gives an integral.
- **Stated assumptions:** $a_i < \infty$, $b > 0$, $\alpha > 0$, $y \in \mathbb{N}_0$, and $u_i \sim \mathrm{Gamma}(\alpha,b)$ (rate parameterisation).
- **Scope:** Single observation $i$; uniformity in $\mathbf{x}_i$ is implicit through $a_i < \infty$.

### A.2 — Proof of @prp-te (conditional efficiency score)
- **Object type:** Conditional expectation $\mathrm{E}[e^{-u_i}\mid Y_i = y_i,\,\mathbf{x}_i]$; series ratio (production), integral ratio (cost).
- **Claim verbatim (production, 02-model.qmd:330-337):** ratio of two alternating series differing only by shift $b\to b+1$ in the rate-like argument. Cost analogue at 02-model.qmd:341-348.
- **Stated assumptions:** Same as A.1; finiteness of both integrals "for all $b > 0$ and $\alpha > 0$" asserted at 02-model.qmd:350-352.
- **Scope:** Single observation; valid for any $y_i\geq 0$.

### A.3 — PMF/log-likelihood well-definedness for all $b>0$
- **Object type:** Regularity claim (finiteness of PMF and of log-likelihood; consistency and $\sqrt{n}$-normality of MLE).
- **Claim verbatim (08-appendix.qmd:110-118):** "The PMFs ... are well-defined for all $b > 0$ ... no restriction on $b$."
- **Stated assumptions:** $\alpha$ bounded away from 0; $b$ bounded away from 0 and $\infty$ (for the asymptotic statements).
- **Scope:** All units, all $b>0$.

### A.4 — Conditional moment existence
- **Object type:** Existence of conditional moments $\mathrm{E}[e^{r u_i}\mid y_i,\,\mathbf{x}_i]$.
- **Claim verbatim (03-gamma-generalization.qmd:137-140):** "finite whenever $r < b + y_i$ in the production case... and for *every* $r \in \mathbb{R}$ in the cost case, regardless of $b$."
- **Stated assumptions:** As above; uses posterior densities @eq-post-prod / @eq-post-cost.
- **Scope:** Conditional on $y_i$, $\mathbf{x}_i$; valid for all $b > 0$, $\alpha > 0$.

## Phase 2: Proof Validity
**Assessment:** GAPS (no critical errors; several missing justifications and minor imprecisions).

### A.1 Proof of @prp-pmf
#### Issues found: 3

##### Issue 2.A1.1: Dominating bound stated but the inequality step is implicit
- **Location:** 08-appendix.qmd:33-37
- **Severity:** MINOR
- **Problem:** The bound $\sum_j e^{ja_i}\Gamma(\alpha)/[j!(y+b+j)^\alpha] \leq \Gamma(\alpha) b^{-\alpha} e^{e^{a_i}}$ relies on $(y+b+j)^{-\alpha} \leq b^{-\alpha}$, which holds because $y\geq 0, j\geq 0$ and $\alpha>0$. The proof does not state this inequality, even in a parenthetical. A first-time reader may not see at a glance that the bound holds uniformly in $j$.
- **Suggested fix:** Insert a half-sentence: "since $(y+b+j)^{-\alpha} \leq b^{-\alpha}$ for $y,j\geq 0$ and $\alpha>0$".

##### Issue 2.A1.2: Divergence boundary stated as strict but is non-strict
- **Location:** 08-appendix.qmd:64-66
- **Severity:** MINOR
- **Problem:** The text reads "$\int_0^\infty u^{\alpha-1}e^{(y+j-b)u}\,du$ diverge for every $j > b - y$." This is correct for $j$ strictly greater than $b-y$. The divergence in fact occurs whenever $y+j-b \geq 0$, including the equality case (then $\int_0^\infty u^{\alpha-1}\,du$ diverges at $+\infty$ for any $\alpha > 0$). The point of the proof — that term-by-term integration fails — is unaffected, but the boundary statement is slightly imprecise.
- **Suggested fix:** Replace "$j > b - y$" with "$j \geq b - y$" (or "$y + j \geq b$").

##### Issue 2.A1.3: Integrability at $u\to 0^+$ in the cost integrand mentioned only in passing
- **Location:** 08-appendix.qmd:55-60
- **Severity:** MINOR
- **Problem:** The proof asserts integrability at $u=0^+$ via "the integrand behaves like $u^{\alpha-1}$, integrable for every $\alpha>0$" — correct. But note the prefactor $\exp(-e^{a_i+u})$ at $u=0$ equals $\exp(-e^{a_i})$, a finite positive constant; the proof never makes this explicit. Strictly the integrand is bounded above by $u^{\alpha-1}\cdot C$ for some constant $C = \exp(\max(0, (y-b)\cdot u_*))\cdot \sup_{u\in[0,u_*]}\exp(-e^{a_i+u})\cdot e^{-(y-b)\cdot 0}$ on a neighbourhood $[0,u_*]$ of zero, hence integrable. This is fine but worth a one-line justification.
- **Suggested fix:** Add: "since $\exp(-e^{a_i+u})$ is continuous and bounded on $[0, u_*]$ for any $u_* < \infty$".

### A.2 Proof of @prp-te
#### Issues found: 2

##### Issue 2.A2.1: Reuse of dominating bound is asserted, not verified
- **Location:** 08-appendix.qmd:82-85
- **Severity:** MINOR
- **Problem:** "The same Maclaurin expansion and term-by-term integration as in the proof of @prp-pmf — with $(y_i+b+j)$ replaced by $(y_i+b+1+j)$ — gives..." The reader is expected to verify that the dominating sum $\sum_j e^{ja_i}/[j!(y_i+b+1+j)^\alpha]$ remains uniformly bounded. It does — indeed by exactly the same $b^{-\alpha} e^{e^{a_i}}$ bound (since $(y_i+b+1+j)^\alpha \geq b^\alpha$ again). One sentence makes this airtight.
- **Suggested fix:** "...replaced by $(y_i+b+1+j)$; the dominating sum is again bounded by $\Gamma(\alpha) b^{-\alpha} e^{e^{a_i}}$, so Fubini applies."

##### Issue 2.A2.2: Cost numerator integrability bound asserted via "same argument"
- **Location:** 08-appendix.qmd:101-104
- **Severity:** MINOR
- **Problem:** The shift from $(y_i-b)u$ to $(y_i-b-1)u$ in the linear exponent is correct, and the claim that the double-exponential factor dominates "for any real coefficient on $u$" is true at $u\to\infty$. The proof again does not separately handle $u\to 0^+$ for the new integrand, but the behaviour at the origin is unchanged (still $\sim u^{\alpha-1}$), so this is fine pending Issue 2.A1.3.
- **Suggested fix:** Once 2.A1.3 is addressed, a single cross-reference suffices.

### A.3 PMF well-definedness
#### Issues found: 3

##### Issue 2.A3.1: Boundary behaviour of cost integrand at $u=0$ not separately argued in A.3
- **Location:** 08-appendix.qmd:110-118
- **Severity:** MAJOR
- **Problem:** A.3 invokes "super-exponential decay" dominating the polynomial factor $t^{y\pm b - 1}$ "regardless of the sign of $y\pm b - 1$." That tail dominance is correct at infinity. But well-definedness of $\int_0^\infty u^{\alpha-1}\exp((y-b)u-e^{a_i+u})\,du$ also requires integrability at $u=0^+$ — non-trivial only when $\alpha < 1$, where $u^{\alpha-1}$ has an integrable singularity. A.3 does not state this; it relies on the reader importing the boundary argument from A.1 (08-appendix.qmd:58-60). For a self-contained appendix section invoked from §3, a one-sentence statement is warranted.
- **Suggested fix:** Add: "Integrability at $u=0^+$ follows because the integrand is bounded by a constant multiple of $u^{\alpha-1}$ in a neighbourhood of zero, which is integrable for any $\alpha>0$."

##### Issue 2.A3.2: Super-exponential term decay asserted, not derived
- **Location:** 08-appendix.qmd:115-118
- **Severity:** MINOR
- **Problem:** "...the $j!$ in the denominator of the alternating series @eq-pmf-gamma produces super-exponential term decay for every finite $a_i$, ensuring absolute convergence with no restriction on $b$." The actual decay is governed by the ratio $|t_{j+1}|/|t_j| = e^{a_i}/(j+1)\cdot[(y+b+j)/(y+b+j+1)]^\alpha \to 0$, given explicitly in §2 at 02-model.qmd:118-123. A.3 asserts the conclusion but does not derive it — though §2 supplies the derivation, A.3 is the proof that should cite it.
- **Suggested fix:** Insert "by the ratio test bound at 02-model.qmd:118-123" or restate the ratio.

##### Issue 2.A3.3: Newey-McFadden citation form correct, but theorem numbers should be verified
- **Location:** 08-appendix.qmd:122-126
- **Severity:** MINOR
- **Problem:** Newey-McFadden (1994, Handbook of Econometrics ch. 36) — Theorem 2.5 in that chapter establishes consistency of extremum estimators under compactness, continuity, identifiability, and ULLN; Theorem 3.3 establishes $\sqrt{n}$-asymptotic normality under additional differentiability and Fisher-information-nonsingularity assumptions. The labels match the cited content. Confirmed correct.
- **Suggested fix:** None needed beyond noting in passing which conditions of Theorem 2.5 are non-trivial here (the ULLN, given that the log-likelihood involves an infinite series for the general-$\alpha$ case).

### A.4 Conditional moment existence
#### Issues found: 3

##### Issue 2.A4.1: Production case — only the "if" direction is proven
- **Location:** 08-appendix.qmd:142-148
- **Severity:** MINOR
- **Problem:** The proof shows that the posterior tail is bounded above by a Gamma-like density with rate $b+y_i$, which gives finiteness of $\mathrm{E}[e^{ru_i}\mid y_i]$ for $r < b+y_i$. The headline claim in §3 is "finite whenever $r < b+y_i$" (a sufficient condition), so the proof exactly supports the stated claim. However, the proof does NOT prove the converse (non-existence for $r \geq b+y_i$), which a casual reader might think is the strongest available statement. If the authors wish to claim sharpness (i.e., $r<b+y_i$ is also necessary), they would need a lower-bound argument: $\exp(-\lambda_i e^{-u})\to 1$ as $u\to\infty$, so eventually $\geq 1/2$, hence the integral over $[M,\infty)$ is bounded below by $(1/2)\int_M^\infty u^{\alpha-1}e^{(r-b-y_i)u}\,du$, which diverges if $r\geq b+y_i$.
- **Suggested fix:** Either leave the claim as stated (sufficiency only) or add the two-line lower-bound argument to obtain sharpness; if the sharpness claim is wanted explicitly, the text should say "finite if and only if".

##### Issue 2.A4.2: Cost case — $u\to 0^+$ boundary not addressed
- **Location:** 08-appendix.qmd:150-159
- **Severity:** MAJOR
- **Problem:** The proof argues only the right tail, asserting $\exp(-\lambda_i e^{u_i})$ "dominates any polynomial or exponential growth" at $u\to\infty$. Behaviour at $u=0^+$ is unaddressed. The integrand $u^{\alpha-1}\exp((y_i+r-b)u-\lambda_i e^u)$ behaves like $u^{\alpha-1}\cdot \exp(-\lambda_i)$ as $u\to 0^+$, integrable for any $\alpha>0$. The same gap as Issue 2.A3.1 — and the same one-line fix applies.
- **Suggested fix:** Add: "integrability at $u=0^+$ follows because the integrand is $\sim u^{\alpha-1}\exp(-\lambda_i)$ near zero, integrable for $\alpha>0$."

##### Issue 2.A4.3: Posterior normalising constant finiteness not formally noted
- **Location:** 08-appendix.qmd:140-159
- **Severity:** MINOR
- **Problem:** The conditional moment is written as a ratio of integrals (implicitly in the proof, explicitly in A.2 at 08-appendix.qmd:71-78). For the moment to be well-defined, the denominator (the marginal PMF) must be strictly positive — which is true: the alternating series sums to a strictly positive value (it is a probability), and the cost integrand is everywhere strictly positive. The proof of A.4 does not explicitly say this; a one-line remark would close the loop.
- **Suggested fix:** Add: "The denominator (marginal PMF) is strictly positive by Proposition @prp-pmf, so the conditional moment is well-defined as a ratio."

## Phase 3: Assumptions and Statements

- **Parameter restrictions:** All of $b > 0$, $\alpha > 0$, $y \in \mathbb{N}_0$, $a_i < \infty$ are stated at 02-model.qmd:94-95 (production) and implicitly in (ii) at 02-model.qmd:97-110 (cost). The single-observation scope is clear from the indexing.
- **Strength of conclusion:** Both propositions claim what the proofs deliver. The conditional-moment claim in §3 is "finite whenever $r < b+y_i$" — a sufficiency statement; the proof matches (see 2.A4.1). The cost-case "every $r\in\mathbb{R}$" is also a sufficiency statement supported by the proof.
- **Notation:** $a_i = \log\lambda_i$ is introduced at 02-model.qmd:20-23 with @eq-loglink and is used consistently throughout the appendix.
- **Cost-case prefactor reuse:** 02-model.qmd:101-106 writes $b^\alpha e^{a_i y}/(y!\Gamma(\alpha))$ outside the integral; inside, the integrand involves $\exp(-e^{a_i+u})$. The integrand notation in (ii) and the integrand in @eq-gamma-integral-cost differ stylistically (the (ii) statement absorbs $\lambda_i^y$ into $e^{a_i y}$ at the prefactor; the appendix derivation initially keeps $\lambda_i^y e^{yu}$ as a unit). This is consistent but mildly notation-shifting between the statement and its derivation. Not a defect.

## Phase 4: Citations, Linkage, Polish

- **@neweyMcFadden1994:** Bibliography entry exists at references.bib:167-178 with correct DOI (10.1016/S1573-4412(05)80005-4) and publication metadata. Citation form `@neweyMcFadden1994 [Theorems 2.5 and 3.3]` is standard Quarto.
- **Cross-references:** All of @eq-pmf-gamma, @eq-pmf-gamma-cost, @eq-te-gamma, @eq-te-gamma-cost, @eq-marginalization, @eq-maclaurin, @eq-gamma-integral-cost, @eq-post-prod, @eq-post-cost are defined exactly once and used in the right contexts. Confirmed via grep across .qmd files.
- **Forward references from §2/§3:** 02-model.qmd:113 references @sec-app-pmf-proof; 02-model.qmd:355 references @sec-app-te-proof; 03-gamma-generalization.qmd:103-104 references @sec-app-likelihood; 03-gamma-generalization.qmd:142-143 references @sec-app-condmoments. All resolve.
- **Polish:** Use of "for every finite $a_i$" (08-appendix.qmd:36, 117) is correct given $a_i = \mathbf{x}_i'\boldsymbol{\beta}$. The cost case "No closed-form series representation is available; direct numerical quadrature ... is therefore required" (08-appendix.qmd:65-66) is a strong statement — it would be more conservative to write "no convergent term-by-term series via this Maclaurin expansion is available", since an alternative expansion (e.g. integration by parts, asymptotic series, or expansion around a different point) is not ruled out by the divergence shown.

## Summary
- **Overall:** MINOR (with two MAJOR items both reducible to a single one-line fix about boundary integrability at $u=0^+$).
- **Critical issues:** 0
- **Major issues:** 2 (Issues 2.A3.1, 2.A4.2 — both about the $u=0^+$ boundary, same fix)
- **Minor issues:** 9

## Priority Recommendations
1. **[MAJOR]** Insert a single sentence in §A.3 (and a back-reference in §A.4) covering integrability of the cost-case integrand at $u=0^+$: the integrand behaves like $u^{\alpha-1}\exp(-\lambda_i)$ near zero, integrable for any $\alpha>0$. This closes the only non-trivial gap.
2. **[MINOR]** Tighten the divergence threshold in A.1 cost case from "$j > b-y$" to "$j \geq b-y$" (08-appendix.qmd:64-66).
3. **[MINOR]** Make explicit the dominating-bound step $(y+b+j)^{-\alpha}\leq b^{-\alpha}$ in A.1 (08-appendix.qmd:33-37) and re-cite it in A.2 (08-appendix.qmd:82-85).
4. **[MINOR]** In A.4 production case, either explicitly mark the claim as sufficiency only, or add the two-line lower-bound argument to obtain "if and only if" (08-appendix.qmd:142-148).
5. **[MINOR]** In A.3, replace "super-exponential term decay" assertion with a one-line cite of the ratio derived at 02-model.qmd:118-123, and note that the denominator of the conditional moment is positive by @prp-pmf (linkage to 2.A4.3).
6. **[MINOR]** Soften "No closed-form series representation is available" (08-appendix.qmd:65) to "No convergent term-by-term series via this Maclaurin expansion is available" — the current claim asserts non-existence of any series form, which the proof does not establish.

## Positive Findings
1. The alternating-series construction in A.1 is correctly justified by Fubini with a clean explicit dominating function $\Gamma(\alpha) b^{-\alpha} e^{e^{a_i}}$ that is uniformly finite for any finite $a_i$ — a non-trivial gain over Fé & Hofler's simulated-likelihood treatment.
2. The cost-case divergence argument (08-appendix.qmd:60-66) correctly identifies why the production-case alternating series has no cost-case analogue, by displaying which inner integrals diverge — a sharp negative result rather than mere appeal to "non-existence".
3. The A.4 cost-case observation that conditioning on $y_i$ strictly enlarges the moment-existence region (relative to the unconditional MGF requirement $b > 1$) is mathematically correct and is the right economic point to make for cost-frontier efficiency scoring; the proof, modulo Issue 2.A4.2 about the lower boundary, is sound.
