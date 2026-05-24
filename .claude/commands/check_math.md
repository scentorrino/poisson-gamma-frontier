Read CLAUDE.md. Perform a focused, rigorous mathematical audit of $ARGUMENTS
(or all .qmd files if unspecified).

This is a math-only pass — ignore prose style entirely.

## AUDIT TASKS

### A. Derivation Verification
For every non-trivial derivation in the paper:
1. State the claim being made
2. Work through the key steps independently
3. Flag any step that is incorrect, skips steps without justification,
   or relies on an assumption not stated in the paper

Key derivations to check in THIS paper:
- The substitution t = a-u then s = e^t leading to the incomplete gamma result
- The series expansion via e^{-e^{a-w}} = Σ_k (-1)^k e^{ka} e^{-kw} / k!
- The interchange of sum and integral (is dominated convergence justified?)
- The reduction of α=1 series to the closed-form incomplete gamma
- The integer-α finite sum via binomial theorem
- The score equations for MLE (if present)
- Any asymptotic/consistency claims for the estimator

### B. Notation Audit
Produce a complete symbol table:
| Symbol | First defined | Definition | All locations used | Conflicts? |

Flag:
- Overloaded symbols (same letter used for two different things)
- Undefined symbols
- Symbols defined but never used
- Notation that conflicts with standard usage in the SFA literature
  (e.g. convention for u = inefficiency vs efficiency)

### C. Theorem/Lemma/Proposition Statements
For any formal statement:
- Is the statement precise? (all quantifiers explicit, domains stated)
- Is the proof complete?
- Are all assumptions listed in the statement used in the proof?
- Are there assumptions used in the proof not listed in the statement?

### D. Equations vs Prose Consistency
For every equation, check the surrounding prose:
- Does the prose correctly describe what the equation says?
- Are equation numbers referenced correctly in text?
- Are there equations presented as novel that are actually standard results
  (should be cited instead)?

## OUTPUT
Save to review/math_audit.md with structure:
### Verified (list of results confirmed correct)
### Errors Found (equation ref | issue | correction)
### Unjustified Steps (equation ref | missing justification)
### Notation Issues (symbol table + conflicts)
### Suggestions (not errors, but improvements to clarity/rigor)