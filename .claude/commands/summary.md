---
description: Synthesise all review reports into a single executive summary with a prioritised action plan. Run after /proofread, /check-math, and /consistency have completed.
argument-hint: [optional: "short" for one-page version, or "journal-name" to tailor tone]
---

Read CLAUDE.md to understand the paper's subject matter, target journal, and review scope.

Then read every file in the review/ folder that exists:
- review/proofread_report.md
- review/math_audit.md
- review/consistency_report.md
- review/symbol_table.md

If some of these files are missing, note which checks have not yet been run and
work only from what is available.

Also read the paper file(s) listed in CLAUDE.md to verify context where needed.

---

## YOUR TASK

Produce a single synthesis document saved to review/summary.md.
Do NOT copy-paste from the individual reports — synthesise, deduplicate, and prioritise.
The same underlying problem may appear in multiple reports (e.g. a notation conflict
flagged in both math_audit and consistency_report); merge these into one entry.

---

## OUTPUT STRUCTURE

The file must follow this structure exactly:

---

# Review Summary

**Paper:** [title from CLAUDE.md]
**Authors:** [from CLAUDE.md]
**Target journal:** [from CLAUDE.md]
**Draft version:** [from CLAUDE.md]
**Review date:** [today's date]
**Checks completed:** [list which of the four reports exist]

---

## Overall Assessment

Write 3–5 sentences covering:
- What the paper does well (be specific, not generic)
- The single most important problem to fix
- The overall readiness level: choose one of:
  "Ready to submit with minor revisions" /
  "Needs moderate revision before submission" /
  "Needs substantial revision" /
  "Not ready for submission"
- Estimated revision effort: Low (< 1 day) / Medium (2–4 days) / High (> 1 week)

---

## Issue Register

Group all issues across all reports into three severity tiers.
Within each tier, list issues in order of importance.
Each row must have a unique ID (C1, C2, M1, M2, m1, m2, etc.).

### 🔴 Critical — Must Fix Before Submission
These are errors that are factually wrong, logically invalid, or that would cause
an editor to desk-reject the paper.

| ID | Location | Issue | Suggested fix |
|----|----------|-------|---------------|
| C1 | [file, section, or equation ref] | [precise description] | [concrete suggestion] |

If there are no critical issues, write: *No critical issues found.*

### 🟡 Major — Should Fix Before Submission
These are problems that weaken the paper's contribution, create confusion,
or would generate mandatory revision requests from a referee.

| ID | Location | Issue | Suggested fix |
|----|----------|-------|---------------|
| M1 | ... | ... | ... |

If there are no major issues, write: *No major issues found.*

### 🔵 Minor — Recommended Fixes
Typos, small inconsistencies, unclear phrasing, missing minor citations.
These will not block acceptance but improve the paper's professionalism.

| ID | Location | Issue | Suggested fix |
|----|----------|-------|---------------|
| m1 | ... | ... | ... |

---

## Notation & Symbol Conflicts

If review/symbol_table.md exists, extract only the conflicts (ignore clean entries).
Format as a compact table:

| Symbol | Intended meaning | Conflicting use | Recommended resolution |
|--------|-----------------|-----------------|----------------------|

If no conflicts exist, write: *No notation conflicts found.*

---

## Section-by-Section Verdict

For each section of the paper (infer section names from the paper files or CLAUDE.md),
give a one-line verdict using one of: ✅ Ready / ⚠️ Needs revision / 🔴 Significant problems.
Add a brief note (max 15 words) only for sections that are not ✅.

| Section | Verdict | Note |
|---------|---------|------|
| Abstract | ... | ... |
| Introduction | ... | ... |
| [remaining sections] | ... | ... |

---

## Recommended Action Plan

A numbered list of actions in the order they should be performed.
Sequencing matters — flag when fixing one issue may affect others downstream
(e.g. "Fix C1 before rerunning simulations, as the error propagates to Table 2").

1. [Most urgent action — typically the highest-severity issue]
2. ...
...

---

## What to Re-Check After Revisions

List which slash commands to re-run after the author makes changes,
and on which files. Be specific — do not say "re-run everything" unless warranted.

Example format:
- `/check-math "section3.qmd"` — verify the corrected derivation in Proposition 1
- `/consistency` — confirm the notation conflict between sections 2 and 4 is resolved
- `/compile` — check that all cross-references still resolve after edits

---

## Detailed Reports

Remind the user where the full evidence for each issue can be found:

- Full language and flow issues → review/proofread_report.md
- Full mathematical audit → review/math_audit.md
- Full consistency check → review/consistency_report.md
- Complete symbol table → review/symbol_table.md

---

## FORMATTING RULES

- Be specific throughout: cite file names, equation numbers, section names
- Do not invent issues not found in the reports
- Do not repeat the same issue under multiple severity tiers
- Do not use vague language like "the paper could be clearer" without pointing to a location
- If $ARGUMENTS contains "short", omit the section-by-section table and the
  detailed reports section, and keep the issue register to a maximum of 10 rows total
- If $ARGUMENTS contains a journal name (e.g. "Journal of Econometrics"),
  add a final line to the Overall Assessment noting any specific fit concerns
  with that journal's scope or style standards
