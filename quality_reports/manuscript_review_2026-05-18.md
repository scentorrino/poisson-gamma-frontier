# Manuscript Review — Poisson-Gamma Count Frontier
**Date:** 2026-05-18
**Reviewer:** writer-critic (dispatched via general-purpose; first session for this critic in this project)
**Paper type:** Theory + Empirics (methods)
**Mode:** Full (all 8 categories)

## Category 1 — Structure and Flow: COHERENT

The section ordering is canonical for a theory + empirics methods paper: §1 Introduction → §2 Model (propositions) → §3 Moments/Existence/Scaling → §4 Estimation → §5 Simulations → §6 Empirical → §7 Conclusion → §8 Appendix. The introduction previews both the theoretical results (closed-form PMF, conditional efficiency score, both orientations) and the empirical evidence (Hausman patent panel) — the explicit four-contributions list at `01-introduction.qmd:61-79` lands within the first ~2 pages and is appropriately granular. The roadmap paragraph at `01-introduction.qmd:86-97` cross-links every downstream section. Each main section opens with an explicit framing paragraph and closes with a forward-pointer; this is consistent and pleasant.

Issues, ranked:

- The transition from `02-model.qmd` to `03-gamma-generalization.qmd` repeats the existence/conditional-moment discussion at a level of detail that risks fatigue. §2 already foreshadows existence in the remark at lines 200-214; §3.1 reopens it; §3.2 reopens it again with the appendix backref. The "Three claims together determine..." opener at `03-gamma-generalization.qmd:20-30` is a meta-summary that announces what the next subsection will prove; consider trimming the meta-summary or the redundant re-statement at lines 95-146.
- The §4 conclusion paragraph that announces §5 (`04-estimation.qmd:426-428`) is a textbook "section announcement". Same pattern at the end of §3 (`03-gamma-generalization.qmd:249-253`) and §5 (`05-simulations.qmd:519-523`).
- `06-empirical.qmd:383-391` reads as a mid-section summary right before a major subsection (Inefficiency Determinants). It is a duplicate of the §6 conclusion paragraphs and should be cut or merged.

The "argument move per paragraph" rule is generally respected; long paragraphs (e.g. `01-introduction.qmd:61-79`) bundle four contributions into one paragraph, which is acceptable as a list but creates a wall of text.

## Category 2 — Claims and Evidence: SUPPORTED with minor GAPS

The major claims trace cleanly:

- The $\alpha\log(b/(b+1))$ and $\alpha\log(b/(b-1))$ intercept bias predictions are stated in §4 (`04-estimation.qmd:83-89`), verified in §5 numerically (production: `05-simulations.qmd:254-269`; cost: `05-simulations.qmd:1081-1093` via inline `r` expressions that pull observed bias from `cost_summ`), and then re-confirmed empirically in §6 (`06-empirical.qmd:231-241`). Magnitudes are stated with units (log-units, mean output ratio).
- The weak-identification finding for $\alpha$ is introduced in §3 (`03-gamma-generalization.qmd:107-111`), illustrated in §4 (Figure `fig-profile-lik`), and tied to coverage numbers in §5 (`05-simulations.qmd:411-421`). The chain is solid.
- Prior literature comparisons name specific authors and what they did: Fé & Hofler 2013 (half-normal, MSL), Greene 1990 (Gamma continuous, Laguerre quadrature), Greene 2003 (SML), Meeusen & van den Broeck 1977 (exponential).

Gaps:

