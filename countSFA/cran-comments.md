# cran-comments.md

## Initial submission

This is a new submission of `countSFA`.

## Test environments

- macOS 26.4.1, R 4.5.3 (local)
- TBD: win-builder release/devel
- TBD: R-hub fedora-clang-devel

## R CMD check results

0 errors | 0 warnings | 1 note

The note is the standard "New submission" note from CRAN incoming
feasibility.

## Description

`countSFA` implements maximum likelihood estimation of Poisson
stochastic frontier models for count-valued outputs. The package
supports three parametric families for the one-sided inefficiency
term — exponential (closed-form), Gamma (absolutely convergent
alternating series), and half-normal (maximum simulated likelihood) —
and provides posterior technical efficiency scores plus
likelihood-ratio and Vuong (1989) tests for model comparison.

The methodology is described in an accompanying working paper
(Centorrino and Perez Urdiales, 2026), referenced in `inst/CITATION`.
The bundled `patents` dataset is the public Hausman, Hall, and
Griliches (1984) panel.

## Reverse dependencies

None. This is a new package.
