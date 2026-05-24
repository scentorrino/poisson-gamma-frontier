# Personal Style Guide

<!--
Extracted from a corpus of Samuele Centorrino's published methodological-econometrics papers
(Journal of Econometrics, JBES, Annals of Economics and Statistics, Econometrics and Statistics).
The writer agent should load this file on every drafting/revision invocation and calibrate to
the patterns recorded here. Patterns are grounded in verbatim excerpts from the corpus.
-->

## Source Corpus

**Extracted on:** 2026-05-23
**Papers analyzed:** 5

| Paper | Year | Journal |
|---|---|---|
| Iterative estimation of nonparametric regressions with continuous endogenous variables and discrete instruments [Centorrino, Fève, Florens] | 2025 | Journal of Econometrics 247, 105950 |
| Nonparametric estimation of stochastic frontier models with weak separability [Centorrino, Parmeter] | 2024 | Journal of Econometrics 238, 105641 |
| Instrumental Variable Estimation of Dynamic Treatment Effects on a Duration Outcome [Beyhum, Centorrino, Florens, Van Keilegom] | 2023 | Journal of Business & Economic Statistics 41 |
| Nonparametric Instrumental Variable Estimation of Binary Response Models with Continuous Endogenous Regressors [Centorrino, Florens] | 2020 | Econometrics and Statistics |
| Semiparametric Varying Coefficient Models with Endogenous Covariates [Centorrino, Racine] | 2017 | Annals of Economics and Statistics 128 |

The first four are first-author or solo-led; the JBES paper is a coauthored piece where the lead author is not Centorrino (used for triangulation only).

---

## Sentence Patterns

| Metric | Value | Example from corpus |
|--------|-------|--------------------|
| Median sentence length (words) | ~22 | "An estimator of $\varphi_\dagger$ is obtained by solving a regularized version of this functional equation (see Chen and Pouzo, 2012; Darolles et al., 2011; Florens, 2003; Hall and Horowitz, 2005; Horowitz, 2011; Newey and Powell, 2003, among others)." (NP-IV 2025, p.2) |
| Range (10th–90th pct, words) | ~10 to ~45 | Lower bound: "We assume the following." (NP-IV 2025, p.3). Upper bound: full multi-clause technical sentences with parentheticals and citations (typical in literature-positioning paragraphs). |
| Passive voice frequency | Low–moderate | Active "we" dominates; passive appears for definitions ("$\varphi_\dagger$ is characterized as the solution of...") and for technical attribution ("This model has been considerably studied..."). |
| First-person plural ("we") | Very frequent in intro, methods, and contribution paragraphs. Rare inside proofs and definitions. | "We consider...", "We propose...", "We provide...", "We thus revisit..." (NP-IV 2025). |
| Em-dash usage | **Effectively zero in body prose.** A few in abstracts and footnotes; never as drama markers. | The 2025 NP-IV paper contains essentially no em-dashes in body text; semicolons and parentheticals do the same work. |
| Semicolon usage | Common, used to join related clauses or to chain a citation list inside parentheses. | "This is true, for instance, for randomized experiments with partial compliance, where the intent-to-treat provides an obvious source of exogenous variation (see Krueger, 1999; Torgovitsky, 2015)." (NP-IV 2025, p.2) |
| Parentheticals | Heavy. Used for citation clusters, technical clarifications, and "see also" pointers. | "(see Chen and Pouzo, 2012; Darolles et al., 2011; Florens, 2003; ... among others)" — pattern repeats across all papers. |

---

## Paragraph Architecture

**Typical paragraph structure:** A topic statement (often a substantive claim about the model or the literature) followed by 2–4 supporting sentences that develop, qualify, or cite. Closes with a forward link, a citation, or a sharp qualifier.

### Opening moves the author uses (with quoted examples)

