Read CLAUDE.md. Write the theory content for the section specified in $ARGUMENTS
(e.g. "02-model" or "03-gamma-generalization").

Requirements for the .qmd file:
- Pure Quarto markdown: prose in plain text, math in $...$ or in ::: {.theorem} divs
- Use numbered display equations with {#eq-labelname} for cross-referencing
- Reference equations with @eq-labelname, sections with @sec-labelname
- Include a small non-executed R chunk (eval: false) showing the PMF formula as code
  to help readers connect math to implementation
- Cite using [@meeusenBroeck1977], [@feHofler2013], [@greene1980]
- Derivation steps (substitutions t=a-u, s=e^t) should be shown explicitly in math

Section-specific guidance:
- 02-model.qmd: setup, log-linear link λ=exp(xβ-u), joint density, marginal derivation
- 03-gamma-generalization.qmd: Gamma(α,b) setup, series PMF, integer-α finite sum,
  verify α=1 recovers the exponential result, table summarising all three cases

After writing, confirm all @eq- and @sec- cross-references resolve correctly.