- `01-introduction.qmd:72-79`: "Fourth, we apply the model to the @hausman1984 patent panel ... and show that the exponential frontier improves substantially over the baseline Poisson GLM, that capital intensity and science-sector membership are statistically significant determinants of inefficiency". The claim that determinants are *statistically significant* is hedged in §6 (`06-empirical.qmd:735-753`) — the `r round(delta1_se, ...)` injection means the actual significance is computed at render time. The intro states the conclusion as fact; ideally the intro language is more cautious, or §6 must produce significance unconditionally (e.g. via `fmt_s` stars). At present the intro is *committed* to a finding whose sign and magnitude are emitted inline by R.
- `01-introduction.qmd:24-27`: "@greene1990 reports that the half-normal and exponential restrictions can substantially distort the distribution of estimated firm inefficiencies" — no page number or magnitude. Compare against Greene 1990 fn/page would strengthen.
- `06-empirical.qmd:243-247`: "The estimated rate $\hat{b}$ from the exponential frontier implies an average inefficiency of $\mathrm{E}[u_i] = 1/\hat{b}$" — the *value* of $1/\hat b$ is not stated even though it is the headline of the empirical section. The text says "The average firm's expected output is $\exp(-1/\hat{b})$ times its frontier output" without giving the number. A reader should not have to compile to know what the mean efficiency in the data is. (The §6.2 intro at line 280 does report `r round(mean(...))`, but the §6.1 rate-parameter paragraph itself leaves the reader hanging.)
- `06-empirical.qmd:541-548`: "Moving from the Poisson GLM (M1) to the homogeneous exponential frontier (M3) raises the log-likelihood by `r round(ll_M3_sc - ll_M1_sc, 1)` log-units at the cost of one additional parameter, confirming that a one-sided inefficiency term is warranted by the data." This conclusion follows only if the gap is large; for n=1730 even a moderate ΔLL would be "warranted" by AIC. Better to commit to the test reported in `tbl-model-tests` (the AIC/BIC gap) than to assert "warranted" inline.

No orphan claims found in §2-§5. The proofs in §8 cover @prp-pmf, @prp-te, well-definedness, and conditional-moment existence — the proofs review of 2026-05-18 confirms these are tight; I do not re-litigate.

## Category 3 — Identification Fidelity: FAITHFUL

The paper is properly calibrated: it estimates a frontier model under a parametric likelihood and never claims a causal effect of any $\mathbf{x}_i$ on $Y_i$. Testable predictions are explicit and numbered:

- The intercept-attenuation prediction is stated as an asymptotic equality at `04-estimation.qmd:83-89` and `05-simulations.qmd:259-264` (`eq-pois-attenuation`), then directly verified in both simulations and empirics.
- Weak identification of $\alpha$ along $\alpha\to 0, b\to\infty$ at constant $\alpha/b$ is explicit (`04-estimation.qmd:124-130`, `03-gamma-generalization.qmd:107-111`); the §5 coverage table is the direct test.
- The boundary issue with M3-vs-M1 is correctly handled in §6 (`06-empirical.qmd:668-674`): the paper *avoids* the chi-squared LR for the boundary nesting and falls back to AIC/BIC, with @andrews2001 cited. This is technically careful and rare to get right.

The empirical section is faithfully labelled as "association" not "effect" throughout (`06-empirical.qmd:355-362`, "positive cross-sectional association between R&D intensity and estimated efficiency", "consistent with the view that..."). The remark at `06-empirical.qmd:249-254` correctly flags that the SEs do not account for within-firm clustering. The remark at `06-empirical.qmd:371-381` flags the pooled-cross-section limitation and defers the firm-FE extension to future work.

The paper is **patent-based throughout**; there is no leftover CWA / EPA language. The pivot mentioned in the review brief has not landed in the manuscript text — that is fine, but if the empirical pivot is intended, the abstract (`index.qmd:6`) and intro (`01-introduction.qmd:72-78`) are committed to patents and would need to flip.

One quibble: the introductory contribution list at `01-introduction.qmd:61-79` says the empirical application "show[s] that ... capital intensity and science-sector membership are statistically significant determinants of inefficiency". Significance depends on the fitted SEs, which are computed at render time and not committed. The intro should match what §6 *will* conclude (cf. Category 2).

## Category 4 — Writing Quality: AI PATTERNS FOUND (minor)

The prose is mostly tight and technical. A few patterns are present but the worst-offender vocabulary list is largely absent (no "delve", "tapestry", "interplay", "garner", "underscore", "landscape", "foster"). However:

**Content patterns:**
- *Significance inflation* — limited. The word "principled" appears once (`01-introduction.qmd:39`, "take the first steps toward a principled count-data frontier") — passable. The "fourfold" contribution framing in the intro is at the edge of promotional but the four are real. (-1)
- *Superficial -ing analyses* — moderate use. Examples:
    - `05-simulations.qmd:511`, "biases the intercept by a predictable log-mean-inefficiency factor while leaving slope coefficients intact — a pattern that alerts practitioners to..." — gerund as smoke.
    - `06-empirical.qmd:441-446`, "compressing the efficiency distribution" / "absorbing the sector- and capital-induced heterogeneity into the single rate parameter $b$" — the gerunds chain together at sentence ends. Mild. (-2)

**Language patterns:**
- *Copula avoidance* — minimal. The text uses "is" directly throughout. No deduction.
- *Negative parallelisms* ("not X but Y") — minimal; I count two instances ("not a computational device but the algebraic consequence" at `02-model.qmd:185`; "not an identification failure of the model but a near-boundary behaviour" at `04-estimation.qmd:151-152`). Both are technically apt. (-0)
- *Excessive hedging* — minimal. "may" and "perhaps" used sparingly.

**Style patterns:**
- *Em-dash overuse* — counts: §5 (`05-simulations.qmd`) 19 em-dashes over 1150 lines, §3 10/253, §4 16/428, §8 7/188, §6 7/870 (mostly low density). §3 density (≈4%) is on the high side but tolerable. (-2)
- *Rule of three* — present but acceptable: "patent counts, hospital discharges, or scientific publications" (`01-introduction.qmd:52`), "size, age, ownership, industry classification" (`03-gamma-generalization.qmd:164`). Not formulaic enough to flag heavily. (-0)
- *Uniform sentence length* — no, sentences vary from short clauses to nested 50-word constructions.

**Communication patterns:**
- *Filler phrases* — minimal. "It is important to note" does not appear; "It is worth mentioning" does not appear.
- *Section announcements* — present:
    - End of §3 (`03-gamma-generalization.qmd:249-253`): "With the PMF, efficiency score, moments, and scaling extension all in hand, @sec-estimation builds the log-likelihood and describes how numerical optimisation is conducted..."
    - End of §4 (`04-estimation.qmd:426-428`): "With the estimation framework established, @sec-simulations examines finite-sample performance..."
    - End of §5 (`05-simulations.qmd:519-523`): "With the finite-sample properties of the estimator established, @sec-empirical applies..."
    - End of §6 first-half (`06-empirical.qmd:387-391`): "...The scaling model extension in @sec-emp-scaling examines... @sec-conclusion collects the paper's contributions and outlines extensions..."
    Three or four section-bridging paragraphs is acceptable in a long paper, but four in a row using the same construction "With X established, §Y..." is formulaic. (-3)

**Concrete sentences to flag:**
- `01-introduction.qmd:23-24`: "...motivating the more flexible Gamma shape This literature was developed for continuously distributed outputs..." — **missing period** between "shape" and "This". Bug.
- `02-model.qmd:18`: "and $\lambda_i$ is a lower bound thatis inflated by inefficiency" — **typo**: "thatis" should be "that is".

Net Category 4 deductions: -8.

## Category 5 — Quarto and Format: COMPLIANT with one ISSUE

- `_quarto.yml` builds to PDF (`format: pdf`) with manuscript template, natbib citation method, `agsm` style. The `cache: true` execute option is set globally; heavy chunks are explicitly `cache: true`. Compliant.
- Bibliography is wired (`bibliography: references.bib`).
- Cross-references throughout use the Quarto `@fig-`, `@tbl-`, `@eq-`, `@sec-`, `@prp-`, `@cor-` idiom. Tables are built with `knitr::kable() + kableExtra` (verified in §5 and §6). Equation labels use `{#eq-xxx}` after `$$...$$`. Section labels use `{#sec-xxx}`.
- Code chunks use `#| label:`, `#| cache: true`, `#| fig-cap:`, `#| tbl-cap:` consistently.