- **"We" + main verb in the first clause** — by far the dominant opener for substantive paragraphs:
  - "We consider the nonparametric regression model" (NP-IV 2025, p.1)
  - "We propose a new approach that is similar in spirit to Florens et al. (2020)" (Centorrino-Parmeter 2024, p.2)
  - "We provide a new approach that is similar in spirit to Florens et al. (2020) in that..." (Centorrino-Parmeter 2024, p.2)
  - "We contribute to the existing literature in several directions." (NP-IV 2025, p.2)

- **Definitional opener** — for assumption / model paragraphs:
  - "Let $(Y^*, X, W)$ be a random vector in $\mathbb{R}\times\mathbb{R}^p\times\mathbb{R}^q$..." (Centorrino-Florens 2020, p.3)
  - "Let $w_{1,1}=g_1^{-1}(1/\xi, w_{-1,1})$, then we have..." (Centorrino-Parmeter 2024, p.5)

- **Field-state opener** — for section-opening or transitional paragraphs:
  - "Instrumental variables are a workhorse of applied research in economics." (NP-IV 2025, p.1)
  - "The stochastic frontier model remains a workhorse for benchmarking and regulatory oversight." (Centorrino-Parmeter 2024, p.1)
  - "The semiparametric varying coefficient model is used in a wide range of applications." (Centorrino-Racine 2017, p.261)
  - The word "workhorse" recurs across three of the five papers — part of the author's lexicon.

- **Acknowledgement opener** — for limitations/threats paragraphs:
  - "We acknowledge that Assumption 2.3 is somewhat restrictive." (Centorrino-Florens 2020, p.4)
  - "This condition is strong and may pose some challenges to the empirical application of fully nonparametric estimators of model (1)." (NP-IV 2025, p.2)

- **Connective single-word opener** — common, used sparingly: *Moreover, Notice that, Indeed, However, Finally, In this respect, As a matter of fact*:
  - "Notice that, in this respect, our approach is less general than control functions..." (NP-IV 2025, p.2)
  - "Moreover, all these papers restrict function $\varphi$ to be parametric so that it is possible to relax the assumptions on the conditional distribution of the error term." (Centorrino-Florens 2020, p.2)

### Closing moves the author uses

- **Forward link to a later section**, no announcement language:
  - "We will discuss the construction of the test statistic and its asymptotic behavior in Section 3.1." (Centorrino-Parmeter 2024, p.4)
- **Parenthetical citation cluster** as the closing payload:
  - "...regularization bias that should disappear as the sample size increases. To control the convergence to zero of this regularization bias, we make the following additional assumption." (Centorrino-Florens 2020, p.5)
- **Bounded qualification**, one clause:
  - "However, our model assumes that the function $g(x,\varepsilon)$ has a separable form, with $U=F_U^{-1}(\varepsilon)$, and $F_U$ the cumulative distribution function of $U$." (NP-IV 2025, p.2)

### Openings the author avoids

- **No "It is well known that…"** — observed zero times in the corpus.
- **No "Recently, there has been growing interest in…"** — observed zero times.
- **No "In this paper we will…"** — when "In this paper" is used (rare), it is followed by a substantive verb, not a meta-future-tense announcement: e.g. "In this paper, we consider the estimation of $\varphi$ in the case in which the dependent variable $Y^*$ is not observable." (Centorrino-Florens 2020, p.3).
- **No bombastic openers.** None of "A revolutionary…", "A new era of…", "We solve…".
- **No rhetorical questions in body prose.**

---

## Section Architecture

### Introduction

