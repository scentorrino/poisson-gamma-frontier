Read CLAUDE.md. Then read every file specified in $ARGUMENTS (or all .qmd files
in the project if no argument given). Also read references.bib.

Perform a deep proofreading pass covering four dimensions:

---

## 1. LANGUAGE & STYLE
- Grammar, spelling, punctuation errors
- Sentences that are awkward, overly long, or ambiguous
- Passive voice overuse (flag but don't over-correct — passive is normal in methods sections)
- Inconsistent terminology (e.g. "inefficiency term" vs "inefficiency component" vs 
  "one-sided error" — pick one and flag deviations)
- Hedging language that weakens claims without adding precision
- Transitions between paragraphs and sections — flag abrupt jumps
- Abstract: does it accurately reflect the paper's actual contributions?

## 2. MATHEMATICAL NOTATION
Check the following across ALL files simultaneously:

Consistency:
- Every symbol introduced must be defined at first use and used consistently thereafter
- List all symbols used in the paper and flag any that are used with different meanings
  in different sections
- Check that subscripts/superscripts are consistent (e.g. λ_i vs λ(x_i))
- Check that the same object is never denoted two different ways

Correctness:
- Verify that equations referenced in prose match the numbered equations in the .qmd files
- Check that dimensions/domains are stated correctly (e.g. u ≥ 0 for inefficiency)
- Check that all summations/integrals have correct limits stated
- Verify that all functions used are well-defined over the claimed domain

Formatting:
- Inline math ($...$) vs display math ($$...$$) — flag inconsistent usage
- Flag any math rendered as plain text by mistake
- Check all @eq- cross-references resolve to actual equation labels

## 3. FLOW OF REASONING
For each section, ask:
- Does the section open by stating what it will do?
- Does each paragraph follow logically from the previous?
- Are all claims either proven, cited, or flagged as assumptions?
- Are empirical results interpreted before moving on, or just stated?
- Does the conclusion section actually conclude from what was shown,
  or does it introduce new material?

Flag any of these:
- Circular arguments
- Claims made before they are justified
- Results stated in the intro that are stronger than what the paper delivers
- Sections that feel disconnected from the paper's main thread

## 4. CROSS-REFERENCES & CITATIONS
- Every @fig-, @tbl-, @eq-, @sec- reference: does it point to something that exists?
- Every [@citation] key: does it exist in references.bib?
- Are there claims that should be cited but aren't?
- Are citations used correctly (e.g. not citing a paper for a result it doesn't contain)?

---

## OUTPUT FORMAT
Produce a structured report saved to review/proofread_report.md with sections:

### Critical Issues (must fix before submission)
### Notation Inconsistencies (table: symbol | first definition | conflicting uses)
### Mathematical Concerns (equation number | issue | suggested fix)  
### Flow Issues (section | paragraph | issue)
### Minor Language Edits (file | approximate location | original | suggested)
### Missing Citations
### Summary: estimated effort to address all issues (low / medium / high)

Be specific — give file names and enough context to locate each issue.
Do NOT rewrite the paper. Flag and suggest only.