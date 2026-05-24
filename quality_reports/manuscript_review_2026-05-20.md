# Manuscript Review — Poisson-Gamma Count Frontier (2026-05-20)
**Date:** 2026-05-20
**Reviewer:** writer-critic (dispatched via general-purpose; second session)
**Paper type:** Theory + Empirics (methods)
**Mode:** Full (all 8 categories)

## Delta from 2026-05-18 review

The raw LaTeX `\begin{remark}...\end{remark}` block flagged at the old `04-estimation.qmd:342-355` has been converted to a Quarto `::: {.remark title="Weak identification of $\alpha$"}` div at the new `04-estimation.qmd:315-328`; the embedded `\ref{}` calls are now `@sec-simulations` and `@fig-profile-lik`. The two typos at `01-introduction.qmd:24` ("shape This") and `02-model.qmd:18` ("thatis") are fixed. The two consolidations of the propositions figures are in place: `fig-pmf-shape` (02-model.qmd:232) now carries both the rate-sweep and the shape-sweep panels via `patchwork`; `fig-te-shape` (02-model.qmd:413) does the analogous consolidation for the efficiency score. The profile-likelihood figure (`fig-profile-lik` at `04-estimation.qmd:157`) is the new n-grid version. The appendix `08-appendix.qmd` has been added with four numbered subsections containing the lifted proofs. No CWA/EPA application language has appeared; the patent application remains throughout, including the abstract. New issues introduced since May 18 are flagged below.

## Category 1 — Structure and Flow: COHERENT

Section ordering is canonical: §1 → §2 (Propositions + Corollaries, both orientations) → §3 (Moments, existence, scaling) → §4 (Estimation, profile-lik) → §5 (Homogeneous MC + scaling MC + cost-frontier MC) → §6 (Empirical, homogeneous + scaling) → §7 (Conclusion) → §8 (Appendix with four lifted-proof subsections). The four-contribution roll-up at `01-introduction.qmd:61-78` and the downstream roadmap at `01-introduction.qmd:86-97` both still land within the first ~2 pages.

Lingering issues:

- The four formulaic "With X established, @sec-Y …" bridge paragraphs flagged on May 18 are still in place: `03-gamma-generalization.qmd:249`, `04-estimation.qmd:400`, `05-simulations.qmd:519`, and `06-empirical.qmd:387`. Pattern unchanged.
- §5 now opens at line 1 and runs to 1149 lines, with three Monte Carlo experiments (homogeneous, scaling, cost) stacked in one section. Each has its own "Experimental Design / Bias / Coverage / Summary" pattern, so by the third pass the reader sees the same four subheadings for the third time. Consider promoting the scaling and cost-validation subsections to their own top-level sections, or signposting the structure more clearly at the section opening.
- §6 has a `Inefficiency Determinants {#sec-emp-scaling}` subsection that begins at line 393, immediately after a forward-pointer paragraph at `06-empirical.qmd:383-391` that already announces the scaling model — the mid-section forward-pointer reads as a duplicate of the §6.2 closer and could be cut.
- The §3 meta-summary opener at `03-gamma-generalization.qmd:18-30` ("Three claims together determine...") still announces what the next three subsections will prove, then the next three subsections prove them.

The "argument move per paragraph" rule is generally respected, with the recurrent exception of the contribution paragraph at `01-introduction.qmd:61-78`, which bundles four contributions into one paragraph.

## Category 2 — Claims and Evidence: SUPPORTED with GAPS

The major theoretical claims trace cleanly through the propositions, the corollaries, and the appendix; the simulation predictions for the intercept-attenuation factors $\alpha\log(b/(b\pm 1))$ are computed inline against the realised bias.

Gaps and stale claims:

- **Abstract over-claims relative to §6.** `index.qmd:6`: "An empirical application to patent counts illustrates that the model recovers firm-level technical efficiency scores that are *robust to the shape of the inefficiency distribution*." But `06-empirical.qmd:139-146` reports that "The Gamma frontier was attempted but did not achieve numerical convergence on this dataset", and `06-empirical.qmd:256-266` (the new "Gamma frontier convergence" remark) confirms the same. The headline robustness check the abstract advertises — comparing exponential and Gamma fits on the empirical data — does not actually occur in the manuscript. The scaling-model LR$_4$ at `06-empirical.qmd:721-733` is an indirect check via the boundary $\hat\alpha = 1.000$ in M6, but the abstract phrasing promises a direct shape-invariance comparison that the data cannot deliver. **This is a Cat 2 fact-vs-evidence mismatch and the most prominent stale claim in the manuscript.**
- **Intro overcommits to determinant significance.** `01-introduction.qmd:74-78` still asserts "capital intensity and science-sector membership are statistically significant determinants of inefficiency". The §6 reporting at `06-empirical.qmd:735-753` injects the sign and magnitude of $\hat\delta_1, \hat\delta_2$ at render time with `r round(...)` and uses conditional language ("`r if (delta1_hat < 0) "is negative, consistent with..." else "is positive, at odds with..."`"). The intro is committed to a finding whose significance is computed at compile time. **Carry-over from May 18.**
- **Headline mean-efficiency number still missing in §6.1.** `06-empirical.qmd:243-247` still talks about $\mathrm{E}[u_i] = 1/\hat b$ and "the average firm's expected output is $\exp(-1/\hat{b})$ times its frontier output" without committing the number $1/\hat b$ itself. The number does appear later at `06-empirical.qmd:280-284` (the §6.2 opener), but the §6.1 paragraph that introduces $\hat b$ as the headline rate parameter leaves the reader without a quantitative anchor. **Carry-over from May 18.**
- **"Warranted" without a test.** `06-empirical.qmd:541-548` still says "raises the log-likelihood by `r round(ll_M3_sc - ll_M1_sc, 1)` log-units at the cost of one additional parameter, confirming that a one-sided inefficiency term is warranted by the data." For n = 1730 a modest $\Delta\ell$ is "warranted" by AIC; better to commit to the AIC/BIC gap reported in `tbl-model-tests` (and to flag that the boundary nesting precludes a formal LR test, which the paper later acknowledges at `06-empirical.qmd:668-674`). **Carry-over from May 18.**
- **External-check footnote claim at `06-empirical.qmd:237`.** "Refitting the pooled Poisson GLM with the current value and four lags of $\log R$ recovers a sum-of-elasticities of $0.486$, which exactly matches the corresponding entry in @cameronTrivedi2005, Table 23.1." The $0.486$ number is hard-coded in prose; the corresponding chunk that would compute it from the data is not visible in `06-empirical.qmd`. If `code/empirical/application.R` does not compute and re-validate this number against `cameronTrivedi2005` Table 23.1, the claim is an orphan and should at minimum carry a page/cell pointer. The phrasing "exactly matches" is also strong: a Poisson GLM fit will return a slightly different number unless restricted to exactly the same Hausman–Hall–Griliches sample.