- Opens with a **field-state declaration** ("Instrumental variables are a workhorse…", "The stochastic frontier model remains a workhorse…", "The semiparametric varying coefficient model is used in a wide range of applications.") — never with the contribution itself.
- The **identification of the gap** typically comes after one or two paragraphs that survey the relevant literature with parenthetical citation clusters.
- **Contribution paragraph** opens with "We propose…" / "We provide…" / "We consider…" and lists 2–4 specific items, usually as a numbered enumeration in the body of the paragraph rather than as a bulleted list. Example: "We contribute to the existing literature in several directions. First, the LF technique that we propose is both computationally efficient and easy to implement. Its properties in this class of statistical problems are new to the best of our knowledge. Finally, while our approach is not as general as those provided by Dunker et al. (2014), Dunker (2021) is limited to the statistical model at hand, our convergence rates clearly spell out the sources of the estimation error and allow us to provide better guidance for implementation in this particular example." (NP-IV 2025, p.2).
- **Roadmap paragraph** is short and concrete: "The paper is organized as follows. In Section 2, we briefly discuss some local identification conditions in the independence case in relation to the usual completeness condition. In Section 3, we present the practical implementation of our estimator, whose properties are detailed in Section 4. We discuss the specific case of a binary instrument in Section 5. We conclude our work with an empirical application estimating the returns to education, using data from Card (1995)." (NP-IV 2025, p.2). Each section gets one sentence; the roadmap is descriptive, not promotional.

### Model / Assumptions section

- Opens with the formal random element / model statement.
- Each assumption gets its own labelled environment (Assumption 2.1, Assumption 2.2, …), followed by one or two interpretive paragraphs.
- The interpretive paragraphs **state the assumption in words and explain when it is restrictive**, with concrete examples — never a generic "this assumption is standard in the literature".

### Estimation / Implementation section

- States the goal of the section in one sentence ("The objective of this section is to describe the implementation of our estimation strategy and provide the asymptotic normality of our estimator." — Centorrino-Parmeter 2024, p.5).
- Lists the estimation steps as a numbered enumeration in the body text, each step one or two short sentences.

### Conclusion

- Often absent or very short in the methodological-econometrics papers (e.g., NP-IV 2025 concludes inside Section 5 with the empirical application). When present, summarises the contribution in 2–3 sentences and points to extensions, without a "summary table" of results.

---

## Lexicon

### Words and phrases the author uses

| Pattern | Example |
|---|---|
| **workhorse** (recurring framing word for an established method) | "Instrumental variables are a workhorse of applied research in economics." (NP-IV 2025) |
| **ill-posed inverse problem** | "the inverse problem is severely ill-posed" (NP-IV 2025, p.5) |
| **regularization** / **regularized** | "the regularized solution of the inverse problem" (Centorrino-Florens 2020, p.5) |
| **completeness condition** / **completeness** | "the so-called completeness condition" (NP-IV 2025, p.2) |
| **amenable to** | "the function $\varphi_\dagger$ to be sufficiently smooth, so that this condition is sufficient to satisfy the requirement of Proposition 2.1(iv)" |
| **in this respect** | "In this respect, our approach is less general than control functions" (NP-IV 2025, p.2) |
| **to the best of our knowledge** | "Its properties in this class of statistical problems are new to the best of our knowledge." (NP-IV 2025, p.2) |
| **as a matter of fact** | "As a matter of fact, from the proof of Proposition 2.1..." (Centorrino-Parmeter 2024, p.4) |
| **Notice that** | "Notice that, by definition, $\varphi_0(\cdot)$ and $\varphi_1(z,\cdot)$ are strictly increasing." (Beyhum et al. 2023, p.4) |
| **However,** / **Moreover,** / **Finally,** | Used as substantive connectives, not as fillers. One per paragraph at most. |
| **straightforward** | "the proofs of these statements are given in Section B of the Supplementary Material" (NP-IV 2025, p.4); "This estimator can be constructed in a straightforward, stepwise approach" (Centorrino-Parmeter 2024, p.2) |
| **consistent with** | "We find results consistent with those of Card, D. [1999] which provides a robustness check on these results" (Centorrino-Racine 2017, p.263) |
| **the latter route is the one we undertake in this paper** | Verbatim phrasing in NP-IV 2025, p.2. |
| **We acknowledge that…** | "We acknowledge that Assumption 2.3 is somewhat restrictive." (Centorrino-Florens 2020, p.4) |

