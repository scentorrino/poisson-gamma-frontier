Read CLAUDE.md and all .qmd files. Extract every [@citation_key] used anywhere in the project.

For each unique citation key, find the full bibliographic details by searching the web,
then write a complete BibTeX entry to references.bib.

The paper cites at minimum:
- feHofler2013 — Fé & Hofler (2013), Journal of Productivity Analysis
- feHofler2020 — Fé & Hofler (2020), The Stata Journal (sfcount)
- hoflerScrogin2008 — Hofler & Scrogin (2008), UCF Discussion Paper
- meeusenBroeck1977 — Meeusen & van den Broeck (1977), International Economic Review
- aigner1977 — Aigner, Lovell & Schmidt (1977), Journal of Econometrics
- greene1980 — Greene (1980), Journal of Econometrics
- hausman1984 — Hausman, Hall & Griliches (1984), Econometrica
- hallGrilichesHausman1986 — Hall, Griliches & Hausman (1986), International Economic Review
- cameronTrivedi1998 — Cameron & Trivedi (1998), Regression Analysis of Count Data
- kumbhakarLovell2000 — Kumbhakar & Lovell (2000), Stochastic Frontier Analysis

For each entry verify: author, title, journal, year, volume, pages, doi.
Save to references.bib in the project root.
After writing, run: quarto check references.bib (or equivalent) and report any malformed entries.