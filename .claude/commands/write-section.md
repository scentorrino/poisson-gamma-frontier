Read CLAUDE.md and the current content of all .qmd files.

Write or substantially improve the section: $ARGUMENTS

Rules:
- Quarto markdown prose only — no raw LaTeX environments except inside $$ math blocks
- Use Quarto cross-reference syntax: @eq-, @fig-, @tbl-, @sec- (never \ref{} or \eqref{})
- Use [@key] citation syntax (never \cite{})
- Every quantitative claim must reference a @tbl- or @fig-
- Callout blocks for important remarks:
    ::: {.callout-note}
    **Remark.** ...
    :::
- Theorem/proof environments via pandoc-amsthm if needed:
    ::: {#thm-label}
    **Theorem 1.** ...
    :::
- No bullet point lists in the main paper prose
- End each section with a brief transition to the next

After writing, verify:
- No broken cross-references
- All R chunks that produce outputs have proper #| label: and #| fig-cap: / #| tbl-cap:
- Math notation consistent with CLAUDE.md throughout