### Words and phrases the author avoids

Based on a corpus-wide search, these AI-flavoured words appear **zero or near-zero times** in the corpus:

- *delve*, *delves into*, *delved*
- *tapestry*
- *interplay* (substantive economic usage rare; never as a filler)
- *underscore*, *underscores*, *underscoring*
- *multifaceted*
- *holistic*
- *leverage* / *leverages* / *leveraging* (the author writes "use" or "apply")
- *garner*, *garners*
- *pivotal*, *pivotal moment*
- *paradigm shift*, *paradigm*
- *groundbreaking*, *transformative*, *unprecedented*, *revolutionary*
- *crucial juncture*
- *robust* as a free-standing adjective without a referent (e.g. "robust to" or "robust evidence" without specifying robustness checks)
- *comprehensive* in promotional sense
- *In light of*

The author also avoids the **negative-parallelism filler** ("not only X but also Y") as a stylistic tic. Negative parallelisms appear in the corpus only when they are load-bearing — i.e., when contrasting two specific approaches.

### Hedging pattern

- **Substantive, not stylistic.** When the author hedges, the hedge names a specific assumption or limitation: "We acknowledge that Assumption 2.3 is somewhat restrictive." (Centorrino-Florens 2020, p.4). "We do not know whether our identification result holds more generally under milder conditions on the CDF of $\varepsilon$." (ibid.)
- **No stacked hedges.** Phrases like "may potentially be the case that…" or "it could perhaps be argued that…" do not appear.
- **Modal verbs** ("may", "could", "might") used for genuine uncertainty, not as a softening tic.
- **"This condition is strong"** — declarative qualifier, not a softening.

### Comparison pattern

- "Our approach is similar in spirit to [Author, Year] in that…" (Centorrino-Parmeter 2024, p.2)
- "Our paper focuses on the case where $X$ is continuous (see also Loh, 2023a)." (NP-IV 2025, p.2)
- "In contrast, the present work does not assume such one-sided noncompliance, and our method allows us to estimate effects over the whole population." (Beyhum et al. 2023, p.1)
- The author **names the specific paper being compared to** rather than "previous work" or "the literature".
- Comparisons report *what differs* in technical terms, not in qualitative size ("better", "more powerful").

---

## Citation Conventions

- **Textual vs. parenthetical split**: roughly 30% textual, 70% parenthetical in body. Textual citations are reserved for direct conceptual lineage ("Dunker et al. (2014) have considered the estimation and asymptotic properties of nonparametric estimators for nonlinear integral equations." — NP-IV 2025, p.2). Parenthetical citations cluster references behind a stated fact.
- **Citation clusters with "among others"**: a signature pattern.
  - "(see Chen and Pouzo, 2012; Darolles et al., 2011; Florens, 2003; Hall and Horowitz, 2005; Horowitz, 2011; Newey and Powell, 2003, among others)" (NP-IV 2025, p.2)
  - "(see Florens, Mouchart, and Rolin (1990) and more recently Andrews (2017), Canay, Santos, and Shaikh (2013), D'Haultfœuille (2011) and Freyberger (2017), among others)" (NP-IV 2025, p.2)
- **"see also" extensions**: common for connecting an idea to an adjacent literature: "(see also Loh, 2023a)" (NP-IV 2025); "(see also Chen and Reiss, 2011; Florens and Simoni, 2012)" (Centorrino-Florens 2020, p.3).
- **Number of papers per claim**: typically 2–5 in a citation cluster; up to 7 when surveying the literature ("among others" closing).
- **Self-citations**: present but sparse — the author cites prior co-authored work (Centorrino 2016; Centorrino et al. 2017; Florens et al. 2018) only when building directly on a prior result, never as a positioning move.

---

## Tone Markers