No orphan figure/table references found (the prior review's chunk-label resolutions still hold; see Cat 6).

## Category 3 — Identification Fidelity: FAITHFUL

The paper does not claim causality. The intercept-attenuation prediction is an asymptotic equality, derived in §4 (`04-estimation.qmd:68-75`), tested in §5 (`05-simulations.qmd:254-269`, `tbl-cost-bias` and surrounding text), and re-verified in §6 (`06-empirical.qmd:231-241`). The weak-identification statement for $\alpha$ is named explicitly across §3 (`03-gamma-generalization.qmd:107-111`), §4 (the `::: {.remark}` div at `04-estimation.qmd:315-328`), §5 (`05-simulations.qmd:411-421`), and §6 (`06-empirical.qmd:721-733`).

The boundary-nesting argument in §6 for the M3-vs-M1 comparison is unusually careful: at `06-empirical.qmd:668-674` the paper refuses to apply the chi-squared LR or Vuong's normal limit and falls back to AIC/BIC gaps, citing @andrews2001. This is correct and rare in applied frontier work. The Vuong test V$_{32}$ at `06-empirical.qmd:660-667` is used only for the genuinely non-nested PHN-vs-Exp comparison, which is appropriate.

The empirical section uses associational language ("positive cross-sectional association", "consistent with the view that ...") throughout — no over-interpretation.

The patent application is fully labelled and the limitation remarks at `06-empirical.qmd:249-254` (cluster-robust SEs deferred) and `06-empirical.qmd:371-381` (pooled cross-section vs panel) are clean. No leftover CWA or EPA application language; if the empirical pivot is meant to happen, the abstract (and the contribution list at `01-introduction.qmd:74-78`) will need a full rewrite.

## Category 4 — Writing Quality: AI PATTERNS FOUND (minor)

The worst-offender vocabulary list ("delve", "tapestry", "intricate", "garner", "underscore", "foster", "navigate") is largely absent. "Navigate" appears once at `04-estimation.qmd:105` in a technical sense.

New issues:

- **Sentence fragment (bug).** `01-introduction.qmd:41`: "...inherits a symmetric bell shape from the underlying continuous draw. **Features better motivated by the continuous literature rather than by count-data applications.** The Fé–Hofler framework also lacks..." The bolded sentence has no verb — it is a noun phrase fragment. (Cat 4: copy-edit bug.)
- **Missing word (bug).** `index.qmd:6` (abstract): "The exponential special admits a closed-form likelihood function..." should read "The exponential special **case** admits..." (the word "case" is missing). (Cat 4: copy-edit bug.)
- **Subject-verb disagreement.** `03-gamma-generalization.qmd:89`: "The first of these conditions is the one [@feHofler2013, fn. 7] **flag** for the half-normal cost frontier." Singular subject `[@feHofler2013, fn. 7]` ⇒ "flags". Alternatively, the citation should be parsed as plural (Fé and Hofler) but the in-text parenthetical resolves to a single citation token. (Cat 4: copy-edit bug.)
- **Promotional adjective.** `04-estimation.qmd:65`: "Starting values are *essential* because..." — would read fine with "important" or just an active sentence. Mild. (-1)
- **Negative parallelisms.** Counts the same two instances flagged in May 18 (`02-model.qmd:185`, `04-estimation.qmd:128-130`); both technically apt. (-0)
- **Em-dash overuse.** New count: §5 has 22 em-dashes across 1149 lines (slight uptick because the scaling and cost MC sections added density); §3 11/253, §4 9/428, §2 7/491, §6 7/870. §5 is the densest at ≈2%, but the dashes are mostly used for genuine parenthetical material, not stylistic flourish. (-2)
- **Section announcements.** The four "With X established, @sec-Y..." bridges identified May 18 are still in place: `03-gamma-generalization.qmd:249`, `04-estimation.qmd:400`, `05-simulations.qmd:519`, `06-empirical.qmd:387`. Pattern unchanged. (-3)
- **Superficial -ing gerund chains.** `06-empirical.qmd:858-868` ends paragraphs with chained gerunds ("compressing the efficiency distribution... absorbing the sector- and capital-induced heterogeneity into the single rate parameter $b$... masking the complementarity..."). Acceptable but dense. (-2)
- **New "remarkably" / similar inflated adverbs.** `06-empirical.qmd:541-548` "confirming that a one-sided inefficiency term is warranted by the data" (already flagged Cat 2 too); `05-simulations.qmd:411-414` "exhibits chronic delta-method under-coverage in the $\alpha_0 = 1$ panel of @fig-sim-coverage — typically 70–80% for $\beta_1$ and $b$ — that does not attenuate with sample size" — "chronic" is mildly evaluative and would be cleaner as "persistent". (-1)

**Concrete sentences to flag:**
- `index.qmd:6`: "The exponential special admits a closed-form likelihood function" — missing "case".
- `01-introduction.qmd:41`: "Features better motivated by the continuous literature rather than by count-data applications." — sentence fragment.
- `03-gamma-generalization.qmd:89`: "the one [@feHofler2013, fn. 7] flag for" — subject-verb agreement.
- `05-simulations.qmd:628`: "In Scenario 0 the LR test @eq-loglik-scaling should achieve size close to..." — cross-reference points to the log-likelihood equation, not the LR test statistic (see Cat 6).

Net Category 4 deductions: -9.

## Category 5 — Quarto and Format: COMPLIANT

- The May 18 critical render-fail item (raw `\begin{remark}` + `\ref{}` in §4) is fixed. Verified: `grep '\\begin{remark}' *.qmd` and `grep '\\ref{' *.qmd` both return no matches.
- `_quarto.yml` builds PDF + HTML, `cache: true` globally, natbib + agsm, `remark.lua` filter wired. Compliant.
- Cross-references throughout use `@fig-`, `@tbl-`, `@eq-`, `@sec-`, `@prp-`, `@cor-`. Tables built with `knitr::kable() + kableExtra`. Equation labels `{#eq-xxx}` placed after `$$...$$`. Section labels `{#sec-xxx}`.
- The `::: {.remark title="..."} ::: ` div pattern is now used consistently across §2, §3, §4, and §6. The Quarto idiom is honoured.
- Code chunks consistently use `#| label:`, `#| cache: true`, `#| fig-cap:`, `#| tbl-cap:`. Heavy chunks (`mc-run`, `scaling-run`, `cost-run`, `emp-mle-fit`) all carry `#| cache: true`.

Minor issues:

- `06-empirical.qmd:286-303` uses the form `:::{#fig-eff-hist}` (figure declared via fenced div around an unlabelled code chunk plus a trailing caption sentence). This is a valid Quarto idiom for chunks where the caption needs to use `r` interpolation (the caption variable `cap_eff_hist` is constructed in the load chunk at lines 55-59 because YAML `!expr` is fragile), but the resulting figure label `#fig-eff-hist` is the *only* one defined this way; every other figure uses `#| label: fig-xxx`. Stylistic inconsistency, not a bug.
- The footnote at `06-empirical.qmd:101-103` is now using the standard Markdown footnote syntax inside a chunk caption-style line; this should render correctly under Quarto, but consider verifying after the next render.

## Category 6 — Compilation / Render-ability: LIKELY PASS, MINOR WARNINGS

Cross-reference resolution (verified by extracting all `{#xxx}` labels and `@xxx` references):

- **Orphan labels (defined but never referenced):**
  - `sec-introduction`, `sec-moments`, `sec-emp-data`, `sec-emp-efficiency`, `sec-pmf-exp`, `sec-te-exp`, `sec-sim-cost` — section anchors that may be scaffolding for future cross-references.
  - `eq-loglink`, `eq-gamma-moments`, `eq-moments-gamma`, `eq-reparam`, `eq-loglik`, `eq-scaling-rate`, `eq-dgp-scaling`, `eq-dgp-cost`, `eq-te-def`, `eq-te-emp`, `eq-post-kernel` — equation labels defined but unreferenced. Largely a carry-over from May 18.
- **Broken cross-references:** `@eq-loglik-scaling` is used twice — at `05-simulations.qmd:616` referring to the *log-likelihood* of the scaling model (correct) and at `05-simulations.qmd:628` introducing the *LR test* ("In Scenario 0 the LR test @eq-loglik-scaling should achieve size close to the nominal 5% level"). The second use points to the wrong equation: there is no LR-test equation defined for the scaling model, and the `@eq-loglik-scaling` label resolves to the log-likelihood expression at `03-gamma-generalization.qmd:201-206`. The sentence at 05-sim:628 reads as if the LR test were itself defined by that equation, which is a real cross-reference bug. (Either renumber, or add a labelled LR-test equation in §3.3 / §5.5 to point to.)
- **Citations:** All keys in `[@xxx]` resolve to entries in `references.bib`. The set used (`aigner1977`, `andrews2001`, `batteseCoelli1995`, `cameronTrivedi2005`, `caudillFord1993`, `countSFApkg`, `drivasEconomidouTsionas2019`, `fe2019`, `feHofler2013`, `feHofler2020`, `greene1980`, `greene1990`, `greene2003`, `griliches1990`, `hadri1999`, `hallGrilichesHausman1986`, `haschkaHerwartz2022`, `hausman1984`, `hoflerScrogin2008`, `JLMS:1982`, `kumbhakarLovell2000`, `meeusenBroeck1977`, `mutzBornmannDaniel2017`, `neweyMcFadden1994`, `pakesGriliches1980`, `vuong1989`, `wangSchmidt2002`) appears in references.bib. No orphan bibkeys.
- **Chunk labels:** unique across the project; no clashes detected.
- **Div blocks:** `::: {#prp-pmf}`, `::: {#prp-te}`, `::: {#cor-pmf-exp}`, `::: {#cor-te-exp}`, and the various `::: {.remark title="..."}` blocks are all balanced. The `:::{#fig-eff-hist}` div in §6 is balanced.
- **Figure consolidations from May 18 verified:** `fig-pmf-shape` and `fig-te-shape` each render a `patchwork` composite. The old labels `fig-gamma-pmf` and `fig-gamma-te` are absent (grep returns no matches).

The headline render risks are the `@eq-loglik-scaling` mis-reference in §5 and possible "??" outputs from the unused-but-defined labels (harmless, but noisy).

## Category 7 — Voice Fidelity: NOT SCORED

No `personal-style-guide.md` is present in the project. Voice fidelity is not scored per the review protocol.

## Category 8 — Notation Consistency: CONSISTENT with minor DRIFT

Verified across §1–§8:

- $u_i$ — inefficiency, scalar non-negative, used universally.
- $(\alpha, b)$ — Gamma shape and rate; $f(u) = b^\alpha u^{\alpha-1} e^{-bu}/\Gamma(\alpha)$. Consistent.
- $a_i = \log\lambda_i = \mathbf{x}_i'\boldsymbol{\beta}$ — defined at `02-model.qmd:21-23` and used uniformly thereafter.
- $\boldsymbol{\beta}$ — frontier coefficients; subscript convention $\beta_1$ (intercept), $\beta_2$ (slope on $z$). Consistent with §5 DGP.
- $\delta$ — **dual use, still present.** Used as the year-dummy coefficient at `06-empirical.qmd:95` (`\sum_{t=2}^5 \delta_t d_t`) *and* as the scaling parameter vector throughout §3.3 (`eq-scaling-bi`) and §5 (`eq-dgp-scaling`). The footnote at `06-empirical.qmd:101-103` flags and reassigns the year-dummy $\delta_t$ as part of $\boldsymbol{\beta}$, which is a valid disambiguation but reads as a workaround. The simulation tables at `tbl-delta-rmse` and the empirical $\hat\delta_1, \hat\delta_2$ at `tbl-model-comparison` correctly use $\delta$ as the scaling vector. Carry-over from May 18; recommend renaming the year-dummy coefficients to $\gamma_t$ or $\tau_t$.
- $\boldsymbol{\theta}$ vs $\boldsymbol{\vartheta}$ — natural-scale vs log-scale parameter vectors. Distinction maintained throughout §4.
- Production vs cost orientation: production = upper sign ($-u_i$), cost = lower sign ($+u_i$). Used consistently from `eq-conditional` (`02-model.qmd:13-17`) onward, including in `prp-pmf`, `prp-te`, `cor-pmf-exp`, `cor-te-exp`, and the simulation DGPs.
- $\widehat{\mathrm{TE}}_i$ — conditional efficiency score, used uniformly in §2, §3, §5, §6.
- $K$ — series truncation budget (§2, §4); also log-capital stock $\log K_{it}$ in §6 (with subscripts). Mild ambiguity but no real clash.
- $z_i$ — scaling-model determinants in §3.3, §5.5, §6.3; consistent.
- $\hat b$ vs $\hat b_i$ — homogeneous vs scaling rate; the subscript pattern is honoured throughout §3.3 onward.

The dual use of $\delta$ remains the one design choice that creates reader friction, and the year-dummy footnote is still required to disambiguate it.

## Score Breakdown
- Starting: 100
- Cat 1 (Structure): -1 (four "With X established" formulaic bridges still present, mid-section forward-pointer at `06-empirical.qmd:387-391` duplicates §6 closer)
- Cat 2 (Claims): -5 (abstract over-claims shape-invariance robustness that §6 cannot deliver due to Gamma non-convergence; intro overcommits to determinant significance; headline mean-efficiency number missing in §6.1; "warranted" claim from $\Delta\ell$ without committing to AIC test; "exactly matches" footnote claim without inline computation)
- Cat 3 (Identification): -0 (well-calibrated; cleanly avoids causal claims; boundary-test handling is exemplary)
- Cat 4 (Writing): -9 (sentence fragment at `01-introduction.qmd:41`; missing word at `index.qmd:6`; subject-verb at `03-gamma-generalization.qmd:89`; four formulaic section bridges; em-dash density in §5; "essential", "chronic"; gerund chains in §6)
- Cat 5 (Quarto/Format): -0 (previous render-fail item fixed; minor `:::{#fig-eff-hist}` stylistic divergence noted but not penalised)
- Cat 6 (Compilation): -3 (`@eq-loglik-scaling` is used at `05-simulations.qmd:628` to refer to an LR-test equation that doesn't exist; ~18 orphan labels persist)
- Cat 7 (Voice): 0 (not scored)
- Cat 8 (Notation): -2 ($\delta$ dual use still handled only by footnote)
- **Final: 80/100**

## Priority Recommendations

1. **[CRITICAL]** Fix the abstract claim at `index.qmd:6`. The current language ("the model recovers firm-level technical efficiency scores that are robust to the shape of the inefficiency distribution") is contradicted by `06-empirical.qmd:139-146` and `06-empirical.qmd:256-266`, where the Gamma frontier fails to converge on the patent panel. Either soften to "the model produces firm-level technical efficiency scores under the exponential restriction, with the Gamma restriction unidentified on this dataset" or restructure §6 to provide the shape-invariance check the abstract promises. Same paragraph also has a missing word: "The exponential special admits" → "The exponential special **case** admits".

2. **[CRITICAL]** Fix the `@eq-loglik-scaling` cross-reference at `05-simulations.qmd:628`. The sentence "In Scenario 0 the LR test @eq-loglik-scaling should achieve size close to the nominal 5% level" treats the log-likelihood equation as if it were the LR-test statistic. Either define a labelled LR-test equation in §3.3 or §5.5 (e.g. `{#eq-lr-scaling}`) and point to it, or rewrite the sentence to say "the LR test of $H_0: \delta = 0$ ... ".

3. **[CRITICAL]** Fix the sentence fragment at `01-introduction.qmd:41`: "Features better motivated by the continuous literature rather than by count-data applications." Merge into the preceding sentence ("...inherits a symmetric bell shape from the underlying continuous draw — features better motivated by the continuous literature than by count-data applications") or rewrite as a full clause.

4. **[MAJOR]** Fix the subject-verb at `03-gamma-generalization.qmd:89`: "the one [@feHofler2013, fn. 7] **flag** for" → "the one [@feHofler2013, fn. 7] **flags** for" (or rephrase to "the one *flagged* in footnote 7 of @feHofler2013").

5. **[MAJOR]** Address the intro–empirics commitment mismatch at `01-introduction.qmd:73-78`. Either soften the language to "we examine capital intensity and science-sector membership as candidate determinants" (deferring the conclusion) or unconditionally commit §6 to specific signs and significance levels. The current render-time `if (delta1_hat < 0) ... else ...` injection at `06-empirical.qmd:739` risks producing a published intro that contradicts a marginal $p$-value flip. (Carry-over from May 18.)

6. **[MAJOR]** Report the headline mean-efficiency number in `06-empirical.qmd:243-247`. Currently the §6.1 paragraph that defines $\hat b$ leaves the reader with a formula and no number; the number is given only at the §6.2 opener. Inline a `r round(1/fit_exp$b, 3)` or similar so the §6.1 reader can anchor on it. (Carry-over from May 18.)

7. **[MAJOR]** Either compute the $0.486$ sum-of-elasticities at `06-empirical.qmd:237` inline (and replace the hard-coded number with a `r round(...)` expression that pulls from `application.R`), or add a pointer to where in `application.R` the number is recovered. The word "exactly" is also strong — consider "matches to three decimals" or similar.

8. **[MAJOR]** Replace "confirming that a one-sided inefficiency term is warranted by the data" at `06-empirical.qmd:541-548` with an explicit AIC/BIC gap statement keyed off `tbl-model-tests`. The paper later notes that the boundary nesting precludes a formal LR test; the M3-vs-M1 comparison should therefore be framed exclusively in information-criterion terms in the prose, not via the word "warranted". (Carry-over from May 18.)

9. **[MINOR]** Remove or use the ~18 orphan labels enumerated in Cat 6, especially `sec-pmf-exp`, `sec-te-exp`, `sec-emp-data`, `sec-emp-efficiency`, `eq-loglik`, `eq-reparam`, `eq-te-def`, `eq-te-emp`. (Carry-over from May 18.)

10. **[MINOR]** Reduce the four "With X established, @sec-Y …" bridge paragraphs at the end of §3, §4, §5, §6 (`03-gamma-generalization.qmd:249`, `04-estimation.qmd:400`, `05-simulations.qmd:519`, `06-empirical.qmd:387`). Pick a different transitional construction for at least two. (Carry-over from May 18.)

11. **[MINOR]** Rename the year-dummy coefficients at `06-empirical.qmd:95` from $\delta_t$ to $\tau_t$ or $\gamma_t$ to eliminate the dual use of $\delta$ that the footnote at `06-empirical.qmd:101-103` is forced to disambiguate. (Carry-over from May 18.)

12. **[MINOR]** Trim "essential" at `04-estimation.qmd:65` and "chronic" at `05-simulations.qmd:411-414` (the latter is the "Coverage of Confidence Intervals" passage). Both read as mildly evaluative where neutral language ("important", "persistent") would do.

## Positive Findings

- **The boundary-test discussion in §6 is exemplary.** The Test/Type/Comparison taxonomy at `06-empirical.qmd:650-674` (chi-squared LR for interior nested restrictions; Vuong normal limit for genuinely non-nested comparisons; AIC/BIC gaps for boundary nesting where @andrews2001 invalidates standard inference) is rare in applied frontier work and the prose makes the distinctions explicit. The construction of `tbl-model-tests` honours the taxonomy: the M3-vs-M1 boundary comparison reports $\Delta$AIC / $\Delta$BIC only, no formal $p$-value.
- **The dual-orientation treatment is genuinely symmetric.** The propositions, corollaries, simulations, and the "structurally symmetric" remarks at `02-model.qmd:174-182` and `02-model.qmd:396-399` all develop production and cost in parallel rather than as an afterthought. The cost-frontier Monte Carlo validation at §5.6 (`sec-sim-cost`) confirms that the per-observation quadrature delivers the same parametric convergence and near-nominal coverage as the alternating-series production case.
- **The intercept-attenuation triangulation is tight.** The asymptotic equality $\alpha_0 \log(b_0/(b_0 \pm 1))$ is derived in §4 (`04-estimation.qmd:68-75`), verified numerically in §5 against rendered simulation summaries (`tbl-cost-bias` and the inline `r` expressions at `05-simulations.qmd:1080-1093`), and recovered in §6 against textbook patent-panel numbers (`06-empirical.qmd:231-241`). Theory–simulation–data agreement is traceable cell by cell.
- **The new profile-likelihood figure at `fig-profile-lik` is informative.** Showing the same $\alpha$ profile at $n \in \{500, 1000, 2500\}$ on a shared master dataset cleanly separates the finite-sample weak-identification phenomenon from a structural identification failure. The figure underwrites the recommendation, repeated in §3, §4, and §5, that profile-likelihood intervals replace delta-method Wald intervals when $\hat\alpha$ is of inferential interest.
- **The §8 appendix is well-scoped.** Four lifted-proof subsections (`sec-app-pmf-proof`, `sec-app-te-proof`, `sec-app-likelihood`, `sec-app-condmoments`) hold the technical material without bloating the main text. The May 18 proofs review confirmed the math is sound.
