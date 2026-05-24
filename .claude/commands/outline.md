Read CLAUDE.md carefully. Produce a detailed paper outline saved to outline.md.

Include:
1. Working title and 3-sentence abstract placeholder
2. For each .qmd section file: 3-4 bullet points of exact content
3. A list of all figures (@fig-xxx labels) and tables (@tbl-xxx labels) to be produced
4. Which R chunks are computationally heavy (mark these for cache: true)

Also create the skeleton .qmd files: for each section, create the file with:
- A YAML header block: ## Section Title {#sec-sectionname}
- One sentence describing what goes here
- A placeholder R chunk with #| label: setup-XX and source("code/estimation_functions.R")

Finally, verify _quarto.yml lists all section files correctly.
Print a summary of files created.