- **Confident but flat.** States the contribution as a fact; flags limits as facts. No bombast, no humble-bragging.
  - "Its properties in this class of statistical problems are new to the best of our knowledge." (NP-IV 2025, p.2) — the only "new to the best of our knowledge" claim in the introduction, and the contribution is otherwise stated flatly.
- **Direct acknowledgement of limitations** without softening.
  - "We acknowledge that Assumption 2.3 is somewhat restrictive."
  - "This condition is strong and may pose some challenges…"
- **No self-deprecation.** The author does not undersell.
- **No promotional adjectives**: "powerful", "compelling", "robust" (as flourish), "innovative", "novel" (used only in titles, never in body).
- **Restrained register**: registers as a methodological econometrician, not as a popular-science writer.
- **Footnotes carry technical comment, not asides or humour.**

---

## Anti-patterns Already Stripped

These patterns are *demonstrably absent* from the corpus — the writer should never reintroduce them:

- **Em-dash chains in body prose** — body text uses commas, semicolons, and parentheticals instead.
- **"In order to" → "To"**: the author uses "To" or omits the construction entirely.
- **"A variety of" / "Several factors contribute"**: the corpus uses specific enumerations.
- **Rule-of-three triplets** in flourish position (the corpus uses triplets only when the underlying content is naturally three items).
- **Meta-announcements** like "This section discusses…", "Next, we turn to…" at the head of paragraphs. The corpus opens substantively.
- **Vague attributions** like "researchers have noted…" or "experts argue…". The corpus always names the paper.
- **Bombastic significance inflation** ("pivotal", "groundbreaking", "transformative").
- **Superficial -ing constructions** ("highlighting the importance of…", "underscoring the need for…").

---

## Notes for the Writer Agent

- **Lead with the substantive verb.** Default sentence opener for new paragraphs is "We" + verb. Definitional paragraphs open with the formal object ("Let $X$ be…", "Consider the model…").
- **Use semicolons before resorting to em-dashes.** The author's body prose is essentially em-dash-free; if a clause needs a parenthetical, use commas or parentheses.
- **Cite in clusters, with "among others" at the end** when surveying a literature; cite singly and textually when building directly on a result.
- **Acknowledge limits explicitly, in one sentence each.** Do not bury qualifications inside a clause.
- **State magnitudes and assumption names directly** rather than gesturing at them: "Assumption 2.3 (Uniform Bounds)" is named when used, not "the assumption above".
- **Avoid the negative-parallelism tic** ("not only X but also Y"). When you find yourself reaching for it, ask whether one of the two claims is load-bearing — keep that one, cut the other.
- **One claim per sentence**, but the author is comfortable with long sentences when the claim is complex; do not force short sentences for their own sake. Median sentence length is ~22 words.
- **Footnotes for technical caveats and pointers**, not for stylistic asides.
- **First-person plural is the default voice.** Use "we" freely; do not switch to passive to avoid it.
- **Promotional adjectives are out.** If you cannot defend the adjective with a number or a citation, delete it.

---

## Self-Citation Gaps

A grep of the corpus for `\cite{Centorrino…}` style references surfaces the following self-citation keys recurring in the methodological-econometrics work:

- Centorrino (2016) — Tikhonov regularization, choice of regularization parameter
- Centorrino et al. (2017) — choice of the tuning parameter for Tikhonov regularization
- Centorrino, Florens (2020) — binary response nonparametric IV
- Centorrino, Parmeter (2024) — stochastic frontier with weak separability
- Centorrino, Pérez-Urdiales (2022) — productivity application
- Florens et al. (2018) — nonparametric IV (Centorrino is co-author)

**Relevance to the current project (`Nowcast_paper`):** none of these methodological self-cites is on-topic for an IMFNow nowcasting-software paper, so no self-citation gap exists in the current bibliography (`gdpnowcast.bib`) on this basis. If a future revision broaches nonparametric IV, stochastic frontiers, or Tikhonov regularization as a motivating analogy, these are the bib entries to add.