**Issue (NOT COMPLIANT, single hot-spot):** `04-estimation.qmd:342-355` is a raw LaTeX `\begin{remark}...\end{remark}` environment that *also* contains raw `\ref{sec-simulations}` and `\ref{fig-profile-lik}` calls. This violates the Quarto convention used everywhere else in the project (the standard `::: {.remark title="..."} ::: ` block is used in 02, 04, and 06 elsewhere). The raw `\ref{}` calls will not resolve to Quarto-numbered references and will likely render as literal "??" in the PDF output. **This is a likely-fail item for the rendered PDF.** Fix: convert to a Quarto remark div, replace `\ref{sec-simulations}` with `@sec-simulations`, replace `\ref{fig-profile-lik}` with `@fig-profile-lik`.

The custom `remark.lua` filter is wired in `_quarto.yml` and presumably handles the `::: {.remark ...}` divs. The `\begin{remark}` block bypasses it.

## Category 6 — Compilation / Render-ability: WARNINGS

Cross-reference resolution (verified by greping defined labels against used `@`-references):

- **Orphan label defined but never referenced:** `sec-pmf-exp` (`02-model.qmd:129`), `sec-te-exp` (`02-model.qmd:366`), `sec-emp-data` (`06-empirical.qmd:67`), `sec-emp-efficiency` (`06-empirical.qmd:268`), `sec-introduction` (`01-introduction.qmd:1`), `sec-moments` (`03-gamma-generalization.qmd:18`), `eq-gamma-moments`, `eq-loglink`, `eq-moments-cost`, `eq-moments-gamma`, `eq-post-kernel`, `eq-scaling-rate`, `eq-starting-b`, `eq-te-def`, `eq-te-emp`, `eq-reparam`, `eq-loglik`, `eq-dgp-scaling`, `eq-dgp-cost`. These labels are defined but never cross-referenced. Not blocking compilation, but indicates labels that could be removed for tidiness or are placeholders for future references.
- **Cross-reference to undefined label:** `@sec-emp-results` at `06-empirical.qmd:395` references a section that is defined as `{#sec-emp-results}` at `06-empirical.qmd:135` — resolves. Verified all the `@fig-` and `@tbl-` references resolve to chunk labels (the chunk labels list matches every used `@fig-`/`@tbl-` reference).
- **Raw `\ref{}` calls** at `04-estimation.qmd:347` and `04-estimation.qmd:353` will not resolve through Quarto's cross-ref machinery and will render as missing references in PDF. Together with the `\begin{remark}...\end{remark}` environment that contains them, this is the single most likely *render warning or fail*.
- **Citations:** Every `[@key]` and `@key` (citation) verified against `references.bib`. Match: all 25 citation keys used in the .qmd files resolve to entries in references.bib (`aigner1977`, `andrews2001`, `batteseCoelli1995`, `cameronTrivedi2005`, `caudillFord1993`, `countSFApkg`, `drivasEconomidouTsionas2019`, `fe2019`, `feHofler2013`, `feHofler2020`, `greene1980`, `greene1990`, `greene2003`, `griliches1990`, `hadri1999`, `hallGrilichesHausman1986`, `haschkaHerwartz2022`, `hausman1984`, `hoflerScrogin2008`, `JLMS:1982`, `kumbhakarLovell2000`, `meeusenBroeck1977`, `mutzBornmannDaniel2017`, `neweyMcFadden1994`, `pakesGriliches1980`, `vuong1989`, `wangSchmidt2002`). No orphan bibkeys.
- **Chunk labels:** unique across the project (verified).
- **Div blocks:** the `::: {#prp-pmf}` through `:::` blocks are balanced in §2; `::: {#cor-pmf-exp}`, `::: {#cor-te-exp}`, `:::{#fig-eff-hist}` (note: no space after `:::` — Quarto tolerates this) are all closed. No obvious unclosed fences.

The proofs review of 2026-05-18 reports the math itself is sound — I do not re-audit.

## Category 7 — Voice Fidelity: NOT SCORED

No `personal-style-guide.md` is present in the project (`.claude/` contains skills only). Voice fidelity is not scored per the review protocol.

## Category 8 — Notation Consistency: CONSISTENT with minor DRIFT

Verified across §2–§6:

- $u_i$ — inefficiency, used consistently as scalar nonneg. Universally.
- $(\alpha, b)$ — Gamma shape and rate, consistent with rate parameterisation $f(u) = b^\alpha u^{\alpha-1}e^{-bu}/\Gamma(\alpha)$. Mean is $\alpha/b$. Consistent.
- $a_i = \log\lambda_i = \mathbf{x}_i'\boldsymbol{\beta}$ — log-frontier mean, defined at `02-model.qmd:21` and used uniformly.
- $\boldsymbol{\beta}$ — frontier coefficient vector. The slope on $z$ is $\beta_2$ in §5 simulation DGP (cf. `eq-dgp` line 113).
- $\delta$ — **clash**: used both as the year dummy coefficient in `06-empirical.qmd:95` (`\sum_{t=2}^{5}\delta_t d_t`) AND as the scaling parameter vector (`eq-scaling-bi`, `03-gamma-generalization.qmd:175`). The footnote at `06-empirical.qmd:101-103` flags the clash and reassigns the year-dummy $\delta_t$ as part of $\boldsymbol{\beta}$ explicitly. This is acceptable disambiguation but a tighter notation would have used $\gamma_t$ or $\tau_t$ for year dummies to avoid the clash entirely. Minor drift, acknowledged.
- Subscript convention: $i$ for cross-sectional unit, $t$ for year, $(i,t)$ in §6. Consistent.
- $\widehat{\mathrm{TE}}_i$ for conditional efficiency score — used uniformly in §2, §5, §6.
- $\boldsymbol{\theta} = (\boldsymbol{\beta}', b, \alpha)$ vs $\boldsymbol{\vartheta} = (\boldsymbol{\beta}', \log b, \log\alpha)$ — the natural-scale vs log-scale distinction is maintained throughout §4.
- Production vs cost orientation: production = "$-u_i$" / upper sign, cost = "$+u_i$" / lower sign. Used consistently from `eq-conditional` (`02-model.qmd:13`) onward. The "upper sign / lower sign" convention combined with the $\mp$ symbol is unambiguous.
- $\lambda_i$ vs $a_i$: $\lambda_i = \exp(a_i) = \exp(\mathbf{x}_i'\boldsymbol{\beta})$ — used consistently. Some passages drop $\lambda_i$ for $e^{a_i}$ (e.g. inside the closed-form formulas) and rely on the reader to translate. Acceptable.
- $K$ (truncation budget for the series) vs $K$ (capital stock in §6 frontier specification) — same symbol used for different objects. In §6 the variable is clearly "log capital stock $\log K_{it}$" with subscripts so the ambiguity is mild; the series truncation $K$ appears only in §2 and §4. No real conflict; minor drift.

Conclusion: notation is tight overall; the one design choice that risks reader confusion is the dual use of $\delta$ (year dummies and scaling vector), which the paper handles with a footnote.

## Score Breakdown
- Starting: 100
- Cat 1 (Structure): -1 (repeated section announcements, mid-section summary in §6)
- Cat 2 (Claims): -3 (intro overcommits to determinant significance; missing headline number for mean efficiency in §6.1; "warranted" claim from ΔLL without test)
- Cat 3 (Identification): -0 (well-calibrated)
- Cat 4 (Writing): -8 (1 typo with missing period at `01-introduction.qmd:24`; 1 typo "thatis" at `02-model.qmd:18`; 4 formulaic section-bridge announcements; minor -ing patterns and em-dash density in §3)
- Cat 5 (Quarto/Format): -6 (raw `\begin{remark}...\end{remark}` + raw `\ref{}` in §4 is a render bug, not just style)
- Cat 6 (Compilation): -4 (raw `\ref{}` likely produce missing-reference warnings in PDF; many orphan defined labels not used, suggests dead reference scaffolding)
- Cat 7 (Voice): 0 (not scored)
- Cat 8 (Notation): -2 ($\delta$ dual use, handled but suboptimal)
- **Final: 76/100**

## Priority Recommendations

1. **[CRITICAL]** Fix `04-estimation.qmd:342-355`. Replace the raw LaTeX `\begin{remark}[Weak identification of $\alpha$]...\end{remark}` environment with a Quarto remark div (`::: {.remark title="Weak identification of $\\alpha$"} ... :::`), and replace `\ref{sec-simulations}` and `\ref{fig-profile-lik}` with `@sec-simulations` and `@fig-profile-lik`. This is the most likely cause of render failure or visible "??" cross-references in the PDF.

2. **[CRITICAL]** Fix the typo at `01-introduction.qmd:23-24`: "motivating the more flexible Gamma shape This literature" — missing period. Should read "motivating the more flexible Gamma shape. This literature".

3. **[MAJOR]** Fix typo at `02-model.qmd:18`: "lower bound thatis inflated" → "that is inflated".

4. **[MAJOR]** Address the intro/empirics commitment mismatch. The intro at `01-introduction.qmd:73-78` asserts that capital intensity and science-sector membership are "statistically significant determinants of inefficiency". Either soften the intro language to "potentially significant" / "we examine X and Y as determinants" (deferring the conclusion to §6), or make the §6 reporting unconditional on render-time SE computations. The current arrangement risks publishing an intro that contradicts a marginal $p$-value flip in §6.

5. **[MAJOR]** Report the headline mean inefficiency / mean efficiency number explicitly in `06-empirical.qmd:243-247`, the §6.1 paragraph that mentions $1/\hat b$. Currently the §6.1 reader sees a formula but no number; the number is buried in §6.2 (line 280).

6. **[MAJOR]** Remove or actually-use orphan labels (`sec-pmf-exp`, `sec-te-exp`, `sec-emp-data`, `sec-emp-efficiency`, `eq-gamma-moments`, `eq-moments-cost`, `eq-moments-gamma`, `eq-post-kernel`, `eq-scaling-rate`, `eq-starting-b`, `eq-te-def`, `eq-te-emp`, `eq-reparam`, `eq-loglik`, `eq-dgp-cost`, `eq-dgp-scaling`). If they are scaffolding for future cross-refs, leave them; if they are dead, removing them tidies the source.

7. **[MAJOR]** Reduce the four formulaic "With X established, @sec-Y..." bridge paragraphs at the end of §3, §4, §5, §6. Pick a different transitional construction for at least two of them.

8. **[MINOR]** The empirical section's defence of `t-stat` and `LR_4 = 0.00` at `06-empirical.qmd:721-734` is technically tight but uses "the data provide no evidence against the exponential restriction" — fine — followed by "consistent with the weak-identification phenomenon documented in @sec-simulations". The reader may worry that a null-power problem masquerades as a real null; consider adding one clarifying sentence on what *would* have been needed to reject (e.g. a different $\lambda/b$ regime or a longer panel).

9. **[MINOR]** Consider renaming the year-dummy coefficients in `eq-frontier-spec` from $\delta_t$ to $\tau_t$ or $\gamma_t$ to eliminate the dual use of $\delta$ that the footnote at `06-empirical.qmd:101-103` is forced to explain.

10. **[MINOR]** §3's "Three claims together determine..." opener (`03-gamma-generalization.qmd:20-30`) reads as a meta-summary preview of three subsections that follow. Either delete the preview or fold the three claims into the subsection headings.

## Positive Findings

- The boundary-test discussion in `04-estimation.qmd:377-380` and the model-comparison framework in `06-empirical.qmd:650-674` are *unusually careful*. The paper distinguishes (i) nested LR where the restriction is interior, (ii) Vuong for genuinely non-nested comparisons, and (iii) AIC/BIC gaps for boundary nesting where Andrews 2001 invalidates standard inference. This is methodologically more rigorous than the typical applied frontier paper and the writing makes the distinctions explicit.
- The intercept-attenuation prediction $\alpha\log(b/(b\pm1))$ is *derived* in §4, *verified* in §5 via inline `r` expressions that compute observed bias against predicted bias (both production and cost orientations), and *recovered* in §6 against textbook Hausman patent numbers. The theory-simulation-data triangulation is tight and traceable.
- The dual-orientation treatment (production + cost) is genuinely symmetric in the propositions, corollaries, simulations, and the "structurally symmetric" remarks. The paper does not just bolt the cost orientation on as an afterthought; it derives both PMFs, both efficiency scores, both quadrature routes, and validates both via Monte Carlo. Few count-data frontier papers do this.
