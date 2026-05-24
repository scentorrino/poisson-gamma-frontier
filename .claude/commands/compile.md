Read CLAUDE.md. Compile the full Quarto manuscript.

Steps:
1. Check _quarto.yml lists all section .qmd files
2. Check references.bib exists and all [@keys] used in .qmd files have entries
3. Check all cross-references (@fig-, @tbl-, @eq-, @sec-) are defined somewhere
4. Run: quarto render
5. Check the output log for errors, undefined references, and missing figures
6. If errors, diagnose and fix, then re-run quarto render
7. Report:
   - PDF page count
   - HTML output location
   - Any unresolved cross-references
   - Any R chunk errors (look for "Error in" in the log)
   - Cache status: which chunks were recomputed vs cached

If quarto is not installed, check with: quarto --version
If knitr or required R packages are missing, identify them from library() calls in .qmd files
and install with install.packages().