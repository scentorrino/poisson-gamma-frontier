Read CLAUDE.md and all .qmd files in the project simultaneously.
This command checks global consistency across the entire manuscript —
things that are only visible when the whole paper is read at once.

## CHECKS

### 1. The Narrative Arc
- Does the introduction promise exactly what the paper delivers — no more, no less?
- Are all contributions listed in the intro demonstrated somewhere in the paper?
- Does the conclusion accurately summarise the actual findings?
- Is there anything in the conclusion not supported by results in the paper?

### 2. Symbol Consistency Across Sections
Trace every symbol through the paper in order of appearance:
- Is every symbol defined before first use?
- Does any symbol change meaning between sections?
- Are notation choices consistent with the key references 
  (Fé & Hofler 2013, Meeusen & van den Broeck 1977)?

### 3. Model Consistency
The core model is: Y|u ~ Poisson(exp(x'β - u)), u ~ Gamma(α, b)
Verify this specification is stated identically in:
- The abstract
- The introduction  
- Section 2 (model setup)
- The estimation section
- The simulation DGP
- The empirical section
Flag any section where the model is stated differently or imprecisely.

### 4. Assumptions Consistency
List every assumption made in the paper (e.g. independence of observations,
support of u, identification conditions). For each:
- Where is it first stated?
- Is it maintained consistently throughout?
- Is it ever violated or quietly dropped?

### 5. Numbers Consistency
Check that all numbers stated in the prose match their source tables/figures:
- Coefficient estimates mentioned in text match Table values
- Sample sizes stated in text match data description
- Simulation parameters in text match the actual R code (if visible)

### 6. Tense & Voice Consistency
- Past tense for what was done, present tense for what the model says — consistent?
- Active/passive voice choices consistent within each section?

## OUTPUT
Save to review/consistency_report.md

For each issue found: section | nature of inconsistency | suggested resolution
End with a one-paragraph overall assessment of manuscript coherence.